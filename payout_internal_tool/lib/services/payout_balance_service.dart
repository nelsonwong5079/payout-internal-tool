import 'dart:convert';
import 'dart:html' as html;

import 'package:http/http.dart' as http;

/// Client for Cloud Functions: checkBalance + balanceUpdate.
/// JWT signing and outbound payout API calls happen only on the backend.
class PayoutBalanceService {
  PayoutBalanceService({
    http.Client? client,
    this.functionsBaseUrl =
        'https://us-central1-codapay-webhook.cloudfunctions.net',
    this.schedulerCheckUrl =
        'https://payout-scheduler.codapay.net/internal/scheduler/email-workflow/check-new-email',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String functionsBaseUrl;
  final String schedulerCheckUrl;

  Uri get _checkBalanceUri => Uri.parse('$functionsBaseUrl/checkBalance');
  Uri get _balanceUpdateUri => Uri.parse('$functionsBaseUrl/balanceUpdate');

  /// VPN-only host. Browser uses no-cors (same pattern as main.dart reports).
  /// Opaque success = request completed without throw (status not readable).
  Future<bool> pingSchedulerFromBrowser() async {
    try {
      await html.window.fetch(schedulerCheckUrl, {
        'method': 'POST',
        'mode': 'no-cors',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<CheckBalanceResult> checkBalance({
    required String secret,
    required String partnerId,
    required String apiKey,
    bool production = false,
  }) async {
    try {
      final res = await _client
          .post(
            _checkBalanceUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'secret': secret,
              'partner_id': partnerId,
              'api_key': apiKey,
              'production': production,
            }),
          )
          .timeout(const Duration(seconds: 45));

      final decoded = _decodeJson(res.body);
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          decoded['success'] == true) {
        return CheckBalanceResult.ok(
          data: decoded['data'],
          environment: '${decoded['environment'] ?? ''}',
          raw: decoded,
        );
      }

      return CheckBalanceResult.err(
        message: decoded['error']?.toString() ??
            'Check balance failed (HTTP ${res.statusCode})',
        statusCode: res.statusCode,
        raw: decoded,
      );
    } catch (e) {
      return CheckBalanceResult.err(
        message: 'Network error: $e',
      );
    }
  }

  Future<BalanceUpdateResult> balanceUpdate({
    required String secret,
    required String partnerId,
    required String apiKey,
    required num balanceValue,
    required String currency,
    required num creditLimit,
  }) async {
    try {
      final res = await _client
          .post(
            _balanceUpdateUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'secret': secret,
              'partner_id': partnerId,
              'api_key': apiKey,
              'balance_value': balanceValue,
              'currency': currency,
              'credit_limit': creditLimit,
            }),
          )
          .timeout(const Duration(seconds: 100));

      final decoded = _decodeJson(res.body);
      var steps = BalanceUpdateSteps.fromJson(
        Map<String, dynamic>.from(decoded['steps'] as Map? ?? {}),
      );

      if (res.statusCode < 200 ||
          res.statusCode >= 300 ||
          decoded['success'] != true) {
        return BalanceUpdateResult.err(
          steps: steps,
          message: decoded['error']?.toString() ??
              'Balance update failed (HTTP ${res.statusCode})',
          statusCode: res.statusCode,
          raw: decoded,
        );
      }

      // Cloud Functions usually cannot reach VPN-only scheduler; retry here.
      final needsClientPing = decoded['needs_client_scheduler_ping'] == true ||
          (steps.emailSent && !steps.schedulerAck);
      if (needsClientPing) {
        final acked = await pingSchedulerFromBrowser();
        if (acked) {
          steps = BalanceUpdateSteps(
            csvBuilt: steps.csvBuilt,
            zipBuilt: steps.zipBuilt,
            emailSent: steps.emailSent,
            schedulerAck: true,
          );
        }
      }

      if (!steps.schedulerAck) {
        return BalanceUpdateResult.err(
          steps: steps,
          message:
              'Email sent, but scheduler ping failed. Connect to VPN and retry '
              '(or trigger check-new-email manually).',
          statusCode: res.statusCode,
          raw: decoded,
        );
      }

      return BalanceUpdateResult.ok(
        steps: steps,
        payoutBalance: '${decoded['payout_balance'] ?? ''}',
        zipName: '${decoded['zip_name'] ?? ''}',
        message: 'Balance CSV emailed and scheduler acknowledged.',
        raw: decoded,
      );
    } catch (e) {
      return BalanceUpdateResult.err(
        steps: const BalanceUpdateSteps(),
        message: 'Network error: $e',
      );
    }
  }

  Map<String, dynamic> _decodeJson(String body) {
    if (body.trim().isEmpty) return {};
    try {
      final v = jsonDecode(body);
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return {'data': v};
    } catch (_) {
      return {'raw': body};
    }
  }
}

class CheckBalanceResult {
  const CheckBalanceResult._({
    required this.success,
    this.data,
    this.environment,
    this.message,
    this.statusCode,
    this.raw,
  });

  factory CheckBalanceResult.ok({
    required Object? data,
    required String environment,
    Map<String, dynamic>? raw,
  }) =>
      CheckBalanceResult._(
        success: true,
        data: data,
        environment: environment,
        raw: raw,
      );

  factory CheckBalanceResult.err({
    required String message,
    int? statusCode,
    Map<String, dynamic>? raw,
  }) =>
      CheckBalanceResult._(
        success: false,
        message: message,
        statusCode: statusCode,
        raw: raw,
        data: raw?['data'],
      );

  final bool success;
  final Object? data;
  final String? environment;
  final String? message;
  final int? statusCode;
  final Map<String, dynamic>? raw;

  String prettyJson() {
    final payload = data ?? raw;
    try {
      return const JsonEncoder.withIndent('  ').convert(payload);
    } catch (_) {
      return '$payload';
    }
  }
}

class BalanceUpdateSteps {
  const BalanceUpdateSteps({
    this.csvBuilt = false,
    this.zipBuilt = false,
    this.emailSent = false,
    this.schedulerAck = false,
  });

  factory BalanceUpdateSteps.fromJson(Map<String, dynamic> m) =>
      BalanceUpdateSteps(
        csvBuilt: m['csvBuilt'] == true,
        zipBuilt: m['zipBuilt'] == true,
        emailSent: m['emailSent'] == true,
        schedulerAck: m['schedulerAck'] == true,
      );

  final bool csvBuilt;
  final bool zipBuilt;
  final bool emailSent;
  final bool schedulerAck;
}

class BalanceUpdateResult {
  const BalanceUpdateResult._({
    required this.success,
    required this.steps,
    this.payoutBalance,
    this.zipName,
    this.message,
    this.statusCode,
    this.raw,
  });

  factory BalanceUpdateResult.ok({
    required BalanceUpdateSteps steps,
    required String payoutBalance,
    required String zipName,
    required String message,
    Map<String, dynamic>? raw,
  }) =>
      BalanceUpdateResult._(
        success: true,
        steps: steps,
        payoutBalance: payoutBalance,
        zipName: zipName,
        message: message,
        raw: raw,
      );

  factory BalanceUpdateResult.err({
    required BalanceUpdateSteps steps,
    required String message,
    int? statusCode,
    Map<String, dynamic>? raw,
  }) =>
      BalanceUpdateResult._(
        success: false,
        steps: steps,
        message: message,
        statusCode: statusCode,
        raw: raw,
      );

  final bool success;
  final BalanceUpdateSteps steps;
  final String? payoutBalance;
  final String? zipName;
  final String? message;
  final int? statusCode;
  final Map<String, dynamic>? raw;
}

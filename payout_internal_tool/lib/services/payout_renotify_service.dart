import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

enum RenotifyEnvironment { staging, production }

extension RenotifyEnvironmentX on RenotifyEnvironment {
  String get label => this == RenotifyEnvironment.staging ? 'Staging' : 'Production';

  String get notifyUrl {
    switch (this) {
      case RenotifyEnvironment.staging:
        return 'https://payout-scheduler.codapay.net/backoffice/notify';
      case RenotifyEnvironment.production:
        return 'https://payout-scheduler.codainfra.net/backoffice/notify';
    }
  }
}

final _payoutIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

class PayoutIdParseResult {
  const PayoutIdParseResult({
    required this.validIds,
    required this.invalidTokens,
    required this.formattedInput,
  });

  final List<String> validIds;
  final List<String> invalidTokens;
  final String formattedInput;

  bool get isEmpty => validIds.isEmpty;
  bool get hasInvalid => invalidTokens.isNotEmpty;
}

class RenotifyLogEntry {
  RenotifyLogEntry({
    required this.index,
    required this.payoutId,
    required this.statusCode,
    required this.timestamp,
    this.errorMessage,
  });

  final int index;
  final String payoutId;
  final int? statusCode;
  final DateTime timestamp;
  final String? errorMessage;

  bool get isSuccess => statusCode == 200;

  String? get failureReason {
    if (isSuccess) return null;
    if (errorMessage != null && errorMessage!.isNotEmpty) return errorMessage;
    if (statusCode != null) return 'HTTP $statusCode';
    return 'Unknown error';
  }

  String get statusLabel {
    if (isSuccess) return 'Success';
    return 'Failed';
  }
}

class RenotifySummary {
  const RenotifySummary({
    required this.total,
    required this.success,
    required this.failed,
    required this.duration,
  });

  final int total;
  final int success;
  final int failed;
  final Duration duration;
}

class PayoutRenotifyService {
  static const vpnErrorMessage =
      'Please connect to the VPN before using this tool.';

  static const defaultProxyUrl = 'http://127.0.0.1:8747/notify';
  static const defaultProxyHealthUrl = 'http://127.0.0.1:8747/health';

  static String get proxyUrl => _readConfigString('renotifyProxyUrl') ?? defaultProxyUrl;

  static String get proxyHealthUrl =>
      _readConfigString('renotifyProxyHealthUrl') ?? defaultProxyHealthUrl;

  static String? _readConfigString(String key) {
    final config = js_util.getProperty(html.window, 'PE_OPS_CONFIG');
    if (config == null) return null;
    final value = js_util.getProperty(config, key);
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static PayoutIdParseResult parsePayoutIds(String input) {
    final tokens = input
        .split(RegExp(r'[\s,]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final valid = <String>[];
    final invalid = <String>[];
    final seen = <String>{};
    final orderedLines = <String>[];

    for (final token in tokens) {
      if (!_payoutIdPattern.hasMatch(token)) {
        invalid.add(token);
        orderedLines.add(token);
        continue;
      }
      final normalized = token.toLowerCase();
      if (seen.add(normalized)) {
        valid.add(normalized);
        orderedLines.add(normalized);
      }
    }

    return PayoutIdParseResult(
      validIds: valid,
      invalidTokens: invalid,
      formattedInput: orderedLines.join('\n'),
    );
  }

  static bool shouldAutoFormatInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains(',')) return true;
    if (trimmed.contains('\n')) return false;
    return trimmed.contains(' ');
  }

  static String buildCurlCommand({
    required RenotifyEnvironment environment,
    required String payoutId,
  }) {
    final url = environment.notifyUrl;
    final body = const JsonEncoder.withIndent('    ').convert({
      'payoutIds': [payoutId],
    });

    return "curl --location --request POST '$url' \\\n"
        "--header 'Content-Type: application/json' \\\n"
        "--data '$body'";
  }

  static const examplePayoutId = '52954907-e9fb-431a-8489-e48d21323192';

  Future<bool> isLocalProxyAvailable() async {
    try {
      final response = await _xhr(
        method: 'GET',
        url: proxyHealthUrl,
        body: null,
      ).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<RenotifyLogEntry> notifySingle({
    required RenotifyEnvironment environment,
    required String payoutId,
    required int index,
  }) async {
    final timestamp = DateTime.now();
    try {
      final response = await _xhr(
        method: 'POST',
        url: proxyUrl,
        body: jsonEncode({
          'environment': environment.name,
          'payoutId': payoutId,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return RenotifyLogEntry(
          index: index,
          payoutId: payoutId,
          statusCode: response.statusCode,
          timestamp: timestamp,
        );
      }

      return RenotifyLogEntry(
        index: index,
        payoutId: payoutId,
        statusCode: response.statusCode,
        timestamp: timestamp,
        errorMessage: _parseFailureReason(response.statusCode, response.body),
      );
    } catch (e) {
      return RenotifyLogEntry(
        index: index,
        payoutId: payoutId,
        statusCode: null,
        timestamp: timestamp,
        errorMessage: _connectionMessage(e),
      );
    }
  }

  Future<({int statusCode, String body})> _xhr({
    required String method,
    required String url,
    required String? body,
  }) {
    final completer = Completer<({int statusCode, String body})>();
    final request = html.HttpRequest();

    request.open(method, url);
    if (body != null) {
      request.setRequestHeader('Content-Type', 'application/json');
    }

    request.onLoad.listen((_) {
      completer.complete((
        statusCode: request.status ?? 0,
        body: request.responseText ?? '',
      ));
    });

    request.onError.listen((_) {
      completer.completeError(
        StateError(
          'Unable to reach the local renotify proxy at $url. '
          'Run: node tools/renotify-proxy/server.js',
        ),
      );
    });

    request.onTimeout.listen((_) {
      completer.completeError(TimeoutException('Request timed out'));
    });

    request.send(body);
    return completer.future;
  }

  String _parseFailureReason(int statusCode, String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return statusCode == 502 ? vpnErrorMessage : 'Request failed with HTTP $statusCode';
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        for (final key in [
          'message',
          'error',
          'errorMessage',
          'detail',
          'reason',
          'description',
          'result',
        ]) {
          final value = decoded[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString().trim();
          }
        }
      } else if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded.trim();
      }
    } catch (_) {}

    return _truncate(trimmed);
  }

  String _truncate(String value, {int max = 240}) {
    if (value.length <= max) return value;
    return '${value.substring(0, max)}…';
  }

  String _connectionMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('proxy') ||
        message.contains('socket') ||
        message.contains('connection') ||
        message.contains('failed host lookup') ||
        message.contains('network') ||
        message.contains('timeout') ||
        message.contains('xmlhttprequest') ||
        message.contains('cors')) {
      return 'Unable to reach the local renotify proxy. Connect to VPN and run: '
          'node tools/renotify-proxy/server.js';
    }
    return error.toString();
  }

  String buildExportCsv(List<RenotifyLogEntry> entries) {
    final buffer = StringBuffer('Payout ID,Response Status,Reason,Timestamp\n');
    for (final entry in entries) {
      final status = entry.statusCode?.toString() ?? 'Error';
      final reason = _csvEscape(entry.failureReason ?? '');
      buffer.writeln(
        '${entry.payoutId},$status,$reason,${_formatTimestamp(entry.timestamp)}',
      );
    }
    return buffer.toString();
  }

  String buildExportTxt(List<RenotifyLogEntry> entries) {
    final buffer = StringBuffer();
    for (final entry in entries) {
      final status = entry.statusCode?.toString() ?? 'Error';
      final reason = entry.failureReason ?? '';
      buffer.writeln(
        '${entry.payoutId}\t$status\t$reason\t${_formatTimestamp(entry.timestamp)}',
      );
    }
    return buffer.toString();
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String exportFilename({
    required RenotifyEnvironment environment,
    required String extension,
  }) {
    final now = DateTime.now();
    final stamp =
        '${now.year}-${_two(now.month)}-${_two(now.day)}_${_two(now.hour)}-${_two(now.minute)}';
    return 'Renotify_${environment.label}_$stamp.$extension';
  }

  static String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
        '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/payout_renotify_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_surface.dart';
import '../widgets/ops_surface.dart';
import '../widgets/status_pill.dart';

class PayoutRenotifyScreen extends StatefulWidget {
  const PayoutRenotifyScreen({super.key});

  @override
  State<PayoutRenotifyScreen> createState() => _PayoutRenotifyScreenState();
}

class _PayoutRenotifyScreenState extends State<PayoutRenotifyScreen> {
  final _inputController = TextEditingController();
  final _service = PayoutRenotifyService();

  RenotifyEnvironment _environment = RenotifyEnvironment.staging;
  bool _isProcessing = false;
  double _progress = 0;
  int _processedCount = 0;
  int _totalCount = 0;

  List<RenotifyLogEntry> _logEntries = [];
  RenotifySummary? _summary;
  List<String> _invalidTokens = [];

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _onRenotifyPressed() async {
    if (_isProcessing) return;

    final parseResult = PayoutRenotifyService.parsePayoutIds(_inputController.text);
    setState(() => _invalidTokens = parseResult.invalidTokens);

    if (parseResult.isEmpty) {
      _showMessage('Please enter at least one Payout ID.');
      return;
    }

    if (parseResult.hasInvalid) {
      _applyFormattedInput(parseResult);
      _showMessage(
        'Invalid Payout ID format detected. Expected UUID '
        '(e.g. 52954907-e9fb-431a-8489-e48d21323192).',
      );
      return;
    }

    _applyFormattedInput(parseResult);

    final count = parseResult.validIds.length;
    final proceed = await _showConfirmDialog(
      title: 'Confirm renotify',
      message: '$count Payout ID${count == 1 ? '' : 's'} detected. Proceed?',
      confirmLabel: 'Proceed',
    );
    if (proceed != true || !mounted) return;

    if (_environment == RenotifyEnvironment.production) {
      final prodOk = await _showConfirmDialog(
        title: 'Production environment',
        message: 'You are about to renotify in PRODUCTION. Are you sure?',
        confirmLabel: 'Yes, renotify in production',
        destructive: true,
      );
      if (prodOk != true || !mounted) return;
    }

    await _runRenotify(parseResult.validIds);
  }

  Future<void> _runRenotify(List<String> payoutIds) async {
    final startedAt = DateTime.now();
    setState(() {
      _isProcessing = true;
      _progress = 0;
      _processedCount = 0;
      _totalCount = payoutIds.length;
      _logEntries = [];
      _summary = null;
    });

    final entries = <RenotifyLogEntry>[];

    for (var i = 0; i < payoutIds.length; i++) {
      if (!mounted) return;

      final entry = await _service.notifySingle(
        environment: _environment,
        payoutId: payoutIds[i],
        index: i + 1,
      );
      entries.add(entry);

      setState(() {
        _logEntries = List.unmodifiable(entries);
        _processedCount = i + 1;
        _progress = _processedCount / payoutIds.length;
      });

      await Future<void>.delayed(Duration.zero);
    }

    if (!mounted) return;

    final success = entries.where((e) => e.isSuccess).length;
    setState(() {
      _isProcessing = false;
      _summary = RenotifySummary(
        total: entries.length,
        success: success,
        failed: entries.length - success,
        duration: DateTime.now().difference(startedAt),
      );
    });
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text(
          message,
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _applyFormattedInput(PayoutIdParseResult result) {
    if (result.formattedInput == _inputController.text) return;
    _inputController.value = TextEditingValue(
      text: result.formattedInput,
      selection: TextSelection.collapsed(offset: result.formattedInput.length),
    );
  }

  void _onInputChanged(String value) {
    final parseResult = PayoutRenotifyService.parsePayoutIds(value);
    setState(() => _invalidTokens = parseResult.invalidTokens);

    if (!PayoutRenotifyService.shouldAutoFormatInput(value)) return;
    if (parseResult.formattedInput == value) return;

    _inputController.value = TextEditingValue(
      text: parseResult.formattedInput,
      selection: TextSelection.collapsed(offset: parseResult.formattedInput.length),
    );
    setState(() => _invalidTokens = parseResult.invalidTokens);
  }

  void _downloadExport(String content, String filename) {
    final bytes = Uint8List.fromList(content.codeUnits);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _exportCsv() {
    if (_logEntries.isEmpty) return;
    _downloadExport(
      _service.buildExportCsv(_logEntries),
      _service.exportFilename(environment: _environment, extension: 'csv'),
    );
  }

  void _exportTxt() {
    if (_logEntries.isEmpty) return;
    _downloadExport(
      _service.buildExportTxt(_logEntries),
      _service.exportFilename(environment: _environment, extension: 'txt'),
    );
  }

  void _reset() {
    setState(() {
      _logEntries = [];
      _summary = null;
      _invalidTokens = [];
      _progress = 0;
      _processedCount = 0;
      _totalCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.page,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 960;
          if (stacked) {
            return ListView(
              children: [
                _buildInputPanel(scrollable: true),
                const SizedBox(height: AppSpacing.section),
                SizedBox(height: 520, child: _buildLogPanel(expand: true)),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: _buildInputPanel(scrollable: false)),
              const SizedBox(width: AppSpacing.section),
              Expanded(flex: 3, child: _buildLogPanel(expand: true)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputPanel({required bool scrollable}) {
    final fields = _buildInputFields();

    if (scrollable) {
      return OpsSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEnvironmentHeader(),
            const SizedBox(height: 20),
            ...fields,
            const SizedBox(height: 20),
            _buildActionButtons(),
          ],
        ),
      );
    }

    return OpsSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEnvironmentHeader(),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: fields,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  List<Widget> _buildInputFields() {
    return [
      Text(
        'Payout IDs',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Paste UUIDs one per line, or separate with commas or spaces — '
        'they will be reformatted automatically.',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.textMutedOnDark,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _inputController,
        enabled: !_isProcessing,
        minLines: 6,
        maxLines: 8,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText:
              '52954907-e9fb-431a-8489-e48d21323192\n'
              'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          hintStyle: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            color: AppColors.textMutedOnDark,
          ),
          filled: true,
          fillColor: AppColors.surfaceMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: const BorderSide(color: AppColors.borderDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: BorderSide(
              color: _invalidTokens.isNotEmpty
                  ? AppColors.error.withValues(alpha: 0.6)
                  : AppColors.borderDark,
            ),
          ),
        ),
        onChanged: _onInputChanged,
      ),
      if (_invalidTokens.isNotEmpty) ...[
        const SizedBox(height: 10),
        _buildInvalidWarning(),
      ],
      if (_isProcessing) ...[
        const SizedBox(height: 20),
        _buildProgress(),
      ],
    ];
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _isProcessing ? null : _onRenotifyPressed,
            icon: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.void_,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_isProcessing ? 'Processing…' : 'Renotify'),
          ),
        ),
        if (_logEntries.isNotEmpty && !_isProcessing) ...[
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: _reset,
            child: const Text('Clear log'),
          ),
        ],
      ],
    );
  }

  Widget _buildEnvironmentHeader() {
    final isProduction = _environment == RenotifyEnvironment.production;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Environment',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isProduction
                    ? 'Production scheduler — use with caution'
                    : 'Staging scheduler for testing',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMutedOnDark,
                ),
              ),
            ],
          ),
        ),
        StatusPill(
          label: _environment.label,
          tone: isProduction ? StatusPillTone.error : StatusPillTone.warning,
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Staging',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: !isProduction
                    ? AppColors.textPrimary
                    : AppColors.textMutedOnDark,
              ),
            ),
            Switch(
              value: isProduction,
              onChanged: _isProcessing
                  ? null
                  : (value) {
                      setState(() {
                        _environment = value
                            ? RenotifyEnvironment.production
                            : RenotifyEnvironment.staging;
                      });
                    },
            ),
            Text(
              'Production',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isProduction
                    ? AppColors.error
                    : AppColors.textMutedOnDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInvalidWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Invalid UUID: ${_invalidTokens.join(', ')}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                height: 1.4,
                color: AppColors.error,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Processing $_processedCount of $_totalCount…',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${(_progress * 100).round()}%',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 6,
            backgroundColor: AppColors.surfaceMuted,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildLogPanel({required bool expand}) {
    final tableArea = _logEntries.isEmpty ? _buildEmptyLog() : _buildLogTable();

    return OpsSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Transaction log',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (_logEntries.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('CSV'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _exportTxt,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('TXT'),
                  ),
                ],
              ],
            ),
          ),
          if (_summary != null) _buildSummary(_summary!),
          if (_logEntries.isNotEmpty) _buildTableHeader(),
          if (expand) Expanded(child: tableArea) else SizedBox(height: 400, child: tableArea),
        ],
      ),
    );
  }

  Widget _buildEmptyLog() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 40, color: AppColors.textMutedOnDark),
            const SizedBox(height: 12),
            Text(
              'Results will appear here',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(RenotifySummary summary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: GlassSurface(
        padding: const EdgeInsets.all(16),
        radius: AppRadii.md,
        child: Row(
          children: [
            _summaryStat('Submitted', summary.total.toString()),
            _summaryStat('Success', summary.success.toString(),
                color: AppColors.success),
            _summaryStat('Failed', summary.failed.toString(),
                color: AppColors.error),
            _summaryStat(
              'Time',
              '${summary.duration.inSeconds}s',
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryStat(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textMutedOnDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('#', style: _headerStyle),
          ),
          Expanded(flex: 2, child: Text('Payout ID', style: _headerStyle)),
          SizedBox(width: 100, child: Text('Status', style: _headerStyle)),
          SizedBox(width: 72, child: Text('Code', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Timestamp', style: _headerStyle)),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textMutedOnDark,
        letterSpacing: 0.3,
      );

  Widget _buildLogTable() {
    return ListView.builder(
      itemCount: _logEntries.length,
      itemBuilder: (context, index) => _LogRow(entry: _logEntries[index]),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final RenotifyLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final success = entry.isSuccess;
    final bg = success
        ? AppColors.success.withValues(alpha: 0.06)
        : AppColors.error.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${entry.index}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMutedOnDark,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  entry.payoutId,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: Row(
                  children: [
                    Icon(
                      success ? Icons.check_circle : Icons.cancel,
                      size: 14,
                      color: success ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: success ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  entry.statusCode?.toString() ?? '—',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _formatTime(entry.timestamp),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textMutedOnDark,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          if (!success && entry.failureReason != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.failureReason!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.error,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

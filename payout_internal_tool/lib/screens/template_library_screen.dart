import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../templates/holiday_notice_pdf.dart';
import '../templates/holiday_notice_template.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_surface.dart';
import '../widgets/status_pill.dart';

class TemplateLibraryScreen extends StatefulWidget {
  const TemplateLibraryScreen({super.key});

  @override
  State<TemplateLibraryScreen> createState() => _TemplateLibraryScreenState();
}

class _TemplateLibraryScreenState extends State<TemplateLibraryScreen> {
  final _myHolidayController = TextEditingController(text: 'Hari Raya Aidilfitri');
  final _idHolidayController = TextEditingController(text: 'Hari Raya Idul Fitri');
  final _sgHolidayController = TextEditingController(text: 'Hari Raya Puasa');
  final _singleDateController = TextEditingController(text: '10 April 2026');
  final _rangeStartController = TextEditingController(text: '10 April 2026');
  final _rangeEndController = TextEditingController(text: '12 April 2026');

  HolidayDateMode _dateMode = HolidayDateMode.single;

  late final String _previewViewType;
  html.IFrameElement? _previewFrame;

  int _selectedTemplate = 0;

  static const _templates = [
    (
      id: 'holiday_notice',
      name: 'Payout Balance Notice',
      description: 'Advisory when MY, ID, and SG finance teams have an upcoming holiday',
    ),
  ];

  static const _receptionListUrl =
      'https://docs.google.com/spreadsheets/d/1Ud6EKkBElwWmu-80chUvK-zOQgNfT1JPItzyS8mq8Dc/edit?gid=621262899#gid=621262899';

  @override
  void initState() {
    super.initState();
    _previewViewType =
        'template-preview-${DateTime.now().millisecondsSinceEpoch}';
    _registerPreview();
  }

  void _registerPreview() {
    ui_web.platformViewRegistry.registerViewFactory(
      _previewViewType,
      (int viewId) {
        _previewFrame = html.IFrameElement()
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..setAttribute('sandbox', 'allow-same-origin');
        _syncPreview();
        return _previewFrame!;
      },
    );
  }

  void _syncPreview() {
    _previewFrame?.srcdoc = _generatedHtml;
  }

  HolidayDateInput get _dateInput => HolidayDateInput(
        mode: _dateMode,
        singleDate: _singleDateController.text,
        rangeStart: _rangeStartController.text,
        rangeEnd: _rangeEndController.text,
      );

  String get _generatedHtml => buildHolidayNoticeHtml(
        malaysiaHolidayName: _myHolidayController.text,
        indonesiaHolidayName: _idHolidayController.text,
        singaporeHolidayName: _sgHolidayController.text,
        dateInput: _dateInput,
      );

  String get _emailSubject => buildHolidayNoticeSubject(_dateInput);

  @override
  void dispose() {
    _myHolidayController.dispose();
    _idHolidayController.dispose();
    _sgHolidayController.dispose();
    _singleDateController.dispose();
    _rangeStartController.dispose();
    _rangeEndController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPreview());
  }

  Future<void> _downloadPdf() async {
    try {
      final bytes = await buildHolidayNoticePdf(
        malaysiaHolidayName: _myHolidayController.text,
        indonesiaHolidayName: _idHolidayController.text,
        singaporeHolidayName: _sgHolidayController.text,
        dateInput: _dateInput,
      );
      final filename = buildHolidayNoticePdfFilename(_dateInput);
      _triggerBrowserDownload(bytes, filename);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded $filename')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  void _triggerBrowserDownload(Uint8List bytes, String filename) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _copyHtml() async {
    await Clipboard.setData(ClipboardData(text: _generatedHtml));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('HTML copied to clipboard')),
    );
  }

  Future<void> _copySubject() async {
    await Clipboard.setData(ClipboardData(text: _emailSubject));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subject line copied to clipboard')),
    );
  }

  void _openReceptionList() {
    html.window.open(_receptionListUrl, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return Column(
            children: [
              SizedBox(
                height: 500,
                child: _buildSidebar(context),
              ),
              const Divider(height: 1, color: AppColors.glassBorder),
              Expanded(child: _buildPreviewPanel(context)),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 360, child: _buildSidebar(context)),
            const VerticalDivider(width: 1, color: AppColors.glassBorder),
            Expanded(child: _buildPreviewPanel(context)),
          ],
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, AppSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Template library', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Fill in the fields to generate publisher-ready HTML.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _buildReceptionListCallout(),
          const SizedBox(height: 20),
          ...List.generate(_templates.length, (i) {
            final t = _templates[i];
            final selected = _selectedTemplate == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selectedTemplate = i),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      color: selected ? AppColors.surfaceMuted : AppColors.surface,
                      border: Border.all(
                        color: selected
                            ? AppColors.accent.withValues(alpha: 0.4)
                            : AppColors.glassBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 16,
                              color: selected
                                  ? AppColors.accentHover
                                  : AppColors.textMutedOnDark,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t.name,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.description,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          _buildSection(
            title: 'Notice details',
            children: [
              _buildField(
                label: 'Malaysia — occasion',
                hint: 'e.g. Hari Raya Aidilfitri',
                controller: _myHolidayController,
              ),
              const SizedBox(height: 12),
              _buildField(
                label: 'Indonesia — occasion',
                hint: 'e.g. Hari Raya Idul Fitri',
                controller: _idHolidayController,
              ),
              const SizedBox(height: 12),
              _buildField(
                label: 'Singapore — occasion',
                hint: 'e.g. Hari Raya Puasa',
                controller: _sgHolidayController,
              ),
              const SizedBox(height: 16),
              Text(
                'Affected date',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _buildDateModeToggle(),
              const SizedBox(height: 12),
              if (_dateMode == HolidayDateMode.single)
                _buildField(
                  label: 'Affected date',
                  hint: 'e.g. 10 April 2026',
                  controller: _singleDateController,
                )
              else ...[
                _buildField(
                  label: 'Start date',
                  hint: 'e.g. 10 April 2026',
                  controller: _rangeStartController,
                ),
                const SizedBox(height: 12),
                _buildField(
                  label: 'End date',
                  hint: 'e.g. 12 April 2026',
                  controller: _rangeEndController,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Email subject',
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  _emailSubject,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _copySubject,
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy subject line'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceptionListCallout() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openReceptionList,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: AppColors.accentHover,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Reception list',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const StatusPill(
                                label: 'Required',
                                tone: StatusPillTone.warning,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Before sending, open the spreadsheet to confirm who should receive this announcement.',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _openReceptionList,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open reception list'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDateModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _dateModeChip(
              label: 'Single date',
              selected: _dateMode == HolidayDateMode.single,
              onTap: () {
                setState(() => _dateMode = HolidayDateMode.single);
                _onFieldChanged();
              },
            ),
          ),
          Expanded(
            child: _dateModeChip(
              label: 'Date range',
              selected: _dateMode == HolidayDateMode.range,
              onTap: () {
                setState(() => _dateMode = HolidayDateMode.range);
                _onFieldChanged();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateModeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            color: selected ? AppColors.surfaceMuted : Colors.transparent,
            border: selected
                ? Border.all(color: AppColors.accent.withValues(alpha: 0.35))
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: (_) => _onFieldChanged(),
          style: GoogleFonts.ibmPlexSans(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildReceptionListBanner() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openReceptionList,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  size: 18,
                  color: AppColors.accentHover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Check the reception list before sending this announcement.',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _openReceptionList,
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Open list'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                  foregroundColor: AppColors.accentHover,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewPanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, AppSpacing.page, AppSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Preview', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 10),
              const StatusPill(label: 'Live', tone: StatusPillTone.info),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('Download PDF'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _copyHtml,
                icon: const Icon(Icons.code, size: 16),
                label: const Text('Copy HTML'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildReceptionListBanner(),
          const SizedBox(height: 12),
          Expanded(
            child: GlassSurface(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: ColoredBox(
                  color: const Color(0xFFF4F6F8),
                  child: HtmlElementView(viewType: _previewViewType),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

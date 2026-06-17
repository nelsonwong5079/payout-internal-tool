import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'holiday_notice_template.dart';

/// Default PDF fonts only support basic Latin; normalise punctuation.
String pdfSafeText(String input) {
  return input
      .replaceAll(' \u2014 ', ' - ')
      .replaceAll(' \u2013 ', ' - ')
      .replaceAll('\u2014', '-')
      .replaceAll('\u2013', '-')
      .replaceAll('\u2018', "'")
      .replaceAll('\u2019', "'");
}

/// Builds a PDF version of the payout balance notice for download.
Future<Uint8List> buildHolidayNoticePdf({
  required String malaysiaHolidayName,
  required String indonesiaHolidayName,
  required String singaporeHolidayName,
  required HolidayDateInput dateInput,
}) async {
  final subject = pdfSafeText(buildHolidayNoticeSubject(dateInput));
  final date = pdfSafeText(dateInput.displayText);
  final my = pdfSafeText(malaysiaHolidayName.trim());
  final id = pdfSafeText(indonesiaHolidayName.trim());
  final sg = pdfSafeText(singaporeHolidayName.trim());

  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      build: (context) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('1E293B'),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                subject,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'SERVICE ADVISORY',
                style: pw.TextStyle(
                  color: PdfColor.fromHex('FBBF24'),
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Text('Dear Publisher Partner,', style: _bodyStyle()),
        pw.SizedBox(height: 12),
        pw.RichText(
          text: pw.TextSpan(
            style: _bodyStyle(),
            children: [
              pw.TextSpan(
                text:
                    'We would like to inform you that we will have an upcoming public holiday ${dateInput.introPhrase}. During this period, ',
              ),
              pw.TextSpan(
                text: 'payout balance top-ups and net-offs',
                style: _bodyStyle(bold: true),
              ),
              const pw.TextSpan(
                text:
                    ' will be temporarily unavailable. Your regular payout processing will ',
              ),
              pw.TextSpan(
                text: 'not',
                style: _bodyStyle(bold: true),
              ),
              const pw.TextSpan(text: ' be affected.'),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('F8FAFC'),
            border: pw.Border.all(color: PdfColor.fromHex('3B82F6'), width: 1.5),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                dateInput.dateLabel.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('64748B'),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                date,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('1E293B'),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _countryCard('Finance colleagues - Malaysia', my)),
            pw.SizedBox(width: 10),
            pw.Expanded(child: _countryCard('Finance colleagues - Indonesia', id)),
            pw.SizedBox(width: 10),
            pw.Expanded(child: _countryCard('Finance colleagues - Singapore', sg)),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'SERVICE IMPACT',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('1E293B'),
          ),
        ),
        pw.SizedBox(height: 8),
        _impactItem(
          'Payout balance top-ups will be unavailable ${dateInput.impactPhrase}.',
          affected: true,
        ),
        _impactItem(
          'Payout balance net-offs will be unavailable ${dateInput.impactPhrase}.',
          affected: true,
        ),
        _impactItem(
          pdfSafeText(
            'Regular payout processing will continue as usual - this advisory does not affect payout speed or settlement timelines.',
          ),
          affected: false,
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('FFFBEB'),
            border: pw.Border.all(color: PdfColor.fromHex('FDE68A')),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            'We apologise for any inconvenience to your balance management during this period. Top-up and net-off services will resume once our finance colleagues return from the holiday. There is no change to how your existing payout transactions are processed.',
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColor.fromHex('92400E'),
              lineSpacing: 4,
            ),
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('F0FDF4'),
            border: pw.Border.all(color: PdfColor.fromHex('BBF7D0')),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            'Please take note of this advisory and plan any balance top-ups or net-offs ${dateInput.planAheadPhrase}. No action is required for your ongoing payout transactions.',
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColor.fromHex('15803D'),
              lineSpacing: 4,
            ),
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Should you have any questions, please reach out to your account manager or support contact.',
          style: _bodyStyle(),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Thank you for your understanding.',
          style: _bodyStyle(bold: true),
        ),
        pw.SizedBox(height: 24),
        pw.Divider(color: PdfColor.fromHex('E2E8F0')),
        pw.SizedBox(height: 8),
        pw.Text(
          'This is an automated service advisory. Please do not reply directly to this message.',
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColor.fromHex('94A3B8'),
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    ),
  );

  return doc.save();
}

String buildHolidayNoticePdfFilename(HolidayDateInput dateInput) {
  final slug = dateInput.displayText
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final suffix = slug.isEmpty ? 'draft' : slug;
  return 'payout-balance-notice-$suffix.pdf';
}

pw.TextStyle _bodyStyle({bool bold = false}) => pw.TextStyle(
      fontSize: 11,
      color: PdfColor.fromHex('334155'),
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      lineSpacing: 4,
    );

pw.Widget _countryCard(String label, String occasion) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromHex('F8FAFC'),
      border: pw.Border.all(color: PdfColor.fromHex('E2E8F0')),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          pdfSafeText(label).toUpperCase(),
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('64748B'),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          occasion,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('1E293B'),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _impactItem(String text, {required bool affected}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 6,
          height: 6,
          margin: const pw.EdgeInsets.only(top: 4, right: 8),
          decoration: pw.BoxDecoration(
            color: affected
                ? PdfColor.fromHex('EF4444')
                : PdfColor.fromHex('22C55E'),
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.Expanded(
          child: pw.Text(pdfSafeText(text), style: _bodyStyle()),
        ),
      ],
    ),
  );
}

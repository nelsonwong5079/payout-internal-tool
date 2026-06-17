enum HolidayDateMode { single, range }

/// User-facing date configuration for the holiday notice template.
class HolidayDateInput {
  const HolidayDateInput({
    required this.mode,
    this.singleDate = '',
    this.rangeStart = '',
    this.rangeEnd = '',
  });

  final HolidayDateMode mode;
  final String singleDate;
  final String rangeStart;
  final String rangeEnd;

  String get displayText {
    if (mode == HolidayDateMode.single) {
      return singleDate.trim();
    }
    final start = rangeStart.trim();
    final end = rangeEnd.trim();
    if (start.isEmpty && end.isEmpty) return '';
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start – $end';
  }

  String get dateLabel => mode == HolidayDateMode.single
      ? 'Affected Date'
      : 'Affected Date Range';

  String get introPhrase => mode == HolidayDateMode.single
      ? 'on the date below'
      : 'during the period below';

  String get impactPhrase => mode == HolidayDateMode.single
      ? 'on the affected date'
      : 'during the affected period';

  String get planAheadPhrase => mode == HolidayDateMode.single
      ? 'before the affected date if you anticipate needing either service'
      : 'before the affected period if you anticipate needing either service';
}

String buildHolidayNoticeSubject(HolidayDateInput dateInput) {
  final date = dateInput.displayText;
  return 'Important Notice — Payout Top Up Balance Services Unavailable $date';
}

/// Generates a professional HTML payout balance advisory when finance-team countries have upcoming holidays.
String buildHolidayNoticeHtml({
  required String malaysiaHolidayName,
  required String indonesiaHolidayName,
  required HolidayDateInput dateInput,
}) {
  final my = _escapeHtml(malaysiaHolidayName.trim());
  final id = _escapeHtml(indonesiaHolidayName.trim());
  final date = _escapeHtml(dateInput.displayText);
  final dateLabel = _escapeHtml(dateInput.dateLabel);
  final introPhrase = dateInput.introPhrase;
  final impactPhrase = dateInput.impactPhrase;
  final planAheadPhrase = dateInput.planAheadPhrase;
  final subject = _escapeHtml(buildHolidayNoticeSubject(dateInput));

  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$subject</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background: #f4f6f8;
      color: #1a1a2e;
      line-height: 1.6;
      padding: 24px 16px;
    }
    .email-wrapper {
      max-width: 640px;
      margin: 0 auto;
      background: #ffffff;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
      border: 1px solid #e2e8f0;
    }
    .header-bar {
      background: #1e293b;
      padding: 20px 28px;
    }
    .subject-line {
      font-size: 15px;
      font-weight: 600;
      color: #f8fafc;
      letter-spacing: -0.01em;
      line-height: 1.4;
    }
    .badge {
      display: inline-block;
      margin-top: 10px;
      padding: 4px 10px;
      background: rgba(251, 191, 36, 0.15);
      color: #fbbf24;
      font-size: 11px;
      font-weight: 600;
      letter-spacing: 0.06em;
      text-transform: uppercase;
      border-radius: 4px;
      border: 1px solid rgba(251, 191, 36, 0.3);
    }
    .body-content { padding: 28px; }
    .greeting {
      font-size: 15px;
      color: #334155;
      margin-bottom: 20px;
    }
    .date-highlight {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-left: 4px solid #3b82f6;
      border-radius: 6px;
      padding: 18px 20px;
      margin-bottom: 24px;
      text-align: center;
    }
    .date-label {
      font-size: 11px;
      font-weight: 600;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: #64748b;
      margin-bottom: 6px;
    }
    .date-value {
      font-size: 22px;
      font-weight: 700;
      color: #1e293b;
      letter-spacing: -0.02em;
    }
    .holiday-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-bottom: 24px;
    }
    @media (max-width: 480px) {
      .holiday-grid { grid-template-columns: 1fr; }
      .body-content { padding: 20px; }
      .date-value { font-size: 18px; }
    }
    .holiday-card {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 6px;
      padding: 14px 16px;
    }
    .country-label {
      font-size: 11px;
      font-weight: 600;
      letter-spacing: 0.06em;
      text-transform: uppercase;
      color: #64748b;
      margin-bottom: 4px;
    }
    .holiday-name {
      font-size: 14px;
      font-weight: 600;
      color: #1e293b;
    }
    .section-title {
      font-size: 13px;
      font-weight: 700;
      color: #1e293b;
      margin-bottom: 10px;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }
    .impact-list {
      list-style: none;
      margin-bottom: 24px;
    }
    .impact-list li {
      position: relative;
      padding: 10px 0 10px 24px;
      font-size: 14px;
      color: #475569;
      border-bottom: 1px solid #f1f5f9;
    }
    .impact-list li:last-child { border-bottom: none; }
    .impact-list li::before {
      content: "";
      position: absolute;
      left: 0;
      top: 16px;
      width: 8px;
      height: 8px;
      background: #ef4444;
      border-radius: 50%;
    }
    .impact-list li.unaffected::before { background: #22c55e; }
    .impact-list li strong { color: #1e293b; }
    .notice-box {
      background: #fffbeb;
      border: 1px solid #fde68a;
      border-radius: 6px;
      padding: 16px 18px;
      margin-bottom: 24px;
    }
    .notice-box p {
      font-size: 14px;
      color: #92400e;
      line-height: 1.55;
    }
    .acknowledgement {
      background: #f0fdf4;
      border: 1px solid #bbf7d0;
      border-radius: 6px;
      padding: 18px 20px;
      margin-bottom: 24px;
    }
    .acknowledgement .section-title { color: #166534; }
    .acknowledgement p {
      font-size: 14px;
      color: #15803d;
      line-height: 1.55;
    }
    .closing {
      font-size: 14px;
      color: #475569;
      margin-bottom: 8px;
    }
    .sign-off {
      font-size: 14px;
      color: #334155;
      font-weight: 500;
    }
    .footer {
      background: #f8fafc;
      border-top: 1px solid #e2e8f0;
      padding: 16px 28px;
      text-align: center;
    }
    .footer p {
      font-size: 12px;
      color: #94a3b8;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <div class="email-wrapper">
    <div class="header-bar">
      <p class="subject-line">$subject</p>
      <span class="badge">Service Advisory</span>
    </div>

    <div class="body-content">
      <p class="greeting">Dear Publisher Partner,</p>

      <p class="greeting" style="margin-top: -8px;">
        We would like to inform you that our finance colleagues in <strong>Malaysia and Indonesia</strong> will have an upcoming public holiday $introPhrase. During this period, <strong>payout balance top-ups and net-offs</strong> will be temporarily unavailable. Your regular payout processing will <strong>not</strong> be affected.
      </p>

      <div class="date-highlight">
        <div class="date-label">$dateLabel</div>
        <div class="date-value">$date</div>
      </div>

      <div class="holiday-grid">
        <div class="holiday-card">
          <div class="country-label">Finance colleagues — Malaysia</div>
          <div class="holiday-name">$my</div>
        </div>
        <div class="holiday-card">
          <div class="country-label">Finance colleagues — Indonesia</div>
          <div class="holiday-name">$id</div>
        </div>
      </div>

      <div class="section-title">Service Impact</div>
      <ul class="impact-list">
        <li><strong>Payout balance top-ups</strong> will be unavailable $impactPhrase.</li>
        <li><strong>Payout balance net-offs</strong> will be unavailable $impactPhrase.</li>
        <li class="unaffected"><strong>Regular payout processing</strong> will continue as usual — this advisory does not affect payout speed or settlement timelines.</li>
      </ul>

      <div class="notice-box">
        <p>We apologise for any inconvenience to your balance management during this period. Top-up and net-off services will resume once our finance colleagues return from the holiday. There is no change to how your existing payout transactions are processed.</p>
      </div>

      <div class="acknowledgement">
        <p>Please take note of this advisory and plan any balance top-ups or net-offs $planAheadPhrase. No action is required for your ongoing payout transactions.</p>
      </div>

      <p class="closing">Should you have any questions, please reach out to your account manager or support contact.</p>
      <p class="sign-off">Thank you for your understanding.</p>
    </div>

    <div class="footer">
      <p>This is an automated service advisory. Please do not reply directly to this message.</p>
    </div>
  </div>
</body>
</html>''';
}

String _escapeHtml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

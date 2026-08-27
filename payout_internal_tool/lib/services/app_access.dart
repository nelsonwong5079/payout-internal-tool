/// Access roles for the PE Ops web app.
///
/// Firebase Auth only proves identity. This layer decides which modules a
/// signed-in user may see. Keep client emails in [kHostedCardClientEmails]
/// after creating the user in Firebase Console → Authentication.
enum AppRole {
  /// Full internal tooling (default for staff accounts).
  operator,

  /// External / client demo — Hosted Card only, no internal credentials UI.
  hostedCardClient,
}

/// Emails that may ONLY use Hosted Card (external-facing).
///
/// Create the Firebase Auth user first (Console → Authentication → Add user),
/// then add the exact email here (lowercase). Redeploy hosting after changes.
const Set<String> kHostedCardClientEmails = {
  'hosted-card.client@codapayments.com',
  'zynga_use@codapayments.com',
};

AppRole roleForEmail(String? email) {
  final normalized = (email ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return AppRole.operator;
  if (kHostedCardClientEmails.contains(normalized)) {
    return AppRole.hostedCardClient;
  }
  return AppRole.operator;
}

extension AppRoleX on AppRole {
  bool get isHostedCardClientOnly => this == AppRole.hostedCardClient;

  String get label {
    switch (this) {
      case AppRole.operator:
        return 'OPERATOR';
      case AppRole.hostedCardClient:
        return 'CLIENT';
    }
  }
}

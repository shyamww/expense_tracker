/// [Web3Forms](https://web3forms.com) — your inbox is tied to this key in their dashboard, not stored as raw email in the app.
///
/// ## What to enter in the Web3Forms dashboard
///
/// **Form name**
/// Any label **only you** see in the dashboard to find this form later.
/// Example: `Expense Tracker` or `Mobile app feedback`.
/// It does **not** affect how emails look or what the app sends.
///
/// **Domain / website** (if the signup form asks for it)
/// - If you have a **real website** for the app (landing page, etc.), use that URL, e.g. `https://yoursite.com`.
/// - If this is **mobile-only** for now, use a placeholder you control later (e.g. a simple GitHub Pages URL) **or** the domain Web3Forms shows as optional — many flows only require your **email** to create the key.
/// **Domain allowlisting** (only accept submissions from one site) is a **Pro** feature; without it, your **access key** still works from the Flutter app.
///
/// ## After you create the form
///
/// 1. Copy your **Access Key** (a UUID) from the Web3Forms dashboard.
/// 2. Build with `--dart-define=WEB3FORMS_ACCESS_KEY=your-key`.
/// 3. Without that value, the feedback form stays disabled instead of exposing
///    a real key in source control.
///
/// Docs: https://docs.web3forms.com/getting-started/api-reference
const String kWeb3FormsAccessKey =
    String.fromEnvironment('WEB3FORMS_ACCESS_KEY');

/// Email subject line for feedback notifications you receive.
const String kFeedbackEmailSubject = 'Fixed';

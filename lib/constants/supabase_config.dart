import 'dart:convert';

class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://izhchozwkbamfnfdbfqw.supabase.co',
  );
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String authRedirectUrl = String.fromEnvironment(
    'SUPABASE_AUTH_REDIRECT_URL',
    defaultValue: 'https://shyamww.github.io/expense_tracker/',
  );

  static bool get isConfigured {
    final parsed = Uri.tryParse(url.trim());
    final key = anonKey.trim();
    return parsed != null &&
        parsed.hasScheme &&
        parsed.host.isNotEmpty &&
        (_isJwtKey(key) || key.startsWith('sb_publishable_'));
  }

  static bool _isJwtKey(String key) {
    final parts = key.split('.');
    if (parts.length != 3) return false;

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return false;
      return decoded['role'] == 'anon' && decoded['ref'] == _projectRef;
    } catch (_) {
      return false;
    }
  }

  static String? get _projectRef {
    final host = Uri.tryParse(url.trim())?.host;
    const suffix = '.supabase.co';
    if (host == null || !host.endsWith(suffix)) return null;
    return host.substring(0, host.length - suffix.length);
  }
}

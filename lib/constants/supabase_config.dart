class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://izhchozwkbamfnfdbfqw.supabase.co',
  );
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured {
    final parsed = Uri.tryParse(url.trim());
    return parsed != null &&
        parsed.hasScheme &&
        parsed.host.isNotEmpty &&
        anonKey.trim().isNotEmpty;
  }
}

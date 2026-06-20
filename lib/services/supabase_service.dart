import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_config.dart';

class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  static bool get isConfigured => SupabaseConfig.isConfigured;
  static bool get isReady => _initialized;

  static SupabaseClient? get client {
    if (!_initialized) return null;
    return Supabase.instance.client;
  }

  static User? get currentUser => client?.auth.currentUser;
  static String? get currentUserId => currentUser?.id;

  static Future<void> initialize() async {
    if (!isConfigured || _initialized) return;
    await Supabase.initialize(
      url: SupabaseConfig.url.trim(),
      publishableKey: SupabaseConfig.anonKey.trim(),
    );
    _initialized = true;
  }
}

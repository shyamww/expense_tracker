import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../constants/supabase_config.dart';

class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;
  static String? _initializationError;

  static bool get isConfigured => SupabaseConfig.isConfigured;
  static bool get isReady => _initialized;
  static String? get initializationError => _initializationError;

  static SupabaseClient? get client {
    if (!_initialized) return null;
    return Supabase.instance.client;
  }

  static User? get currentUser => client?.auth.currentUser;
  static String? get currentUserId => currentUser?.id;

  static Future<void> initialize() async {
    if (!isConfigured || _initialized) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url.trim(),
        publishableKey: SupabaseConfig.anonKey.trim(),
      ).timeout(const Duration(seconds: 5));
      _initialized = true;
      _initializationError = null;
    } catch (e, st) {
      _initialized = false;
      _initializationError = e.toString();
      debugPrint('Supabase init failed: $e\n$st');
    }
  }
}

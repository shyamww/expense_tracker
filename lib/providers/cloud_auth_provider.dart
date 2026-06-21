import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_config.dart';
import '../services/supabase_service.dart';

class CloudAuthProvider extends ChangeNotifier {
  Session? _session;
  StreamSubscription<AuthState>? _subscription;
  bool _loaded = false;
  bool _loading = false;

  bool get isConfigured => SupabaseService.isConfigured;
  bool get isReady => _loaded;
  bool get isLoading => _loading;
  bool get isSignedIn => user != null;
  User? get user => _session?.user ?? SupabaseService.currentUser;
  String? get email => user?.email;
  String? get setupError => SupabaseService.initializationError;

  Future<void> load() async {
    if (_loaded || _loading) return;
    _loading = true;
    notifyListeners();

    if (!isConfigured || !SupabaseService.isReady) {
      await SupabaseService.initialize();
    }

    if (!isConfigured || !SupabaseService.isReady) {
      _loaded = true;
      _loading = false;
      notifyListeners();
      return;
    }

    final auth = SupabaseService.client!.auth;
    _session = auth.currentSession;
    _subscription = auth.onAuthStateChange.listen((state) {
      _session = state.session;
      notifyListeners();
    });
    _loaded = true;
    _loading = false;
    notifyListeners();
  }

  Future<void> _ensureLoaded() async {
    if (!_loaded) await load();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _ensureLoaded();
    final client = SupabaseService.client;
    if (client == null) {
      throw StateError(setupError ?? 'supabase_not_configured');
    }
    final res = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    _session = res.session;
    notifyListeners();
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await _ensureLoaded();
    final client = SupabaseService.client;
    if (client == null) {
      throw StateError(setupError ?? 'supabase_not_configured');
    }
    final res = await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: SupabaseConfig.authRedirectUrl,
    );
    _session = res.session;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _ensureLoaded();
    final client = SupabaseService.client;
    if (client == null) return;
    await client.auth.signOut();
    _session = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

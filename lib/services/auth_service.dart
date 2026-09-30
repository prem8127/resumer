import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_config.dart';

class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
}

/// Supabase Auth backed by Google OAuth.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  bool _initialized = false;
  bool get isInitialized => _initialized;

  SupabaseClient get _client => Supabase.instance.client;

  Stream<User?> get authStateChanges {
    if (!_initialized) return const Stream.empty();
    return _client.auth.onAuthStateChange.map((state) => state.session?.user);
  }

  User? get currentUser => _initialized ? _client.auth.currentUser : null;
  String? get accessToken =>
      _initialized ? _client.auth.currentSession?.accessToken : null;
  bool get isSignedIn => currentUser != null;

  static String signInErrorMessage(Object error) {
    if (error is AuthException) {
      final text = error.message.toLowerCase();
      if (text.contains('provider') || text.contains('google')) {
        return 'Google sign-in is not enabled in your Supabase project.';
      }
      if (text.contains('redirect') || text.contains('url')) {
        return 'The sign-in return URL is not allowed in Supabase Auth settings.';
      }
    }
    return 'Sign-in failed. Check your connection and Supabase Google sign-in settings.';
  }

  Future<void> initialize() async {
    if (_initialized) return;
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
    _initialized = true;
  }

  Future<User?> signInWithGoogle() async {
    await initialize();
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : supabaseRedirectUrl,
    );
    return _client.auth.currentUser;
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await _client.auth.signOut();
    } on Object {
      // Local session state is cleared even if the network is unavailable.
      await _client.auth.signOut(scope: SignOutScope.local);
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}

class SupabaseBootstrap {
  static bool isInitialized = false;

  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      debugPrint('Supabase disabled: missing SUPABASE_URL or key.');
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      isInitialized = true;
      await _ensureSession();
    } on Object catch (error) {
      debugPrint('Supabase disabled until configuration is valid: $error');
      isInitialized = false;
    }
  }

  static Future<void> _ensureSession() async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) {
      return;
    }

    try {
      await auth.signInAnonymously();
    } on Object catch (error) {
      debugPrint('Anonymous Supabase auth failed: $error');
    }
  }
}

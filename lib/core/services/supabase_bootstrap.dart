import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured {
    final parsedUrl = Uri.tryParse(url);
    final hasValidUrl =
        parsedUrl != null && parsedUrl.hasScheme && parsedUrl.host.isNotEmpty;
    final hasUsableKey = publishableKey.startsWith('eyJ') ||
        publishableKey.startsWith('sb_publishable_');
    return hasValidUrl && hasUsableKey;
  }
}

class SupabaseBootstrap {
  static bool isInitialized = false;
  static Future<SupabaseClient?>? _initialization;

  static Future<SupabaseClient?> initialize() =>
      _initialization ??= _initialize();

  static Future<SupabaseClient?> _initialize() async {
    if (!SupabaseConfig.isConfigured) {
      debugPrint('Supabase disabled: missing SUPABASE_URL or key.');
      return null;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      isInitialized = true;
      return Supabase.instance.client;
    } on Object catch (error) {
      debugPrint('Supabase disabled until configuration is valid: $error');
      isInitialized = false;
      return null;
    }
  }
}

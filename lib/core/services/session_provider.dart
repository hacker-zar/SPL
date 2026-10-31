import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef SupabaseClientLoader = Future<SupabaseClient?> Function();
typedef AnonymousSignIn = Future<String?> Function(SupabaseClient client);

/// Provides the restored Supabase session and creates an anonymous one when
/// the app starts, sharing concurrent initialization and sign-in requests.
class SessionProvider {
  SessionProvider({
    required SupabaseClientLoader clientLoader,
    AnonymousSignIn? anonymousSignIn,
  })  : _clientLoader = clientLoader,
        _anonymousSignIn = anonymousSignIn ?? _signInAnonymously;

  final SupabaseClientLoader _clientLoader;
  final AnonymousSignIn _anonymousSignIn;
  Future<SupabaseClient?>? _clientFuture;
  SupabaseClient? _resolvedClient;
  Future<String?>? _ensureUserIdFuture;

  Future<SupabaseClient?> get client =>
      _clientFuture ??= _clientLoader().then((value) {
        _resolvedClient = value;
        return value;
      });

  SupabaseClient? get clientValue => _resolvedClient;

  void resetAnonymousSignIn() => _ensureUserIdFuture = null;

  Future<String?> currentUserId() async {
    try {
      return (await client)?.auth.currentUser?.id;
    } on Object catch (error) {
      debugPrint('Supabase session lookup failed: $error');
      return null;
    }
  }

  Future<String?> ensureUserId() async {
    SupabaseClient? supabase;
    try {
      supabase = await client;
    } on Object catch (error) {
      debugPrint('Supabase initialization failed: $error');
      return null;
    }
    if (supabase == null) return null;

    final userId = supabase.auth.currentUser?.id;
    if (userId != null) return userId;

    final pending = _ensureUserIdFuture ??= _signInWithRecovery(supabase);
    final result = await pending;
    if (result == null && identical(_ensureUserIdFuture, pending)) {
      _ensureUserIdFuture = null;
    }
    return result;
  }

  Future<String?> _signInWithRecovery(SupabaseClient supabase) async {
    try {
      return await _anonymousSignIn(supabase);
    } on Object catch (error) {
      debugPrint('Anonymous Supabase auth failed: $error');
      return null;
    }
  }

  static Future<String?> _signInAnonymously(SupabaseClient client) async {
    final response = await client.auth.signInAnonymously();
    return response.user?.id;
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef SupabaseClientLoader = Future<SupabaseClient?> Function();
typedef AnonymousSignIn = Future<String?> Function(SupabaseClient client);

/// Provides the restored Supabase session and creates an anonymous one only
/// when a write needs a user id.
class SessionProvider {
  SessionProvider({
    required SupabaseClientLoader clientLoader,
    AnonymousSignIn? anonymousSignIn,
  })  : _clientLoader = clientLoader,
        _anonymousSignIn = anonymousSignIn ?? _signInAnonymously;

  final SupabaseClientLoader _clientLoader;
  final AnonymousSignIn _anonymousSignIn;
  Future<SupabaseClient?>? _clientFuture;
  Future<String?>? _ensureUserIdFuture;

  Future<SupabaseClient?> get client => _clientFuture ??= _clientLoader();

  Future<String?> currentUserId() async {
    return (await client)?.auth.currentUser?.id;
  }

  Future<String?> ensureUserId() async {
    final supabase = await client;
    if (supabase == null) return null;

    final userId = supabase.auth.currentUser?.id;
    if (userId != null) return userId;

    return _ensureUserIdFuture ??= _anonymousSignIn(supabase).catchError(
      (Object error) {
        debugPrint('Anonymous Supabase auth failed: $error');
        return null;
      },
    );
  }

  static Future<String?> _signInAnonymously(SupabaseClient client) async {
    final response = await client.auth.signInAnonymously();
    return response.user?.id;
  }
}

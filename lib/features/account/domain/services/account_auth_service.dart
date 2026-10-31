import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AccountAuthGateway {
  String? get currentUserId;
  bool get isAnonymous;

  Future<void> updateEmailAndPassword(String email, String password);
  Future<String?> signInWithPassword(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<void> signOut();
}

class SupabaseAccountAuthGateway implements AccountAuthGateway {
  SupabaseAccountAuthGateway(this.client);

  final SupabaseClient client;

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  bool get isAnonymous => client.auth.currentUser?.isAnonymous ?? false;

  @override
  Future<void> updateEmailAndPassword(String email, String password) async {
    await client.auth.updateUser(
      UserAttributes(email: email, password: password),
    );
  }

  @override
  Future<String?> signInWithPassword(String email, String password) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user?.id;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> updatePassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<void> signOut() => client.auth.signOut();
}

class AccountAuthService {
  AccountAuthService(this.gateway);

  final AccountAuthGateway gateway;

  Future<String> convertAnonymousAccount({
    required String email,
    required String password,
  }) async {
    if (!gateway.isAnonymous) {
      throw StateError('La sesión actual ya no es anónima.');
    }
    final originalUserId = gateway.currentUserId;
    if (originalUserId == null) {
      throw StateError('No hay una sesión activa para proteger.');
    }
    await gateway.updateEmailAndPassword(email, password);
    if (gateway.currentUserId != originalUserId) {
      throw StateError('La conversión cambió el UUID de la sesión.');
    }
    return originalUserId;
  }

  Future<String?> signInExistingAccount({
    required String email,
    required String password,
  }) =>
      gateway.signInWithPassword(email, password);

  Future<void> requestPasswordRecovery(String email) =>
      gateway.sendPasswordReset(email);

  Future<void> setPassword(String password) => gateway.updatePassword(password);

  Future<void> signOut() => gateway.signOut();
}

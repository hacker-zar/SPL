import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/account/domain/services/account_auth_service.dart';

void main() {
  test('protecting an anonymous account keeps its UUID and keyed data', () async {
    final gateway = _FakeGateway(userId: 'guest-1', anonymous: true);
    final storedData = <String, String>{'guest-1': 'saved trip'};
    final service = AccountAuthService(gateway);

    final convertedId = await service.convertAnonymousAccount(
      email: 'driver@example.com',
      password: 'safe-password',
    );

    expect(convertedId, 'guest-1');
    expect(gateway.currentUserId, 'guest-1');
    expect(storedData[convertedId], 'saved trip');
    expect(gateway.isAnonymous, isFalse);
  });

  test('a conversion that changes identity is rejected', () async {
    final gateway = _FakeGateway(
      userId: 'guest-1',
      anonymous: true,
      changeIdOnUpdate: true,
    );

    await expectLater(
      AccountAuthService(gateway).convertAnonymousAccount(
        email: 'driver@example.com',
        password: 'safe-password',
      ),
      throwsStateError,
    );
    expect(gateway.currentUserId, 'registered-2');
  });

  test('signing into a different existing account returns its own identity',
      () async {
    final gateway = _FakeGateway(userId: 'guest-1', anonymous: true);

    final signedInId = await AccountAuthService(gateway)
        .signInExistingAccount(
          email: 'existing@example.com',
          password: 'safe-password',
        );

    expect(signedInId, 'existing-2');
    expect(gateway.currentUserId, 'existing-2');
  });

  test('password recovery passes the requested email to auth', () async {
    final gateway = _FakeGateway(userId: 'guest-1', anonymous: true);

    await AccountAuthService(gateway)
        .requestPasswordRecovery('driver@example.com');

    expect(gateway.recoveryEmail, 'driver@example.com');
  });
}

class _FakeGateway implements AccountAuthGateway {
  _FakeGateway({
    required this.userId,
    required this.anonymous,
    this.changeIdOnUpdate = false,
  });

  String? userId;
  bool anonymous;
  final bool changeIdOnUpdate;
  String? recoveryEmail;

  @override
  String? get currentUserId => userId;

  @override
  bool get isAnonymous => anonymous;

  @override
  Future<void> updateEmailAndPassword(String email, String password) async {
    if (changeIdOnUpdate) userId = 'registered-2';
    anonymous = false;
  }

  @override
  Future<String?> signInWithPassword(String email, String password) async {
    userId = 'existing-2';
    anonymous = false;
    return userId;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    recoveryEmail = email;
  }

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<void> signOut() async {}
}

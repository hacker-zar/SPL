import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/app.dart';
import 'package:rentabilidad_flete/core/services/session_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('concurrent ensureUserId calls share one anonymous sign in', () async {
    final client = _client();
    final signIn = Completer<String?>();
    var signInCount = 0;
    final provider = SessionProvider(
      clientLoader: () async => client,
      anonymousSignIn: (_) {
        signInCount++;
        return signIn.future;
      },
    );

    final first = provider.ensureUserId();
    final second = provider.ensureUserId();
    await Future<void>.delayed(Duration.zero);

    expect(signInCount, 1);
    signIn.complete('anonymous-user');
    expect(await Future.wait([first, second]),
        ['anonymous-user', 'anonymous-user']);
  });

  testWidgets('first screen renders while Supabase initialization is pending',
      (tester) async {
    final neverCompletes = Completer<SupabaseClient?>();
    await tester.pumpWidget(
      TripDecisionApp(supabaseInitializer: () => neverCompletes.future),
    );

    expect(find.text('NetoKM'), findsOneWidget);
  });

  testWidgets('opening the app does not create an anonymous session',
      (tester) async {
    final client = _client();
    var signInCount = 0;
    await tester.pumpWidget(
      TripDecisionApp(
        supabaseInitializer: () async => client,
        anonymousSignIn: (_) async {
          signInCount++;
          return 'anonymous-user';
        },
      ),
    );
    await tester.pump();

    expect(signInCount, 0);
  });
}

SupabaseClient _client() => SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

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

  test('anonymous sign-in failures can be retried', () async {
    var attempts = 0;
    final provider = SessionProvider(
      clientLoader: () async => _client(),
      anonymousSignIn: (_) async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
        return 'guest-user';
      },
    );

    expect(await provider.ensureUserId(), isNull);
    expect(await provider.ensureUserId(), 'guest-user');
    expect(attempts, 2);
  });

  testWidgets('first screen renders while Supabase initialization is pending',
      (tester) async {
    final neverCompletes = Completer<SupabaseClient?>();
    await tester.pumpWidget(
      TripDecisionApp(supabaseInitializer: () => neverCompletes.future),
    );

    expect(find.text('Paso 1 de 4 · Ruta'), findsOneWidget);
    expect(find.byTooltip('Historial'), findsOneWidget);
  });

  testWidgets('opening the app creates one anonymous session after bootstrap',
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
    await tester.pump(const Duration(milliseconds: 10));

    expect(signInCount, 1);
  });
}

SupabaseClient _client() => SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

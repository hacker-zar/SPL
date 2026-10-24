import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/app.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/screens/trip_quote_screen.dart';
import 'package:rentabilidad_flete/features/history/presentation/screens/history_screen.dart';

void main() {
  testWidgets('freight starts directly and history remains accessible',
      (tester) async {
    if (enablePersonalMode) return;

    await tester.pumpWidget(const TripDecisionApp());
    await tester.pumpAndSettle();

    expect(find.byType(TripQuoteScreen), findsOneWidget);
    expect(find.text('Paso 1 de 4 · Vehículo'), findsOneWidget);
    expect(find.text('Calculá cuánto cuesta cada kilómetro.'), findsNothing);

    await tester.tap(find.byTooltip('Historial'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
  });
}

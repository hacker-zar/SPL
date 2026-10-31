import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/widgets/vehicle_step.dart';

void main() {
  testWidgets('vehicle sheet shows an error for an invalid amount',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: VehicleProfileSheet(profile: null)),
    ));

    final consumption = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'Consumo L/100 km');
    await tester.enterText(consumption, 'abc');
    await tester.pump();
    expect(find.text('Ingresá un número válido.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Guardar vehículo'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Guardar vehículo'));
    await tester.pump();
    expect(find.textContaining('Ingresá consumo'), findsOneWidget);
  });
}

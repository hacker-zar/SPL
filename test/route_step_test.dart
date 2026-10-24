import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/analysis/domain/services/profitability_calculator.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/controllers/trip_quote_controller.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/widgets/route_step.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/widgets/trip_wizard.dart';
import 'package:rentabilidad_flete/features/costs/domain/models/cost_inputs.dart';
import 'package:rentabilidad_flete/features/costs/domain/services/toll_estimator.dart';
import 'package:rentabilidad_flete/features/history/data/memory_trip_repository.dart';
import 'package:rentabilidad_flete/features/route_planning/data/manual_route_service.dart';
import 'package:rentabilidad_flete/features/route_planning/data/nominatim_geocoding_service.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/lat_lng_value.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/data/memory_vehicle_profile_repository.dart';

void main() {
  testWidgets('editing an origin invalidates its old coordinates',
      (tester) async {
    final controller = _controller();
    const original = LatLngValue(latitude: -32.95, longitude: -60.65);
    controller.setOriginPoint(original);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: RouteStep(controller: controller)),
      ),
    ));
    final origin = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'Origen');
    await tester.enterText(origin, 'Rosario centro');
    expect(controller.originPoint, isNull);

    controller.setDestinationPoint(
      const LatLngValue(latitude: -31.42, longitude: -64.18),
    );
    final destination = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'Destino');
    await tester.enterText(destination, 'Córdoba centro');
    expect(controller.destinationPoint, isNull);
    controller.dispose();
  });

  testWidgets('offers manual distance and duration after route failure',
      (tester) async {
    final controller = _controller();
    controller
        .setOriginPoint(const LatLngValue(latitude: -32.95, longitude: -60.65));
    controller.setDestinationPoint(
        const LatLngValue(latitude: -31.42, longitude: -64.18));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: RouteStep(controller: controller)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(controller.isManualRouteRequired, isTrue);
    expect(find.text('Usar ruta manual'), findsOneWidget);

    final distance = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'Kilómetros totales');
    final duration = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'Duración estimada (horas)');
    await tester.enterText(distance, '1.050');
    await tester.enterText(duration, '11');
    await tester.ensureVisible(find.text('Usar ruta manual'));
    await tester.tap(find.text('Usar ruta manual'));
    await tester.pumpAndSettle();

    expect(controller.route?.distanceKm, 1050);
    expect(controller.route?.durationMinutes, 660);
    expect(controller.route?.durationDays, 2);
    controller.dispose();
  });

  testWidgets('disables Continue while a place name is resolving',
      (tester) async {
    final controller = _controller()..isOriginResolving = true;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TripWizard(
          controller: controller,
          step: WizardStep.route,
          onStepChanged: (_) {},
          onCalculate: () async {},
        ),
      ),
    ));
    await tester.pump();
    final button = tester
        .widget<FilledButton>(find.byKey(const ValueKey('wizardContinue')));
    expect(button.onPressed, isNull);
    controller.dispose();
  });
}

TripQuoteController _controller() => TripQuoteController(
      calculator: const ProfitabilityCalculator(
        marginThresholds: ProfitabilityThresholds(),
      ),
      routeService: ManualRouteService(),
      geocodingService: NominatimGeocodingService(),
      tollEstimator: const TollEstimator(ratePerKm: 0),
      vehicleProfileRepository: MemoryVehicleProfileRepository(),
      tripRepository: MemoryTripRepository(),
      initialCosts: const CostInputs(),
    );

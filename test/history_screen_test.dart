import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/core/theme/app_theme.dart';
import 'package:rentabilidad_flete/features/analysis/domain/services/profitability_calculator.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/controllers/trip_quote_controller.dart';
import 'package:rentabilidad_flete/features/costs/domain/models/cost_inputs.dart';
import 'package:rentabilidad_flete/features/costs/domain/services/toll_estimator.dart';
import 'package:rentabilidad_flete/features/history/data/memory_trip_repository.dart';
import 'package:rentabilidad_flete/features/history/domain/models/trip_record.dart';
import 'package:rentabilidad_flete/features/history/presentation/screens/history_screen.dart';
import 'package:rentabilidad_flete/features/route_planning/data/manual_route_service.dart';
import 'package:rentabilidad_flete/features/route_planning/data/nominatim_geocoding_service.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/lat_lng_value.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/route_info.dart';
import 'package:rentabilidad_flete/features/trip_data/domain/models/trip_inputs.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/data/memory_vehicle_profile_repository.dart';

void main() {
  testWidgets('filters and opens a saved simulation', (tester) async {
    final repository = MemoryTripRepository();
    await repository.save(_record(
      id: 'profitable',
      origin: 'Rosario',
      destination: 'Cordoba',
      profit: 180000,
    ));
    await repository.save(_record(
      id: 'loss',
      origin: 'Santa Fe',
      destination: 'Parana',
      profit: -30000,
    ));
    final controller = _controller(repository)..load();
    String? openedTripId;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: HistoryScreen(
          controller: controller,
          onOpenTrip: (trip) async => openedTripId = trip.id,
          onDuplicateTrip: (_) async {},
          onStartTrip: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rosario → Cordoba'), findsOneWidget);
    expect(find.text('Santa Fe → Parana'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Rosario');
    await tester.pump();
    expect(find.text('Rosario → Cordoba'), findsOneWidget);
    expect(find.text('Santa Fe → Parana'), findsNothing);

    await tester.tap(find.text('Rosario → Cordoba'));
    await tester.pump();
    expect(openedTripId, 'profitable');
    controller.dispose();
  });

  testWidgets('shows the empty state with its call to action', (tester) async {
    final controller = _controller(MemoryTripRepository())..load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: HistoryScreen(
          controller: controller,
          onOpenTrip: (_) async {},
          onDuplicateTrip: (_) async {},
          onStartTrip: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aún no realizaste ninguna simulación.'), findsOneWidget);
    expect(find.text('Hacer mi primera simulación'), findsOneWidget);
    controller.dispose();
  });
}

TripQuoteController _controller(MemoryTripRepository repository) {
  return TripQuoteController(
    calculator: const ProfitabilityCalculator(
      marginThresholds: ProfitabilityThresholds(),
    ),
    routeService: ManualRouteService(),
    geocodingService: NominatimGeocodingService(),
    tollEstimator: const TollEstimator(ratePerKm: 35),
    vehicleProfileRepository: MemoryVehicleProfileRepository(),
    tripRepository: repository,
    initialCosts: const CostInputs(),
  );
}

TripRecord _record({
  required String id,
  required String origin,
  required String destination,
  required double profit,
}) {
  return TripRecord(
    id: id,
    createdAt: DateTime(2026, 8, 1),
    route: RouteInfo(
      originName: origin,
      destinationName: destination,
      origin: const LatLngValue(latitude: -32.94, longitude: -60.65),
      destination: const LatLngValue(latitude: -31.42, longitude: -64.19),
      distanceKm: 400,
      durationMinutes: 360,
    ),
    trip: const TripInputs(
      pricingMode: PricingMode.flatRate,
      flatRate: 800000,
    ),
    costs: const CostInputs(fuelPricePerLiter: 1000),
    emptyReturn: false,
    income: 800000,
    totalCosts: 800000 - profit,
    netProfit: profit,
    marginPercent: profit / 8000,
  );
}

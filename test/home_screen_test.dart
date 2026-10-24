import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/app.dart';
import 'package:rentabilidad_flete/core/theme/app_theme.dart';
import 'package:rentabilidad_flete/features/analysis/domain/services/profitability_calculator.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/controllers/trip_quote_controller.dart';
import 'package:rentabilidad_flete/features/costs/domain/models/cost_inputs.dart';
import 'package:rentabilidad_flete/features/costs/domain/services/toll_estimator.dart';
import 'package:rentabilidad_flete/features/history/data/memory_trip_repository.dart';
import 'package:rentabilidad_flete/features/history/domain/models/trip_record.dart';
import 'package:rentabilidad_flete/features/home/presentation/screens/home_screen.dart';
import 'package:rentabilidad_flete/features/history/presentation/screens/history_screen.dart';
import 'package:rentabilidad_flete/features/route_planning/data/manual_route_service.dart';
import 'package:rentabilidad_flete/features/route_planning/data/nominatim_geocoding_service.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/lat_lng_value.dart';
import 'package:rentabilidad_flete/features/route_planning/domain/models/route_info.dart';
import 'package:rentabilidad_flete/features/trip_data/domain/models/trip_inputs.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/data/memory_vehicle_profile_repository.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/domain/models/vehicle_profile.dart';

void main() {
  testWidgets('opens the trip wizard and returns to Home', (tester) async {
    final controller = TripQuoteController(
      calculator: const ProfitabilityCalculator(
        marginThresholds: ProfitabilityThresholds(),
      ),
      routeService: ManualRouteService(),
      geocodingService: NominatimGeocodingService(),
      tollEstimator: const TollEstimator(ratePerKm: 35),
      vehicleProfileRepository: MemoryVehicleProfileRepository(),
      tripRepository: MemoryTripRepository(),
      initialCosts: const CostInputs(),
    )..load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: HomeScreen(
          controller: controller,
          personalModeEnabled: enablePersonalMode,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Netokm'), findsOneWidget);
    expect(find.text('Flete'), findsOneWidget);
    expect(
      find.text('Viaje personal'),
      enablePersonalMode ? findsOneWidget : findsNothing,
    );
    expect(
      find.text('Beta'),
      enablePersonalMode ? findsOneWidget : findsNothing,
    );
    expect(find.text('Comparar viajes'), findsNothing);

    if (enablePersonalMode) {
      await tester.tap(find.text('Viaje personal'));
      await tester.pumpAndSettle();

      expect(controller.purpose, TripPurpose.personal);
      expect(find.text('Paso 1 de 4 · Vehículo'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Flete'));
    await tester.pumpAndSettle();
    expect(controller.purpose, TripPurpose.freight);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Calculá cuánto cuesta cada kilómetro.'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('new simulation from a history result opens the freight wizard',
      (tester) async {
    final repository = MemoryTripRepository();
    await repository.save(_savedRecord());
    final controller = TripQuoteController(
      calculator: const ProfitabilityCalculator(
        marginThresholds: ProfitabilityThresholds(),
      ),
      routeService: ManualRouteService(),
      geocodingService: NominatimGeocodingService(),
      tollEstimator: const TollEstimator(ratePerKm: 0),
      vehicleProfileRepository: MemoryVehicleProfileRepository(),
      tripRepository: repository,
      initialCosts: const CostInputs(fuelPricePerLiter: 1000),
    )..load();
    controller.vehicleProfile = const VehicleProfile(
      consumptionLitersPer100Km: 30,
      maintenanceCostPerKm: 100,
      capacityTons: 28,
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: HomeScreen(controller: controller),
    ));
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    await tester.tap(find.text('Rosario → Córdoba'));
    await tester.pumpAndSettle();
    expect(find.text('Resultado del viaje'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -1400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva simulación'));
    await tester.pumpAndSettle();

    expect(find.text('Paso 1 de 4 · Vehículo'), findsOneWidget);
    expect(find.text('Flete'), findsOneWidget);
    controller.dispose();
  });
}

TripRecord _savedRecord() => TripRecord(
      id: 'saved',
      createdAt: DateTime(2026, 10, 20),
      route: const RouteInfo(
        originName: 'Rosario',
        destinationName: 'Córdoba',
        origin: LatLngValue(latitude: -32.95, longitude: -60.65),
        destination: LatLngValue(latitude: -31.42, longitude: -64.18),
        distanceKm: 400,
        durationMinutes: 360,
      ),
      trip:
          const TripInputs(pricingMode: PricingMode.flatRate, flatRate: 500000),
      costs: const CostInputs(fuelPricePerLiter: 1000),
      emptyReturn: false,
      income: 500000,
      totalCosts: 160000,
      netProfit: 340000,
      marginPercent: 68,
    );

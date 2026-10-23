import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/app.dart';
import 'package:rentabilidad_flete/core/theme/app_theme.dart';
import 'package:rentabilidad_flete/features/analysis/domain/services/profitability_calculator.dart';
import 'package:rentabilidad_flete/features/analysis/presentation/controllers/trip_quote_controller.dart';
import 'package:rentabilidad_flete/features/costs/domain/models/cost_inputs.dart';
import 'package:rentabilidad_flete/features/costs/domain/services/toll_estimator.dart';
import 'package:rentabilidad_flete/features/history/data/memory_trip_repository.dart';
import 'package:rentabilidad_flete/features/home/presentation/screens/home_screen.dart';
import 'package:rentabilidad_flete/features/route_planning/data/manual_route_service.dart';
import 'package:rentabilidad_flete/features/route_planning/data/nominatim_geocoding_service.dart';
import 'package:rentabilidad_flete/features/trip_data/domain/models/trip_inputs.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/data/memory_vehicle_profile_repository.dart';

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

    expect(find.text('NetoKM'), findsOneWidget);
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
}

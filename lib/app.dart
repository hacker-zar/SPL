import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/supabase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/analysis/domain/services/profitability_calculator.dart';
import 'features/analysis/presentation/controllers/trip_quote_controller.dart';
import 'features/analysis/presentation/screens/trip_quote_screen.dart';
import 'features/costs/domain/models/cost_inputs.dart';
import 'features/costs/domain/services/toll_estimator.dart';
import 'features/history/data/memory_trip_repository.dart';
import 'features/history/data/supabase_trip_repository.dart';
import 'features/history/domain/repositories/trip_repository.dart';
import 'features/route_planning/data/osrm_route_service.dart';
import 'features/vehicle_profile/data/memory_vehicle_profile_repository.dart';
import 'features/vehicle_profile/data/supabase_vehicle_profile_repository.dart';
import 'features/vehicle_profile/domain/repositories/vehicle_profile_repository.dart';

class TripDecisionApp extends StatefulWidget {
  const TripDecisionApp({super.key});

  @override
  State<TripDecisionApp> createState() => _TripDecisionAppState();
}

class _TripDecisionAppState extends State<TripDecisionApp> {
  late final TripQuoteController controller;

  @override
  void initState() {
    super.initState();
    final supabaseClient =
        SupabaseBootstrap.isInitialized ? Supabase.instance.client : null;
    final currentUserId = supabaseClient?.auth.currentUser?.id;

    late final VehicleProfileRepository vehicleProfileRepository;
    late final TripRepository tripRepository;
    if (supabaseClient != null && currentUserId != null) {
      vehicleProfileRepository = SupabaseVehicleProfileRepository(
        client: supabaseClient,
        userId: currentUserId,
      );
      tripRepository = SupabaseTripRepository(
        client: supabaseClient,
        userId: currentUserId,
      );
    } else {
      vehicleProfileRepository = MemoryVehicleProfileRepository();
      tripRepository = MemoryTripRepository();
    }

    const osrmBaseUrl = String.fromEnvironment(
      'OSRM_BASE_URL',
      defaultValue: 'https://router.project-osrm.org',
    );
    final routeService = OsrmRouteService(baseUrl: osrmBaseUrl);
    final tollEstimator = TollEstimator(
      ratePerKm: _doubleEnvironment('TOLL_RATE_PER_KM', 35),
      minimumAmount: _doubleEnvironment('TOLL_MINIMUM', 0),
      roundTo: _doubleEnvironment('TOLL_ROUND_TO', 100),
    );

    controller = TripQuoteController(
      calculator: const ProfitabilityCalculator(
        marginThresholds: ProfitabilityThresholds(),
      ),
      routeService: routeService,
      tollEstimator: tollEstimator,
      vehicleProfileRepository: vehicleProfileRepository,
      tripRepository: tripRepository,
      initialCosts: const CostInputs(),
    )..load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conviene este viaje?',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: TripQuoteScreen(controller: controller),
    );
  }
}

double _doubleEnvironment(String name, double fallback) {
  final value = switch (name) {
    'TOLL_RATE_PER_KM' => const String.fromEnvironment('TOLL_RATE_PER_KM'),
    'TOLL_MINIMUM' => const String.fromEnvironment('TOLL_MINIMUM'),
    'TOLL_ROUND_TO' => const String.fromEnvironment('TOLL_ROUND_TO'),
    _ => '',
  };
  return double.tryParse(value) ?? fallback;
}

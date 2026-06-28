import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/supabase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/analysis/domain/services/profitability_calculator.dart';
import 'features/analysis/presentation/controllers/trip_quote_controller.dart';
import 'features/analysis/presentation/screens/trip_quote_screen.dart';
import 'features/costs/domain/models/cost_inputs.dart';
import 'features/history/data/memory_trip_repository.dart';
import 'features/history/data/supabase_trip_repository.dart';
import 'features/history/domain/repositories/trip_repository.dart';
import 'features/route_planning/data/google_maps_route_service.dart';
import 'features/route_planning/data/manual_route_service.dart';
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

    const routeApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    final routeService = routeApiKey.isEmpty
        ? ManualRouteService()
        : GoogleMapsRouteService(apiKey: routeApiKey);

    controller = TripQuoteController(
      calculator: ProfitabilityCalculator(
        marginThresholds: const ProfitabilityThresholds(),
      ),
      routeService: routeService,
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
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: TripQuoteScreen(controller: controller),
    );
  }
}

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/session_provider.dart';
import '../domain/models/vehicle_profile.dart';
import '../domain/repositories/vehicle_profile_repository.dart';

class SupabaseVehicleProfileRepository implements VehicleProfileRepository {
  SupabaseVehicleProfileRepository({
    required SessionProvider sessionProvider,
    required VehicleProfileRepository fallbackRepository,
  })  : _sessionProvider = sessionProvider,
        _fallbackRepository = fallbackRepository;

  final SessionProvider _sessionProvider;
  final VehicleProfileRepository _fallbackRepository;

  @override
  Stream<VehicleProfile?> watch() =>
      watchAll().map((profiles) => profiles.isEmpty ? null : profiles.first);

  @override
  Stream<List<VehicleProfile>> watchAll() {
    return Stream.multi((output) {
      StreamSubscription<List<VehicleProfile>>? fallbackSubscription;
      StreamSubscription<List<Map<String, dynamic>>>? remoteSubscription;
      StreamSubscription<AuthState>? authSubscription;
      String? activeUserId;

      void watchFallback() {
        if (fallbackSubscription != null) return;
        fallbackSubscription = _fallbackRepository.watchAll().listen(
              output.add,
              onError: output.addError,
            );
      }

      Future<void> watchUser(String? userId) async {
        if (userId == activeUserId &&
            (userId == null ? fallbackSubscription != null : true)) {
          return;
        }
        activeUserId = userId;
        await fallbackSubscription?.cancel();
        fallbackSubscription = null;
        await remoteSubscription?.cancel();
        remoteSubscription = null;

        if (userId == null) {
          watchFallback();
          return;
        }

        final client = await _sessionProvider.client;
        if (client == null) {
          watchFallback();
          return;
        }
        remoteSubscription = client
            .from('vehicle_profiles')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)
            .order('is_primary', ascending: false)
            .order('created_at')
            .listen(
              (rows) => output.add(
                rows.map(VehicleProfile.fromMap).toList(growable: false),
              ),
              onError: output.addError,
            );
      }

      unawaited(() async {
        final client = await _sessionProvider.client;
        if (client == null) {
          watchFallback();
          return;
        }
        authSubscription = client.auth.onAuthStateChange.listen((state) {
          unawaited(watchUser(state.session?.user.id));
        });
        await watchUser(await _sessionProvider.currentUserId());
      }());

      output.onCancel = () async {
        await fallbackSubscription?.cancel();
        await remoteSubscription?.cancel();
        await authSubscription?.cancel();
      };
    });
  }

  @override
  Future<VehicleProfile> save(VehicleProfile profile) async {
    final userId = await _sessionProvider.ensureUserId();
    final client = await _sessionProvider.client;
    if (userId == null || client == null) {
      throw StateError(
          'No hay una sesión de Supabase disponible para guardar el vehículo permanentemente.');
    }
    final saved = await client
        .from('vehicle_profiles')
        .upsert(
          _toRow(profile, userId, profile.id),
          onConflict: 'id',
        )
        .select()
        .single();
    return VehicleProfile.fromMap(saved);
  }

  Map<String, dynamic> _toRow(
      VehicleProfile profile, String userId, String? id) {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'consumption_liters_per_100_km': profile.consumptionLitersPer100Km,
      'maintenance_cost_per_km': profile.maintenanceCostPerKm,
      'capacity_tons': profile.capacityTons > 0 ? profile.capacityTons : null,
      'plate': profile.plate.isEmpty ? null : profile.plate,
      'daily_fixed_cost': profile.dailyFixedCost,
      'vehicle_type': profile.vehicleType,
      'brand': profile.brand.isEmpty ? null : profile.brand,
      'model': profile.model.isEmpty ? null : profile.model,
      'year': profile.year,
      'fuel_type': profile.fuelType.isEmpty ? null : profile.fuelType,
      'tire_cost_per_km': profile.tireCostPerKm,
      'other_operating_costs_per_km': profile.otherOperatingCostsPerKm,
      'is_primary': profile.isPrimary,
    };
  }
}

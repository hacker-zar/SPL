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
  Stream<VehicleProfile?> watch() {
    return Stream.multi((output) {
      StreamSubscription<VehicleProfile?>? fallbackSubscription;
      StreamSubscription<List<Map<String, dynamic>>>? remoteSubscription;
      StreamSubscription<AuthState>? authSubscription;
      String? activeUserId;

      void watchFallback() {
        if (fallbackSubscription != null) return;
        fallbackSubscription = _fallbackRepository.watch().listen(
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
            .stream(primaryKey: ['user_id'])
            .eq('user_id', userId)
            .limit(1)
            .listen(
              (rows) => output.add(
                rows.isEmpty ? null : VehicleProfile.fromMap(rows.first),
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
  Future<void> save(VehicleProfile profile) async {
    final userId = await _sessionProvider.ensureUserId();
    final client = await _sessionProvider.client;
    if (userId == null || client == null) {
      await _fallbackRepository.save(profile);
      return;
    }
    await client.from('vehicle_profiles').upsert(
          _toRow(profile, userId),
          onConflict: 'user_id',
        );
  }

  Map<String, dynamic> _toRow(VehicleProfile profile, String userId) {
    return {
      'user_id': userId,
      'consumption_liters_per_100_km': profile.consumptionLitersPer100Km,
      'maintenance_cost_per_km': profile.maintenanceCostPerKm,
      'capacity_tons': profile.capacityTons,
      'plate': profile.plate.isEmpty ? null : profile.plate,
      'daily_fixed_cost': profile.dailyFixedCost,
    };
  }
}

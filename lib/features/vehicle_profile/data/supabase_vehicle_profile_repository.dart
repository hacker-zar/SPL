import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/vehicle_profile.dart';
import '../domain/repositories/vehicle_profile_repository.dart';

class SupabaseVehicleProfileRepository implements VehicleProfileRepository {
  SupabaseVehicleProfileRepository({
    required SupabaseClient client,
    required this.userId,
  }) : _client = client;

  final SupabaseClient _client;
  final String userId;

  @override
  Stream<VehicleProfile?> watch() {
    return _client
        .from('vehicle_profiles')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .limit(1)
        .map((rows) {
          if (rows.isEmpty) {
            return null;
          }
          return VehicleProfile.fromMap(rows.first);
        });
  }

  @override
  Future<void> save(VehicleProfile profile) async {
    await _client.from('vehicle_profiles').upsert(
          _toRow(profile),
          onConflict: 'user_id',
        );
  }

  Map<String, dynamic> _toRow(VehicleProfile profile) {
    return {
      'user_id': userId,
      'consumption_liters_per_100_km': profile.consumptionLitersPer100Km,
      'maintenance_cost_per_km': profile.maintenanceCostPerKm,
      'capacity_tons': profile.capacityTons,
      'plate': profile.plate.isEmpty ? null : profile.plate,
    };
  }
}

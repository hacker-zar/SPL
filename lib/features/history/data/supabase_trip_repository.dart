import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/trip_record.dart';
import '../domain/repositories/trip_repository.dart';

class SupabaseTripRepository implements TripRepository {
  SupabaseTripRepository({
    required SupabaseClient client,
    required this.userId,
  }) : _client = client;

  final SupabaseClient _client;
  final String userId;

  @override
  Stream<List<TripRecord>> watchRecent() {
    return _client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(30)
        .map(
          (rows) => rows
              .map((row) => TripRecord.fromMap(row['id'] as String, row))
              .toList(),
        );
  }

  @override
  Future<void> save(TripRecord trip) async {
    await _client.from('trips').insert(_toRow(trip));
  }

  Map<String, dynamic> _toRow(TripRecord trip) {
    return {
      'id': trip.id,
      'user_id': userId,
      'created_at': trip.createdAt.toIso8601String(),
      'origin_name': trip.route.originName,
      'destination_name': trip.route.destinationName,
      'distance_km': trip.route.distanceKm,
      'duration_minutes': trip.route.durationMinutes,
      'empty_return': trip.emptyReturn,
      'route': trip.route.toMap(),
      'trip': trip.trip.toMap(),
      'costs': trip.costs.toMap(),
      'income': trip.income,
      'total_costs': trip.totalCosts,
      'net_profit': trip.netProfit,
      'margin_percent': trip.marginPercent,
    };
  }
}

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/session_provider.dart';
import '../domain/models/trip_record.dart';
import '../domain/repositories/trip_repository.dart';

class SupabaseTripRepository implements TripRepository {
  SupabaseTripRepository({
    required SessionProvider sessionProvider,
    required TripRepository fallbackRepository,
  })  : _sessionProvider = sessionProvider,
        _fallbackRepository = fallbackRepository;

  final SessionProvider _sessionProvider;
  final TripRepository _fallbackRepository;

  @override
  Stream<List<TripRecord>> watchRecent() {
    return Stream.multi((output) {
      StreamSubscription<List<TripRecord>>? fallbackSubscription;
      StreamSubscription<List<Map<String, dynamic>>>? remoteSubscription;
      StreamSubscription<AuthState>? authSubscription;
      String? activeUserId;

      void watchFallback() {
        if (fallbackSubscription != null) return;
        fallbackSubscription = _fallbackRepository.watchRecent().listen(
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
            .from('trips')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(30)
            .listen(
              (rows) => output.add(
                rows
                    .map((row) => TripRecord.fromMap(row['id'] as String, row))
                    .toList(),
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
  Future<void> save(TripRecord trip) async {
    final userId = await _sessionProvider.ensureUserId();
    final client = await _sessionProvider.client;
    if (userId == null || client == null) {
      await _fallbackRepository.save(trip);
      return;
    }
    await client.from('trips').insert(_toRow(trip, userId));
  }

  Map<String, dynamic> _toRow(TripRecord trip, String userId) {
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

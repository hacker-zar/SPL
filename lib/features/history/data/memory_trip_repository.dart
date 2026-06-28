import 'dart:async';

import '../domain/models/trip_record.dart';
import '../domain/repositories/trip_repository.dart';

class MemoryTripRepository implements TripRepository {
  final List<TripRecord> _trips = [];
  final StreamController<List<TripRecord>> _controller =
      StreamController<List<TripRecord>>.broadcast();

  @override
  Stream<List<TripRecord>> watchRecent() async* {
    yield [..._trips];
    yield* _controller.stream;
  }

  @override
  Future<void> save(TripRecord trip) async {
    _trips.removeWhere((item) => item.id == trip.id);
    _trips.add(trip);
    _trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _controller.add([..._trips]);
  }
}

import '../models/trip_record.dart';

abstract class TripRepository {
  Stream<List<TripRecord>> watchRecent();

  Future<void> save(TripRecord trip);
}

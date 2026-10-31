import 'package:flutter/foundation.dart';

import '../../domain/models/comparison_trip.dart';

class ComparisonController extends ChangeNotifier {
  ComparisonController({this.maxTrips = 4});

  final int maxTrips;
  final List<ComparisonTrip> _trips = [];

  List<ComparisonTrip> get trips => List.unmodifiable(_trips);

  bool get canCompare => _trips.length >= 2;

  String get nextLabel {
    for (var index = 0; index < maxTrips; index++) {
      final candidate = 'Viaje ${String.fromCharCode(65 + index)}';
      if (_trips.every((trip) => trip.label != candidate)) return candidate;
    }
    return 'Viaje ${_trips.length + 1}';
  }

  void add(ComparisonTrip trip) {
    if (_trips.length >= maxTrips) {
      return;
    }
    _trips.add(
      ComparisonTrip(
        label: nextLabel,
        record: trip.record,
        analysis: trip.analysis,
      ),
    );
    notifyListeners();
  }

  void remove(ComparisonTrip trip) {
    _trips.remove(trip);
    notifyListeners();
  }
}

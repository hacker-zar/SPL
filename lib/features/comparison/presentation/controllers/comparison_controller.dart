import 'package:flutter/foundation.dart';

import '../../domain/models/comparison_trip.dart';

class ComparisonController extends ChangeNotifier {
  ComparisonController({this.maxTrips = 2});

  final int maxTrips;
  final List<ComparisonTrip> _trips = [];

  List<ComparisonTrip> get trips => List.unmodifiable(_trips);

  bool get canCompare => _trips.length >= 2;

  String get nextLabel => 'Viaje ${String.fromCharCode(65 + _trips.length)}';

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

  ComparisonDecision get decision {
    assert(canCompare, 'Se necesitan al menos dos viajes para comparar.');
    final ordered = [..._trips]..sort(_compareTrips);
    return ComparisonDecision(
      recommended: ordered.first,
      alternative: ordered[1],
    );
  }

  int _compareTrips(ComparisonTrip first, ComparisonTrip second) {
    final profit = second.record.netProfit.compareTo(first.record.netProfit);
    if (profit != 0) {
      return profit;
    }
    final margin =
        second.record.marginPercent.compareTo(first.record.marginPercent);
    if (margin != 0) {
      return margin;
    }
    final perKm = second.profitPerKm.compareTo(first.profitPerKm);
    if (perKm != 0) {
      return perKm;
    }
    return second.profitPerHour.compareTo(first.profitPerHour);
  }
}

class ComparisonDecision {
  const ComparisonDecision({
    required this.recommended,
    required this.alternative,
  });

  final ComparisonTrip recommended;
  final ComparisonTrip alternative;

  double get absoluteDifference =>
      recommended.record.netProfit - alternative.record.netProfit;

  double get percentageDifference {
    final base = alternative.record.netProfit.abs();
    if (base == 0) {
      return absoluteDifference == 0 ? 0 : 100;
    }
    return (absoluteDifference.abs() / base) * 100;
  }

  bool get isClose => percentageDifference <= 5;

  bool get bothAreLosses =>
      recommended.record.netProfit <= 0 && alternative.record.netProfit <= 0;

  List<String> get reasons {
    final values = <String>[];
    if (recommended.record.netProfit > alternative.record.netProfit) {
      values.add('mayor ganancia neta');
    }
    if (recommended.record.marginPercent > alternative.record.marginPercent) {
      values.add('mejor margen');
    }
    if (recommended.profitPerKm > alternative.profitPerKm) {
      values.add('mejor rentabilidad por kilómetro');
    }
    if (recommended.profitPerHour > alternative.profitPerHour) {
      values.add('mejor ganancia por hora');
    }
    return values.isEmpty ? ['métricas económicas muy similares'] : values;
  }
}

import '../../../costs/domain/models/cost_inputs.dart';
import '../../../route_planning/domain/models/route_info.dart';
import '../../../trip_data/domain/models/trip_inputs.dart';
import '../../../analysis/domain/models/trip_analysis.dart';
import '../../../analysis/domain/models/profitability_status.dart';
import '../../../vehicle_profile/domain/models/vehicle_profile.dart';

class TripRecord {
  const TripRecord({
    required this.id,
    required this.createdAt,
    required this.route,
    required this.trip,
    required this.costs,
    required this.emptyReturn,
    required this.income,
    required this.totalCosts,
    required this.netProfit,
    required this.marginPercent,
    this.vehicleProfile,
    this.calculationStatus,
  });

  final String id;
  final DateTime createdAt;
  final RouteInfo route;
  final TripInputs trip;
  final CostInputs costs;
  final bool emptyReturn;
  final double income;
  final double totalCosts;
  final double netProfit;
  final double marginPercent;
  final VehicleProfile? vehicleProfile;
  final String? calculationStatus;

  ProfitabilityStatus? get savedStatus => switch (calculationStatus) {
        'profitable' => ProfitabilityStatus.profitable,
        'low' => ProfitabilityStatus.low,
        'loss' => ProfitabilityStatus.loss,
        _ => null,
      };

  factory TripRecord.fromAnalysis({
    required String id,
    required RouteInfo route,
    required TripInputs trip,
    required CostInputs costs,
    required bool emptyReturn,
    required TripAnalysis analysis,
    VehicleProfile? vehicleProfile,
  }) {
    return TripRecord(
      id: id,
      createdAt: DateTime.now(),
      route: route,
      trip: trip,
      costs: costs,
      emptyReturn: emptyReturn,
      income: trip.purpose == TripPurpose.personal ? 0 : analysis.grossIncome,
      totalCosts: analysis.totalCosts,
      netProfit: trip.purpose == TripPurpose.personal ? 0 : analysis.netProfit,
      marginPercent:
          trip.purpose == TripPurpose.personal ? 0 : analysis.marginPercent,
      vehicleProfile: vehicleProfile,
      calculationStatus: analysis.status.name,
    );
  }

  Map<String, dynamic> toMap({required String userId}) => {
        'userId': userId,
        'createdAt': createdAt.toIso8601String(),
        'route': route.toMap(),
        'trip': trip.toMap(),
        'costs': costs.toMap(),
        'emptyReturn': emptyReturn,
        'income': income,
        'totalCosts': totalCosts,
        'netProfit': netProfit,
        'marginPercent': marginPercent,
        'vehicleProfile': vehicleProfile?.toMap(userId: userId),
        'calculationStatus': calculationStatus,
      };

  factory TripRecord.fromMap(String id, Map<String, dynamic> map) {
    return TripRecord(
      id: id,
      createdAt: DateTime.parse(
        (map['created_at'] as String?) ?? map['createdAt'] as String,
      ),
      route: RouteInfo.fromMap(Map<String, dynamic>.from(map['route'])),
      trip: TripInputs.fromMap(Map<String, dynamic>.from(map['trip'])),
      costs: CostInputs.fromMap(Map<String, dynamic>.from(map['costs'])),
      emptyReturn:
          map['empty_return'] as bool? ?? map['emptyReturn'] as bool? ?? false,
      income: (map['income'] as num?)?.toDouble() ?? 0,
      totalCosts: (map['total_costs'] as num?)?.toDouble() ??
          (map['totalCosts'] as num?)?.toDouble() ??
          0,
      netProfit: (map['net_profit'] as num?)?.toDouble() ??
          (map['netProfit'] as num?)?.toDouble() ??
          0,
      marginPercent: (map['margin_percent'] as num?)?.toDouble() ??
          (map['marginPercent'] as num?)?.toDouble() ??
          0,
      vehicleProfile: _profileSnapshot(map),
      calculationStatus: map['calculation_status'] as String? ??
          map['calculationStatus'] as String?,
    );
  }

  static VehicleProfile? _profileSnapshot(Map<String, dynamic> map) {
    final raw = map['vehicle_profile_snapshot'] ?? map['vehicleProfile'];
    if (raw is! Map) return null;
    return VehicleProfile.fromMap(Map<String, dynamic>.from(raw));
  }
}

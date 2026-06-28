class VehicleProfile {
  const VehicleProfile({
    required this.consumptionLitersPer100Km,
    required this.maintenanceCostPerKm,
    required this.capacityTons,
    this.plate = '',
  });

  final double consumptionLitersPer100Km;
  final double maintenanceCostPerKm;
  final double capacityTons;
  final String plate;

  bool get isComplete =>
      consumptionLitersPer100Km > 0 &&
      maintenanceCostPerKm >= 0 &&
      capacityTons > 0;

  VehicleProfile copyWith({
    double? consumptionLitersPer100Km,
    double? maintenanceCostPerKm,
    double? capacityTons,
    String? plate,
  }) {
    return VehicleProfile(
      consumptionLitersPer100Km:
          consumptionLitersPer100Km ?? this.consumptionLitersPer100Km,
      maintenanceCostPerKm:
          maintenanceCostPerKm ?? this.maintenanceCostPerKm,
      capacityTons: capacityTons ?? this.capacityTons,
      plate: plate ?? this.plate,
    );
  }

  Map<String, dynamic> toMap({required String userId}) => {
        'userId': userId,
        'consumptionLitersPer100Km': consumptionLitersPer100Km,
        'maintenanceCostPerKm': maintenanceCostPerKm,
        'capacityTons': capacityTons,
        'plate': plate,
      };

  factory VehicleProfile.fromMap(Map<String, dynamic> map) {
    return VehicleProfile(
      consumptionLitersPer100Km:
          (map['consumption_liters_per_100_km'] as num?)?.toDouble() ??
              (map['consumptionLitersPer100Km'] as num?)?.toDouble() ??
              0,
      maintenanceCostPerKm:
          (map['maintenance_cost_per_km'] as num?)?.toDouble() ??
              (map['maintenanceCostPerKm'] as num?)?.toDouble() ??
              0,
      capacityTons: (map['capacity_tons'] as num?)?.toDouble() ??
          (map['capacityTons'] as num?)?.toDouble() ??
          0,
      plate: map['plate'] as String? ?? '',
    );
  }
}

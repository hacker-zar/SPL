import '../../../trip_data/domain/models/trip_inputs.dart';

class VehicleProfile {
  const VehicleProfile({
    required this.consumptionLitersPer100Km,
    required this.maintenanceCostPerKm,
    required this.capacityTons,
    this.id,
    this.plate = '',
    this.dailyFixedCost = 0,
    this.vehicleType = 'camion',
    this.brand = '',
    this.model = '',
    this.year,
    this.fuelType = '',
    this.tireCostPerKm = 0,
    this.otherOperatingCostsPerKm = 0,
    this.isPrimary = true,
  });

  final String? id;
  final double consumptionLitersPer100Km;
  final double maintenanceCostPerKm;
  final double capacityTons;
  final String plate;
  final double dailyFixedCost;
  final String vehicleType;
  final String brand;
  final String model;
  final int? year;
  final String fuelType;
  final double tireCostPerKm;
  final double otherOperatingCostsPerKm;
  final bool isPrimary;

  bool get isComplete =>
      consumptionLitersPer100Km > 0 &&
      maintenanceCostPerKm >= 0 &&
      capacityTons > 0;

  bool isCompleteFor(TripPurpose purpose) => switch (purpose) {
        TripPurpose.freight => isComplete,
        TripPurpose.personal =>
          consumptionLitersPer100Km > 0 && maintenanceCostPerKm >= 0,
      };

  VehicleProfile copyWith({
    double? consumptionLitersPer100Km,
    double? maintenanceCostPerKm,
    double? capacityTons,
    String? plate,
    double? dailyFixedCost,
    String? id,
    String? vehicleType,
    String? brand,
    String? model,
    int? year,
    String? fuelType,
    double? tireCostPerKm,
    double? otherOperatingCostsPerKm,
    bool? isPrimary,
  }) {
    return VehicleProfile(
      consumptionLitersPer100Km:
          consumptionLitersPer100Km ?? this.consumptionLitersPer100Km,
      maintenanceCostPerKm: maintenanceCostPerKm ?? this.maintenanceCostPerKm,
      capacityTons: capacityTons ?? this.capacityTons,
      plate: plate ?? this.plate,
      dailyFixedCost: dailyFixedCost ?? this.dailyFixedCost,
      id: id ?? this.id,
      vehicleType: vehicleType ?? this.vehicleType,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      fuelType: fuelType ?? this.fuelType,
      tireCostPerKm: tireCostPerKm ?? this.tireCostPerKm,
      otherOperatingCostsPerKm:
          otherOperatingCostsPerKm ?? this.otherOperatingCostsPerKm,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  Map<String, dynamic> toMap({required String userId}) => {
        'userId': userId,
        'consumptionLitersPer100Km': consumptionLitersPer100Km,
        'maintenanceCostPerKm': maintenanceCostPerKm,
        'capacityTons': capacityTons,
        'plate': plate,
        'dailyFixedCost': dailyFixedCost,
        'id': id,
        'vehicleType': vehicleType,
        'brand': brand,
        'model': model,
        'year': year,
        'fuelType': fuelType,
        'tireCostPerKm': tireCostPerKm,
        'otherOperatingCostsPerKm': otherOperatingCostsPerKm,
        'isPrimary': isPrimary,
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
      dailyFixedCost: (map['daily_fixed_cost'] as num?)?.toDouble() ??
          (map['dailyFixedCost'] as num?)?.toDouble() ??
          0,
      id: map['id'] as String?,
      vehicleType: map['vehicle_type'] as String? ??
          map['vehicleType'] as String? ??
          'camion',
      brand: map['brand'] as String? ?? '',
      model: map['model'] as String? ?? '',
      year: (map['year'] as num?)?.toInt(),
      fuelType: map['fuel_type'] as String? ?? map['fuelType'] as String? ?? '',
      tireCostPerKm: (map['tire_cost_per_km'] as num?)?.toDouble() ??
          (map['tireCostPerKm'] as num?)?.toDouble() ??
          0,
      otherOperatingCostsPerKm:
          (map['other_operating_costs_per_km'] as num?)?.toDouble() ??
              (map['otherOperatingCostsPerKm'] as num?)?.toDouble() ??
              0,
      isPrimary:
          map['is_primary'] as bool? ?? map['isPrimary'] as bool? ?? true,
    );
  }
}

class CostInputs {
  const CostInputs({
    this.fuelPricePerLiter = 0,
    this.tolls = 0,
    this.allowances = 0,
  });

  final double fuelPricePerLiter;
  final double tolls;
  final double allowances;

  CostInputs copyWith({
    double? fuelPricePerLiter,
    double? tolls,
    double? allowances,
  }) {
    return CostInputs(
      fuelPricePerLiter: fuelPricePerLiter ?? this.fuelPricePerLiter,
      tolls: tolls ?? this.tolls,
      allowances: allowances ?? this.allowances,
    );
  }

  Map<String, dynamic> toMap() => {
        'fuelPricePerLiter': fuelPricePerLiter,
        'tolls': tolls,
        'allowances': allowances,
      };

  factory CostInputs.fromMap(Map<String, dynamic> map) {
    return CostInputs(
      fuelPricePerLiter:
          (map['fuelPricePerLiter'] as num?)?.toDouble() ?? 0,
      tolls: (map['tolls'] as num?)?.toDouble() ?? 0,
      allowances: (map['allowances'] as num?)?.toDouble() ?? 0,
    );
  }
}

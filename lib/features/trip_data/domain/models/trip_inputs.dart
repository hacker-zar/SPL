enum PricingMode {
  flatRate,
  perTon;

  String get label {
    return switch (this) {
      PricingMode.flatRate => 'Precio del viaje',
      PricingMode.perTon => 'Por tonelada',
    };
  }
}

class TripInputs {
  const TripInputs({
    required this.pricingMode,
    this.flatRate = 0,
    this.tons = 0,
    this.pricePerTon = 0,
  });

  final PricingMode pricingMode;
  final double flatRate;
  final double tons;
  final double pricePerTon;

  double get grossIncome {
    return switch (pricingMode) {
      PricingMode.flatRate => flatRate,
      PricingMode.perTon => tons * pricePerTon,
    };
  }

  bool get isValid {
    return switch (pricingMode) {
      PricingMode.flatRate => flatRate > 0,
      PricingMode.perTon => tons > 0 && pricePerTon > 0,
    };
  }

  Map<String, dynamic> toMap() => {
        'pricingMode': pricingMode.name,
        'flatRate': flatRate,
        'tons': tons,
        'pricePerTon': pricePerTon,
      };

  factory TripInputs.fromMap(Map<String, dynamic> map) {
    final storedMode = map['pricingMode'] as String?;
    final tons = (map['tons'] as num?)?.toDouble() ?? 0;
    final pricePerTon = (map['pricePerTon'] as num?)?.toDouble() ?? 0;
    final pricingMode = storedMode == null && tons > 0 && pricePerTon > 0
        ? PricingMode.perTon
        : PricingMode.values.byName(storedMode ?? PricingMode.flatRate.name);
    return TripInputs(
      pricingMode: pricingMode,
      flatRate: (map['flatRate'] as num?)?.toDouble() ?? 0,
      tons: tons,
      pricePerTon: pricePerTon,
    );
  }
}

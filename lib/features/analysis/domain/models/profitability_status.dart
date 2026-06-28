import 'package:flutter/material.dart';

enum ProfitabilityStatus {
  profitable,
  low,
  loss;

  String get label {
    return switch (this) {
      ProfitabilityStatus.profitable => 'Viaje rentable',
      ProfitabilityStatus.low => 'Rentabilidad baja',
      ProfitabilityStatus.loss => 'No aceptes este viaje',
    };
  }

  Color get color {
    return switch (this) {
      ProfitabilityStatus.profitable => const Color(0xFF1B7F3A),
      ProfitabilityStatus.low => const Color(0xFFE2A400),
      ProfitabilityStatus.loss => const Color(0xFFC62828),
    };
  }
}

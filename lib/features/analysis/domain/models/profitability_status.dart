import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

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
      ProfitabilityStatus.profitable => AppColors.decisionGo,
      ProfitabilityStatus.low => AppColors.decisionLow,
      ProfitabilityStatus.loss => AppColors.decisionStop,
    };
  }
}

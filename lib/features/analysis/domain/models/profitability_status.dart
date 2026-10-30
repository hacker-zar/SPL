import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

enum ProfitabilityStatus {
  profitable,
  low,
  loss;

  String get label {
    return switch (this) {
      ProfitabilityStatus.profitable => 'Conviene',
      ProfitabilityStatus.low => 'Margen bajo',
      ProfitabilityStatus.loss => 'No conviene',
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

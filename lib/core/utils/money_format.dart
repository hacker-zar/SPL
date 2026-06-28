import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

final _moneyFormat = NumberFormat.currency(
  locale: 'es_AR',
  symbol: AppConstants.currencySymbol,
  decimalDigits: 0,
);

final _numberFormat = NumberFormat.decimalPattern('es_AR');

String money(num value) => _moneyFormat.format(value);

String decimal(num value, {int decimals = 1}) {
  _numberFormat.minimumFractionDigits = decimals;
  _numberFormat.maximumFractionDigits = decimals;
  return _numberFormat.format(value);
}

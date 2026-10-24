/// Parses amounts written with Argentine number conventions.
///
/// A comma is always the decimal separator. Dots are thousands separators only
/// when every group after the first contains exactly three digits; otherwise a
/// single dot is treated as a decimal separator.
double? parseAmount(String input) {
  final value = input.replaceAll(r'$', '').replaceAll(RegExp(r'\s+'), '');
  if (value.isEmpty) return null;

  final hasComma = value.contains(',');
  if (hasComma && ','.allMatches(value).length != 1) return null;

  final parts = value.split(',');
  final integerPart = parts.first;
  final decimalPart = hasComma ? parts.last : null;
  if (integerPart.isEmpty ||
      (hasComma && (decimalPart == null || decimalPart.isEmpty))) {
    return null;
  }
  if (decimalPart != null && !RegExp(r'^\d+$').hasMatch(decimalPart)) {
    return null;
  }

  String normalizedInteger;
  if (integerPart.contains('.')) {
    final groups = integerPart.split('.');
    if (groups.any((group) => !RegExp(r'^\d+$').hasMatch(group))) return null;
    final isThousandsGrouping = groups.first.isNotEmpty &&
        groups.first.length <= 3 &&
        groups.skip(1).every((group) => group.length == 3);

    if (hasComma) {
      if (!isThousandsGrouping) return null;
      normalizedInteger = groups.join();
    } else if (groups.length == 2 && !isThousandsGrouping) {
      normalizedInteger = groups.join('.');
    } else if (isThousandsGrouping) {
      normalizedInteger = groups.join();
    } else {
      return null;
    }
  } else {
    if (!RegExp(r'^\d+$').hasMatch(integerPart)) return null;
    normalizedInteger = integerPart;
  }

  final normalized = decimalPart == null
      ? normalizedInteger
      : '$normalizedInteger.$decimalPart';
  return double.tryParse(normalized);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/core/utils/parse_amount.dart';

void main() {
  test('parses Argentine amounts', () {
    expect(parseAmount('1.050.000'), 1050000);
    expect(parseAmount('1.200'), 1200);
    expect(parseAmount('1200,5'), 1200.5);
    expect(parseAmount('35.5'), 35.5);
    expect(parseAmount(r'$ 1.200'), 1200);
    expect(parseAmount('abc'), isNull);
    expect(parseAmount(''), isNull);
  });
}

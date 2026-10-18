import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/trip_data/domain/models/trip_inputs.dart';

void main() {
  test('missing purpose defaults to freight for legacy maps', () {
    final trip = TripInputs.fromMap({'pricingMode': 'flatRate'});
    expect(trip.purpose, TripPurpose.freight);
    expect(trip.isValid, isFalse);
  });

  test('personal purpose is serialized and does not require an income', () {
    const trip = TripInputs(
      pricingMode: PricingMode.flatRate,
      purpose: TripPurpose.personal,
    );
    expect(trip.isValid, isTrue);
    expect(TripInputs.fromMap(trip.toMap()).purpose, TripPurpose.personal);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/domain/models/vehicle_profile.dart';

void main() {
  test('missing daily fixed cost defaults to zero', () {
    final profile = VehicleProfile.fromMap({
      'consumption_liters_per_100_km': 30,
      'maintenance_cost_per_km': 100,
      'capacity_tons': 28,
    });
    expect(profile.dailyFixedCost, 0);
  });
}

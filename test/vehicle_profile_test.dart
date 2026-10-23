import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/domain/models/vehicle_profile.dart';
import 'package:rentabilidad_flete/features/trip_data/domain/models/trip_inputs.dart';

void main() {
  test('missing daily fixed cost defaults to zero', () {
    final profile = VehicleProfile.fromMap({
      'consumption_liters_per_100_km': 30,
      'maintenance_cost_per_km': 100,
      'capacity_tons': 28,
    });
    expect(profile.dailyFixedCost, 0);
  });

  test('personal completeness does not require capacity', () {
    const profile = VehicleProfile(
      consumptionLitersPer100Km: 10,
      maintenanceCostPerKm: 1,
      capacityTons: 0,
    );
    expect(profile.isCompleteFor(TripPurpose.personal), isTrue);
    expect(profile.isCompleteFor(TripPurpose.freight), isFalse);
  });
}

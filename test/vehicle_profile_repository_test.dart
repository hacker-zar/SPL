import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/data/memory_vehicle_profile_repository.dart';
import 'package:rentabilidad_flete/features/vehicle_profile/domain/models/vehicle_profile.dart';

void main() {
  test('vehicle repository model allows multiple vehicles of the same type',
      () async {
    final repository = MemoryVehicleProfileRepository();
    await repository.save(_vehicle());
    await repository.save(_vehicle());

    expect(await repository.watchAll().first, hasLength(2));
  });
}

VehicleProfile _vehicle() => const VehicleProfile(
      consumptionLitersPer100Km: 10,
      maintenanceCostPerKm: 1,
      capacityTons: 28,
      vehicleType: 'camion',
    );

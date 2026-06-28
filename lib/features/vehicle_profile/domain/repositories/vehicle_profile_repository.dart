import '../models/vehicle_profile.dart';

abstract class VehicleProfileRepository {
  Stream<VehicleProfile?> watch();

  Future<void> save(VehicleProfile profile);
}

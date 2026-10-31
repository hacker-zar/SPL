import '../models/vehicle_profile.dart';

abstract class VehicleProfileRepository {
  Stream<VehicleProfile?> watch();

  Stream<List<VehicleProfile>> watchAll() async* {
    await for (final profile in watch()) {
      yield profile == null ? const [] : [profile];
    }
  }

  Future<VehicleProfile> save(VehicleProfile profile);
}

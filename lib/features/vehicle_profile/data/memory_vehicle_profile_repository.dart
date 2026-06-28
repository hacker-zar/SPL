import 'dart:async';

import '../domain/models/vehicle_profile.dart';
import '../domain/repositories/vehicle_profile_repository.dart';

class MemoryVehicleProfileRepository implements VehicleProfileRepository {
  MemoryVehicleProfileRepository([VehicleProfile? initial])
      : _profile = initial ??
            const VehicleProfile(
              consumptionLitersPer100Km: 34,
              maintenanceCostPerKm: 120,
              capacityTons: 28,
            );

  VehicleProfile? _profile;
  final StreamController<VehicleProfile?> _controller =
      StreamController<VehicleProfile?>.broadcast();

  @override
  Stream<VehicleProfile?> watch() async* {
    yield _profile;
    yield* _controller.stream;
  }

  @override
  Future<void> save(VehicleProfile profile) async {
    _profile = profile;
    _controller.add(_profile);
  }
}

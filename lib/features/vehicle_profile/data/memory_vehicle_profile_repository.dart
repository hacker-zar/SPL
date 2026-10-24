import 'dart:async';

import '../domain/models/vehicle_profile.dart';
import '../domain/repositories/vehicle_profile_repository.dart';

class MemoryVehicleProfileRepository implements VehicleProfileRepository {
  MemoryVehicleProfileRepository([VehicleProfile? initial])
      : _profile = initial;

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

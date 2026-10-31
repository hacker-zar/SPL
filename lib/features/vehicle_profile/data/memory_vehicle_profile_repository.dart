import 'dart:async';

import '../domain/models/vehicle_profile.dart';
import '../domain/repositories/vehicle_profile_repository.dart';

class MemoryVehicleProfileRepository implements VehicleProfileRepository {
  MemoryVehicleProfileRepository([VehicleProfile? initial])
      : _profiles = initial == null ? [] : [initial];

  final List<VehicleProfile> _profiles;
  final StreamController<List<VehicleProfile>> _controller =
      StreamController<List<VehicleProfile>>.broadcast();

  @override
  Stream<VehicleProfile?> watch() =>
      watchAll().map((profiles) => profiles.isEmpty ? null : profiles.first);

  @override
  Stream<List<VehicleProfile>> watchAll() async* {
    yield List.unmodifiable(_profiles);
    yield* _controller.stream;
  }

  @override
  Future<VehicleProfile> save(VehicleProfile profile) async {
    final index = profile.id == null
        ? -1
        : _profiles.indexWhere((item) => item.id == profile.id);
    if (index < 0) {
      _profiles.add(profile);
    } else {
      _profiles[index] = profile;
    }
    _controller.add(List.unmodifiable(_profiles));
    return profile;
  }
}

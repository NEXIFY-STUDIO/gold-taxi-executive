import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/config/app_config.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/driver.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/location_point.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/ride.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/vehicle_class.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/repositories/ride_repository.dart';
import 'package:goldtaxi_bolt_v2_5/src/state/app_state.dart';

void main() {
  test('does not subscribe to driver streams before startup is invoked',
      () async {
    final repository = _TrackingRideRepository();
    final state = AppState(
      repository: repository,
      config: const AppConfig(),
    );

    addTearDown(() {
      state.dispose();
      repository.dispose();
    });

    expect(repository.nearbyDriversCalls, 0);

    await state.start();

    expect(repository.nearbyDriversCalls, 1);
  });
}

class _TrackingRideRepository implements RideRepository {
  final _driversController = StreamController<List<Driver>>.broadcast();
  int nearbyDriversCalls = 0;

  @override
  Stream<List<Driver>> nearbyDrivers(LocationPoint center) {
    nearbyDriversCalls += 1;
    return _driversController.stream;
  }

  @override
  Future<Ride> createRide({
    required LocationPoint pickup,
    required LocationPoint dropoff,
    required VehicleClass vehicleClass,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<Ride> watchRide(String rideId) => const Stream<Ride>.empty();

  @override
  Future<void> acceptRide(String rideId) async {}

  @override
  Future<void> declineRide(String rideId, String reason) async {}

  @override
  Future<void> markArrived(String rideId) async {}

  @override
  Future<void> startRide(String rideId) async {}

  @override
  Future<void> completeRide(String rideId) async {}

  @override
  Future<void> cancelRide(String rideId, String reason) async {}

  @override
  Future<void> adminCancelRide(String rideId, String reason) async {}

  @override
  Future<void> setDriverOnline(bool online) async {}

  @override
  void dispose() {
    _driversController.close();
  }
}

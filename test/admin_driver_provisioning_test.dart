import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/config/app_config.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/driver.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/driver_approval.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/location_point.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/ride.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/vehicle_class.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/repositories/ride_repository.dart';
import 'package:goldtaxi_bolt_v2_5/src/models/app_user_role.dart';
import 'package:goldtaxi_bolt_v2_5/src/state/app_state.dart';

void main() {
  test('passenger cannot approve themselves as driver', () async {
    final repository = _ProvisioningRideRepository();
    final state = AppState(
      repository: repository,
      config: const AppConfig(),
      userRole: AppUserRole.passenger,
    );

    addTearDown(() {
      state.dispose();
      repository.dispose();
    });

    await state.approveDriver(_input(targetUid: 'passenger-user'));

    expect(repository.approvals, isEmpty);
    expect(state.error, 'Ops role required.');
  });

  test('driver cannot approve other drivers', () async {
    final repository = _ProvisioningRideRepository();
    final state = AppState(
      repository: repository,
      config: const AppConfig(),
      userRole: AppUserRole.driver,
    );

    addTearDown(() {
      state.dispose();
      repository.dispose();
    });

    await state.approveDriver(_input(targetUid: 'passenger-user'));

    expect(repository.approvals, isEmpty);
    expect(state.error, 'Ops role required.');
  });

  test('admin can submit driver approval profile', () async {
    final repository = _ProvisioningRideRepository();
    final state = AppState(
      repository: repository,
      config: const AppConfig(),
      userRole: AppUserRole.admin,
    );

    addTearDown(() {
      state.dispose();
      repository.dispose();
    });

    await state.approveDriver(_input(targetUid: 'passenger-user'));

    expect(repository.approvals, hasLength(1));
    expect(repository.approvals.single.toJson(), {
      'targetUid': 'passenger-user',
      'name': 'Erik Driver',
      'phone': '+421900000000',
      'vehicleLabel': 'Mercedes S-Class',
      'licensePlate': 'ZH 824 611',
      'vehicleClass': 'premium',
    });
    expect(state.error, isNull);
    expect(state.opsNotice, contains('Erik Driver approved as driver'));
  });
}

DriverApprovalInput _input({required String targetUid}) {
  return DriverApprovalInput(
    targetUid: targetUid,
    name: 'Erik Driver',
    phone: '+421900000000',
    vehicleLabel: 'Mercedes S-Class',
    licensePlate: 'zh 824 611',
    vehicleClass: VehicleClass.premium,
  );
}

class _ProvisioningRideRepository implements RideRepository {
  final _driversController = StreamController<List<Driver>>.broadcast()
    ..add(const []);
  final approvals = <DriverApprovalInput>[];

  @override
  Stream<List<Driver>> nearbyDrivers(LocationPoint center) {
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
  Future<String> approveDriver(DriverApprovalInput input) async {
    approvals.add(input);
    return 'driver-passenger-user';
  }

  @override
  Future<void> setDriverOnline(bool online) async {}

  @override
  void dispose() {
    _driversController.close();
  }
}

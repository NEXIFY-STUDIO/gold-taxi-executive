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
  test('passenger can create a driver application', () async {
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

    await state.submitDriverApplication(_applicationInput());

    expect(repository.submittedApplications, hasLength(1));
    expect(repository.approvedApplicationIds, isEmpty);
    expect(repository.submittedApplications.single.toJson(), {
      'fullName': 'Erik Driver',
      'phone': '+421900000000',
      'vehicleLabel': 'Mercedes S-Class',
      'licensePlate': 'ZH 824 611',
      'vehicleClass': 'executive',
    });
    expect(state.driverApplicationNotice, contains('Driver request sent'));
  });

  test('passenger cannot approve driver request', () async {
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

    await state.approveDriverApplication(repository.pendingApplication);

    expect(repository.approvedApplicationIds, isEmpty);
    expect(state.error, 'Ops role required.');
  });

  test('driver cannot approve other driver requests', () async {
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

    await state.approveDriverApplication(repository.pendingApplication);

    expect(repository.approvedApplicationIds, isEmpty);
    expect(state.error, 'Ops role required.');
  });

  test('admin can approve driver request and refresh request list', () async {
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

    await state.loadDriverApplications();
    await state.approveDriverApplication(repository.pendingApplication);

    expect(repository.approvedApplicationIds, ['application-passenger']);
    expect(state.error, isNull);
    expect(state.opsNotice, contains('Erik Driver approved as driver'));
    expect(state.driverApplications.single.status,
        DriverApplicationStatus.approved);
  });

  test('admin rejection keeps passenger out of driver role', () async {
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

    await state.rejectDriverApplication(repository.pendingApplication);

    expect(repository.rejectedApplicationIds, ['application-passenger']);
    expect(repository.approvedApplicationIds, isEmpty);
    expect(state.opsNotice, contains('driver request rejected'));
    expect(state.driverApplications.single.status,
        DriverApplicationStatus.rejected);
  });
}

DriverApplicationInput _applicationInput() {
  return const DriverApplicationInput(
    fullName: 'Erik Driver',
    phone: '+421900000000',
    vehicleLabel: 'Mercedes S-Class',
    licensePlate: 'zh 824 611',
    vehicleClass: DriverApplicationVehicleClass.executive,
  );
}

class _ProvisioningRideRepository implements RideRepository {
  final _driversController = StreamController<List<Driver>>.broadcast()
    ..add(const []);
  final submittedApplications = <DriverApplicationInput>[];
  final approvedApplicationIds = <String>[];
  final rejectedApplicationIds = <String>[];

  late DriverApplication pendingApplication = DriverApplication(
    id: 'application-passenger',
    userId: 'passenger-user',
    fullName: 'Erik Driver',
    phone: '+421900000000',
    vehicleLabel: 'Mercedes S-Class',
    licensePlate: 'ZH 824 611',
    vehicleClass: DriverApplicationVehicleClass.executive,
    status: DriverApplicationStatus.pending,
    createdAt: DateTime.utc(2026, 6, 19),
    updatedAt: DateTime.utc(2026, 6, 19),
  );

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
  Future<String> submitDriverApplication(DriverApplicationInput input) async {
    submittedApplications.add(input);
    return pendingApplication.id;
  }

  @override
  Future<List<DriverApplication>> loadDriverApplications() async {
    return [pendingApplication];
  }

  @override
  Future<String> approveDriverApplication(String applicationId) async {
    approvedApplicationIds.add(applicationId);
    pendingApplication = DriverApplication(
      id: pendingApplication.id,
      userId: pendingApplication.userId,
      fullName: pendingApplication.fullName,
      phone: pendingApplication.phone,
      vehicleLabel: pendingApplication.vehicleLabel,
      licensePlate: pendingApplication.licensePlate,
      vehicleClass: pendingApplication.vehicleClass,
      status: DriverApplicationStatus.approved,
      createdAt: pendingApplication.createdAt,
      updatedAt: DateTime.utc(2026, 6, 19, 1),
    );
    return 'driver-passenger-user';
  }

  @override
  Future<void> rejectDriverApplication(
    String applicationId,
    String reason,
  ) async {
    rejectedApplicationIds.add(applicationId);
    pendingApplication = DriverApplication(
      id: pendingApplication.id,
      userId: pendingApplication.userId,
      fullName: pendingApplication.fullName,
      phone: pendingApplication.phone,
      vehicleLabel: pendingApplication.vehicleLabel,
      licensePlate: pendingApplication.licensePlate,
      vehicleClass: pendingApplication.vehicleClass,
      status: DriverApplicationStatus.rejected,
      createdAt: pendingApplication.createdAt,
      updatedAt: DateTime.utc(2026, 6, 19, 1),
      rejectionReason: reason,
    );
  }

  @override
  Future<String> approveDriver(DriverApprovalInput input) async =>
      'driver-passenger-user';

  @override
  Future<void> setDriverOnline(bool online) async {}

  @override
  void dispose() {
    _driversController.close();
  }
}

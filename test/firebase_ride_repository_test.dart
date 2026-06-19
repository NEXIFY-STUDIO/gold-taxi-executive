import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/models/app_user_role.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/driver.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/location_point.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/ride.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/models/vehicle_class.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/repositories/firebase_ride_repository.dart';
import 'package:goldtaxi_bolt_v2_5/src/data/repositories/firebase_runtime_gateway.dart';

void main() {
  test('FirebaseRideRepository delegates ride commands and streams', () async {
    final gateway = FakeFirebaseRuntimeGateway();
    final repository = FirebaseRideRepository(gateway: gateway);

    addTearDown(gateway.dispose);

    await repository.initialize();
    expect(gateway.initialized, isTrue);

    final driverStream = repository.nearbyDrivers(
      const LocationPoint(latitude: 47.3769, longitude: 8.5417, label: 'HB'),
    );
    expect(await driverStream.first, isNotEmpty);

    final ride = await repository.createRide(
      pickup: const LocationPoint(
        latitude: 47.3769,
        longitude: 8.5417,
        label: 'HB',
      ),
      dropoff: const LocationPoint(
        latitude: 47.4581,
        longitude: 8.5555,
        label: 'Airport',
      ),
      vehicleClass: VehicleClass.comfort,
    );

    expect(ride.status, RideStatus.searching);
    expect(gateway.createRideCalls, 1);

    await repository.setDriverOnline(true);
    expect(gateway.setDriverOnlineCalls, [true]);

    await repository.acceptRide('ride-1');
    await repository.declineRide('ride-1', 'no thanks');
    await repository.markArrived('ride-1');
    await repository.startRide('ride-1');
    await repository.completeRide('ride-1');
    await repository.cancelRide('ride-1', 'ops');
    await repository.adminCancelRide('ride-1', 'ops');

    expect(gateway.commandLog, [
      'accept:ride-1',
      'decline:ride-1:no thanks',
      'arrived:ride-1',
      'start:ride-1',
      'complete:ride-1',
      'cancel:ride-1:ops',
      'ops-cancel:ride-1:ops',
    ]);

    final watched = repository.watchRide('ride-1');
    expect(await watched.first, isA<Ride>());
  });
}

class FakeFirebaseRuntimeGateway implements FirebaseRuntimeGateway {
  FakeFirebaseRuntimeGateway();

  bool initialized = false;
  @override
  AppUserRole get userRole => AppUserRole.driver;
  int createRideCalls = 0;
  final setDriverOnlineCalls = <bool>[];
  final commandLog = <String>[];
  Ride? _currentRide;
  List<Driver> _currentDrivers = const [];

  @override
  Future<void> initialize() async {
    initialized = true;
    _currentDrivers = [
      const Driver(
        id: 'drv-1',
        name: 'Markus Keller',
        vehicleName: 'Mercedes S-Class',
        plateNumber: 'ZH 824 611',
        vehicleClass: VehicleClass.premium,
        location: LocationPoint(
          latitude: 47.3778,
          longitude: 8.5394,
          label: 'Bahnhofstrasse',
        ),
        heading: 94,
        rating: 4.96,
        status: DriverStatus.idle,
        photoUrl: '',
      ),
    ];
  }

  @override
  Stream<List<Driver>> watchDrivers(LocationPoint center) =>
      Stream<List<Driver>>.value(_currentDrivers);

  @override
  Stream<Ride> watchRide(String rideId) => _currentRide == null
      ? const Stream<Ride>.empty()
      : Stream<Ride>.value(_currentRide!);

  @override
  Future<Ride> createRide({
    required LocationPoint pickup,
    required LocationPoint dropoff,
    required VehicleClass vehicleClass,
  }) async {
    createRideCalls += 1;
    final ride = Ride(
      id: 'ride-1',
      pickup: pickup,
      dropoff: dropoff,
      vehicleClass: vehicleClass,
      status: RideStatus.searching,
      estimatedFare: 42,
      finalFare: null,
      distanceKm: 8.1,
      durationMinutes: 18,
      createdAt: DateTime.now(),
    );
    _currentRide = ride;
    return ride;
  }

  @override
  Future<void> acceptRide(String rideId) async {
    commandLog.add('accept:$rideId');
  }

  @override
  Future<void> declineRide(String rideId, String reason) async {
    commandLog.add('decline:$rideId:$reason');
  }

  @override
  Future<void> markArrived(String rideId) async {
    commandLog.add('arrived:$rideId');
  }

  @override
  Future<void> startRide(String rideId) async {
    commandLog.add('start:$rideId');
  }

  @override
  Future<void> completeRide(String rideId) async {
    commandLog.add('complete:$rideId');
  }

  @override
  Future<void> cancelRide(String rideId, String reason) async {
    commandLog.add('cancel:$rideId:$reason');
  }

  @override
  Future<void> adminCancelRide(String rideId, String reason) async {
    commandLog.add('ops-cancel:$rideId:$reason');
  }

  @override
  Future<void> setDriverOnline(bool online) async {
    setDriverOnlineCalls.add(online);
  }

  void dispose() {}
}

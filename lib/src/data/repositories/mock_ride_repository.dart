import 'dart:async';
import 'dart:math';

import '../../services/dispatch_service.dart';
import '../../services/payment_gateway.dart';
import '../../services/pricing_service.dart';
import '../models/driver.dart';
import '../models/driver_approval.dart';
import '../models/location_point.dart';
import '../models/ride.dart';
import '../models/vehicle_class.dart';
import 'ride_repository.dart';

class MockRideRepository implements RideRepository {
  MockRideRepository({
    this.offerTimeout = const Duration(seconds: 15),
    this.approachTickInterval = const Duration(milliseconds: 700),
    this.approachProgressPerTick = .13,
  });

  final _pricing = const PricingService();
  final _dispatch = const DispatchService();
  final _payment = MockPaymentGateway();
  final Map<String, StreamController<Ride>> _rideControllers = {};
  final Map<String, Ride> _rides = {};
  final Map<String, DriverApplication> _driverApplications = {};
  Timer? _driverTimer;
  Timer? _offerTimer;
  double _tick = 0;
  bool _disposed = false;
  final Duration offerTimeout;
  final Duration approachTickInterval;
  final double approachProgressPerTick;

  final List<Driver> _drivers = [
    const Driver(
      id: 'drv_001',
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
    const Driver(
      id: 'drv_002',
      name: 'Daniel Horváth',
      vehicleName: 'BMW 7 Series',
      plateNumber: 'ZH 442 900',
      vehicleClass: VehicleClass.comfort,
      location: LocationPoint(
        latitude: 47.3727,
        longitude: 8.5481,
        label: 'Altstadt',
      ),
      heading: 310,
      rating: 4.91,
      status: DriverStatus.idle,
      photoUrl: '',
    ),
    const Driver(
      id: 'drv_003',
      name: 'Luca Steiner',
      vehicleName: 'Mercedes V-Class',
      plateNumber: 'ZH 220 118',
      vehicleClass: VehicleClass.van,
      location: LocationPoint(
        latitude: 47.3816,
        longitude: 8.5317,
        label: 'Hardbrücke',
      ),
      heading: 12,
      rating: 4.88,
      status: DriverStatus.idle,
      photoUrl: '',
    ),
  ];

  @override
  Stream<List<Driver>> nearbyDrivers(LocationPoint center) {
    final controller = StreamController<List<Driver>>.broadcast();
    Timer? timer;

    void emit() {
      _tick += .14;
      controller.add(
        _drivers.map((driver) {
          final wobbleLat = sin(_tick + driver.id.hashCode) * .00045;
          final wobbleLng = cos(_tick + driver.id.hashCode) * .00045;
          return driver.copyWith(
            location: LocationPoint(
              latitude: driver.location.latitude + wobbleLat,
              longitude: driver.location.longitude + wobbleLng,
              label: driver.location.label,
            ),
            heading: (driver.heading + _tick * 30) % 360,
          );
        }).toList(),
      );
    }

    controller.onListen = () {
      emit();
      timer = Timer.periodic(const Duration(seconds: 1), (_) => emit());
    };
    controller.onCancel = () {
      timer?.cancel();
      timer = null;
    };

    return controller.stream;
  }

  @override
  Future<Ride> createRide({
    required LocationPoint pickup,
    required LocationPoint dropoff,
    required VehicleClass vehicleClass,
  }) async {
    final estimate = _pricing.estimate(
      pickup: pickup,
      dropoff: dropoff,
      vehicleClass: vehicleClass,
      surgeMultiplier: _surgeFor(pickup),
    );

    await _payment.authorize(
      customerId: 'mock_customer',
      amount: estimate.amount * 1.2,
      currency: 'CHF',
    );

    final id = 'ride_${DateTime.now().millisecondsSinceEpoch}';
    final ride = Ride(
      id: id,
      pickup: pickup,
      dropoff: dropoff,
      vehicleClass: vehicleClass,
      status: RideStatus.searching,
      estimatedFare: estimate.amount,
      finalFare: null,
      distanceKm: estimate.distanceKm,
      durationMinutes: estimate.durationMinutes,
      createdAt: DateTime.now(),
      surgeMultiplier: estimate.surgeMultiplier,
    );

    final controller = StreamController<Ride>.broadcast();
    _rideControllers[id] = controller;
    _rides[id] = ride;
    controller.add(ride);

    _scheduleOfferExpiry(id);
    return ride;
  }

  @override
  Stream<Ride> watchRide(String rideId) {
    final existing = _rideControllers[rideId];
    if (existing == null) {
      return const Stream<Ride>.empty();
    }
    return existing.stream;
  }

  @override
  Future<void> acceptRide(String rideId) async {
    final ride = _rides[rideId];
    if (ride == null) return;
    _offerTimer?.cancel();
    if (!ride.status.canTransitionTo(RideStatus.accepted)) {
      throw StateError(
        'Cannot accept ride in ${ride.status.name} state.',
      );
    }

    final driver = _dispatch.pickBestDriver(
      drivers: _drivers,
      pickup: ride.pickup,
      requestedClass: ride.vehicleClass,
    );

    if (driver == null) {
      _emit(ride.transitionTo(RideStatus.cancelled));
      return;
    }

    _setDriverStatus(driver.id, DriverStatus.busy);
    _emit(
      ride.transitionTo(
        RideStatus.accepted,
        driver: driver.copyWith(status: DriverStatus.busy),
      ),
    );
    _simulateDriverApproach(rideId);
  }

  @override
  Future<void> declineRide(String rideId, String reason) async {
    final ride = _rides[rideId];
    if (ride == null) return;
    _offerTimer?.cancel();
    if (!ride.status.canTransitionTo(RideStatus.cancelled)) {
      throw StateError(
        'Cannot decline ride in ${ride.status.name} state.',
      );
    }

    _emit(ride.transitionTo(RideStatus.cancelled));
  }

  @override
  Future<void> markArrived(String rideId) async {
    final ride = _rides[rideId];
    if (ride == null) return;
    if (ride.status == RideStatus.accepted ||
        ride.status == RideStatus.driverArriving) {
      _driverTimer?.cancel();
      _emit(ride.transitionTo(RideStatus.arrived));
      return;
    }
    throw StateError('Cannot mark ride arrived in ${ride.status.name} state.');
  }

  @override
  Future<void> startRide(String rideId) async {
    final ride = _rides[rideId];
    if (ride == null) return;
    if (ride.status != RideStatus.arrived) {
      throw StateError('Cannot start ride in ${ride.status.name} state.');
    }
    _emit(ride.transitionTo(RideStatus.inProgress));
  }

  @override
  Future<void> completeRide(String rideId) async {
    final ride = _rides[rideId];
    if (ride == null) return;
    if (ride.status != RideStatus.inProgress) {
      throw StateError('Cannot complete ride in ${ride.status.name} state.');
    }
    final waitFee = ride.waitMinutes * .35;
    final finalFare =
        ((ride.estimatedFare + waitFee) * 100).roundToDouble() / 100;
    await _payment.capture(
      authorizationId: 'mock_auth',
      finalAmount: finalFare,
    );
    _emit(
      ride.transitionTo(
        RideStatus.completed,
        finalFare: finalFare,
      ),
    );
    if (ride.driver != null) {
      _setDriverStatus(ride.driver!.id, DriverStatus.idle);
    }
  }

  @override
  Future<void> cancelRide(String rideId, String reason) async {
    final ride = _rides[rideId];
    if (ride == null) return;
    await _payment.cancelAuthorization('mock_auth');
    _offerTimer?.cancel();
    _emit(ride.transitionTo(RideStatus.cancelled));
    if (ride.driver != null) {
      _setDriverStatus(ride.driver!.id, DriverStatus.idle);
    }
  }

  @override
  Future<void> adminCancelRide(String rideId, String reason) async {
    await cancelRide(rideId, reason);
  }

  @override
  Future<String> submitDriverApplication(DriverApplicationInput input) async {
    final id = 'app_${DateTime.now().millisecondsSinceEpoch}';
    _driverApplications[id] = DriverApplication(
      id: id,
      userId: 'mock-passenger',
      fullName: input.fullName.trim(),
      phone: input.phone.trim(),
      vehicleLabel: input.vehicleLabel.trim(),
      licensePlate: input.licensePlate.trim().toUpperCase(),
      vehicleClass: input.vehicleClass,
      status: DriverApplicationStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return id;
  }

  @override
  Future<List<DriverApplication>> loadDriverApplications() async {
    return _driverApplications.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<String> approveDriverApplication(String applicationId) async {
    final application = _driverApplications[applicationId];
    if (application == null) {
      throw StateError('Driver application not found.');
    }
    final driverId = await approveDriver(
      DriverApprovalInput(
        targetUid: application.userId,
        name: application.fullName,
        phone: application.phone,
        vehicleLabel: application.vehicleLabel,
        licensePlate: application.licensePlate,
        vehicleClass: application.vehicleClass.driverVehicleClass,
      ),
    );
    _driverApplications[applicationId] = DriverApplication(
      id: application.id,
      userId: application.userId,
      fullName: application.fullName,
      phone: application.phone,
      vehicleLabel: application.vehicleLabel,
      licensePlate: application.licensePlate,
      vehicleClass: application.vehicleClass,
      status: DriverApplicationStatus.approved,
      createdAt: application.createdAt,
      updatedAt: DateTime.now(),
    );
    return driverId;
  }

  @override
  Future<void> rejectDriverApplication(
    String applicationId,
    String reason,
  ) async {
    final application = _driverApplications[applicationId];
    if (application == null) {
      throw StateError('Driver application not found.');
    }
    _driverApplications[applicationId] = DriverApplication(
      id: application.id,
      userId: application.userId,
      fullName: application.fullName,
      phone: application.phone,
      vehicleLabel: application.vehicleLabel,
      licensePlate: application.licensePlate,
      vehicleClass: application.vehicleClass,
      status: DriverApplicationStatus.rejected,
      createdAt: application.createdAt,
      updatedAt: DateTime.now(),
      rejectionReason: reason.trim(),
    );
  }

  @override
  Future<String> approveDriver(DriverApprovalInput input) async {
    final driverId = 'drv_${input.targetUid.trim()}';
    final existingIndex =
        _drivers.indexWhere((driver) => driver.id == driverId);
    final driver = Driver(
      id: driverId,
      name: input.name.trim(),
      vehicleName: input.vehicleLabel.trim(),
      plateNumber: input.licensePlate.trim().toUpperCase(),
      vehicleClass: input.vehicleClass,
      location: const LocationPoint(
        latitude: 47.3769,
        longitude: 8.5417,
        label: 'Zürich HB',
      ),
      heading: 0,
      rating: 5,
      status: DriverStatus.offline,
      photoUrl: '',
    );
    if (existingIndex == -1) {
      _drivers.add(driver);
    } else {
      _drivers[existingIndex] = driver;
    }
    return driverId;
  }

  void _scheduleOfferExpiry(String rideId) {
    _offerTimer?.cancel();
    _offerTimer = Timer(offerTimeout, () {
      if (_disposed) return;
      final ride = _rides[rideId];
      if (ride == null || ride.status != RideStatus.searching) return;
      _emit(ride.transitionTo(RideStatus.cancelled));
    });
  }

  void _simulateDriverApproach(String rideId) {
    _driverTimer?.cancel();
    var progress = 0.0;

    _driverTimer = Timer.periodic(approachTickInterval, (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }

      final ride = _rides[rideId];
      final driver = ride?.driver;
      if (ride == null || driver == null || !ride.status.isActive) {
        timer.cancel();
        return;
      }

      var nextRide = ride;
      if (nextRide.status == RideStatus.accepted) {
        nextRide = nextRide.transitionTo(RideStatus.driverArriving);
        _emit(nextRide);
      }

      progress += approachProgressPerTick;

      if (progress >= 1) {
        if (nextRide.status == RideStatus.driverArriving) {
          _emit(nextRide.transitionTo(RideStatus.arrived));
        }
        timer.cancel();
        return;
      }

      final location = nextRide.driver!.location.interpolateTo(
        nextRide.pickup,
        progress,
        label: nextRide.driver!.location.label,
      );

      _emit(nextRide.copyWith(
        status: RideStatus.driverArriving,
        driver: nextRide.driver!.copyWith(
          location: location,
          heading: location.bearingTo(nextRide.pickup),
        ),
      ));
    });
  }

  double _surgeFor(LocationPoint pickup) {
    final hour = DateTime.now().hour;
    final airportDistance = pickup.distanceKmTo(
      const LocationPoint(
        latitude: 47.4581,
        longitude: 8.5555,
        label: 'Zürich Airport',
      ),
    );

    if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
      return 1.25;
    }
    if (airportDistance < 2) return 1.15;
    return 1.0;
  }

  void _emit(Ride ride) {
    if (_disposed) return;
    _rides[ride.id] = ride;
    _rideControllers[ride.id]?.add(ride);
  }

  void _setDriverStatus(String driverId, DriverStatus status) {
    final index = _drivers.indexWhere((driver) => driver.id == driverId);
    if (index == -1) return;
    _drivers[index] = _drivers[index].copyWith(status: status);
  }

  @override
  void dispose() {
    _disposed = true;
    _offerTimer?.cancel();
    _driverTimer?.cancel();
    for (final controller in _rideControllers.values) {
      controller.close();
    }
  }

  @override
  Future<void> setDriverOnline(bool online) async {}
}

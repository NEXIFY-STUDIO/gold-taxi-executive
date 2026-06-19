import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../data/models/driver.dart';
import '../data/models/location_point.dart';
import '../data/models/ride.dart';
import '../data/models/vehicle_class.dart';
import '../data/repositories/ride_repository.dart';
import '../models/app_user_role.dart';
import '../services/pricing_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    required RideRepository repository,
    required this.config,
    this.userRole = AppUserRole.passenger,
  }) : _repository = repository;

  final RideRepository _repository;
  final AppConfig config;
  final AppUserRole userRole;
  final PricingService pricing = const PricingService();

  LocationPoint currentLocation = const LocationPoint(
    latitude: 47.3769,
    longitude: 8.5417,
    label: 'Zürich HB',
  );

  LocationPoint pickup = const LocationPoint(
    latitude: 47.3769,
    longitude: 8.5417,
    label: 'Zürich Hauptbahnhof',
  );

  LocationPoint dropoff = const LocationPoint(
    latitude: 47.4581,
    longitude: 8.5555,
    label: 'Zürich Airport',
  );

  VehicleClass selectedClass = VehicleClass.comfort;
  List<Driver> drivers = [];
  List<Ride> rides = [];
  Ride? activeRide;
  bool isLoading = false;
  bool driverOnline = false;
  int driverOfferSecondsRemaining = 0;
  int completedTrips = 0;
  double earningsToday = 0;
  int shellIndex = 0;
  String? error;
  String? opsNotice;

  StreamSubscription<List<Driver>>? _driverSubscription;
  StreamSubscription<Ride>? _rideSubscription;
  Timer? _offerCountdownTimer;
  final Set<String> _creditedRideIds = {};
  bool _started = false;

  bool get canAccessDriverConsole => userRole.canAccessDriverTools;

  bool get canAccessOpsConsole => userRole.canAccessOpsTools;

  List<int> get visibleShellIndices => userRole.visibleShellIndices;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    _driverSubscription = _repository.nearbyDrivers(currentLocation).listen(
      (items) {
        drivers = items;
        notifyListeners();
      },
    );
  }

  PriceEstimate estimateFor(VehicleClass vehicleClass) {
    return pricing.estimate(
      pickup: pickup,
      dropoff: dropoff,
      vehicleClass: vehicleClass,
      surgeMultiplier: _visibleSurge,
    );
  }

  double get _visibleSurge {
    final airportDistance = pickup.distanceKmTo(dropoff);
    return airportDistance > 8 ? 1.12 : 1.0;
  }

  void setShellIndex(int value) {
    shellIndex = visibleShellIndices.contains(value) ? value : 0;
    notifyListeners();
  }

  void setSelectedClass(VehicleClass value) {
    selectedClass = value;
    notifyListeners();
  }

  void updatePickupLabel(String label) {
    pickup = LocationPoint(
      latitude: pickup.latitude,
      longitude: pickup.longitude,
      label: label.trim().isEmpty ? 'Pickup' : label.trim(),
    );
    notifyListeners();
  }

  void updatePickupLocation(LocationPoint value) {
    pickup = value;
    notifyListeners();
  }

  void updateDropoffLabel(String label) {
    dropoff = LocationPoint(
      latitude: dropoff.latitude,
      longitude: dropoff.longitude,
      label: label.trim().isEmpty ? 'Dropoff' : label.trim(),
    );
    notifyListeners();
  }

  void updateDropoffLocation(LocationPoint value) {
    dropoff = value;
    notifyListeners();
  }

  Future<void> requestRide() async {
    if (isLoading) return;
    if (activeRide != null) {
      error = 'Please complete or cancel current ride first.';
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final ride = await _repository.createRide(
        pickup: pickup,
        dropoff: dropoff,
        vehicleClass: selectedClass,
      );

      activeRide = ride;
      _upsertRide(ride);
      _rideSubscription?.cancel();
      _rideSubscription = _repository.watchRide(ride.id).listen((updated) {
        activeRide = updated;
        _upsertRide(updated);
        _handleRideUpdate(updated);
        notifyListeners();
      });
      if (driverOnline && ride.status == RideStatus.searching) {
        _startOfferCountdown();
      }
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startRide() async {
    if (!_requireDriverRole()) return;
    final ride = activeRide;
    if (ride == null) return;
    await _repository.startRide(ride.id);
  }

  Future<void> acceptRideOffer() async {
    if (!_requireDriverRole()) return;
    final ride = activeRide;
    if (ride == null) return;
    await _repository.acceptRide(ride.id);
  }

  Future<void> declineRideOffer() async {
    if (!_requireDriverRole()) return;
    final ride = activeRide;
    if (ride == null) return;
    await _repository.declineRide(ride.id, 'Declined by driver');
  }

  Future<void> markArrived() async {
    if (!_requireDriverRole()) return;
    final ride = activeRide;
    if (ride == null) return;
    await _repository.markArrived(ride.id);
  }

  Future<void> completeRide() async {
    if (!_requireDriverRole()) return;
    final ride = activeRide;
    if (ride == null) return;
    await _repository.completeRide(ride.id);
  }

  Future<void> cancelRide() async {
    final ride = activeRide;
    if (ride == null) return;
    await _repository.cancelRide(ride.id, 'Cancelled by passenger');
  }

  Future<void> adminCancelRide(Ride ride) async {
    if (!_requireOpsRole()) return;
    await _repository.adminCancelRide(ride.id, 'Cancelled by ops');
    opsNotice = 'Ride ${ride.id} cancelled by ops.';
    notifyListeners();
  }

  Future<void> resolveRide(Ride ride) async {
    if (!_requireOpsRole()) return;
    await adminCancelRide(ride);
    opsNotice = 'Ride ${ride.id} resolved by ops.';
    notifyListeners();
  }

  void clearCompletedRide() {
    activeRide = null;
    _offerCountdownTimer?.cancel();
    driverOfferSecondsRemaining = 0;
    _rideSubscription?.cancel();
    _rideSubscription = null;
    notifyListeners();
  }

  void toggleDriverOnline() {
    if (!_requireDriverRole()) return;
    driverOnline = !driverOnline;
    unawaited(_repository.setDriverOnline(driverOnline));
    if (driverOnline && activeRide?.status == RideStatus.searching) {
      _startOfferCountdown();
    } else if (!driverOnline) {
      _offerCountdownTimer?.cancel();
      driverOfferSecondsRemaining = 0;
    }
    notifyListeners();
  }

  void _handleRideUpdate(Ride ride) {
    _upsertRide(ride);
    if (ride.status == RideStatus.searching && driverOnline) {
      _startOfferCountdown();
      return;
    }

    if (ride.status == RideStatus.accepted ||
        ride.status == RideStatus.driverArriving ||
        ride.status == RideStatus.arrived ||
        ride.status == RideStatus.inProgress) {
      _offerCountdownTimer?.cancel();
      driverOfferSecondsRemaining = 0;
    }

    if (ride.status == RideStatus.completed && _creditedRideIds.add(ride.id)) {
      completedTrips += 1;
      earningsToday += ride.finalFare ?? ride.estimatedFare;
    }

    if (ride.status == RideStatus.cancelled) {
      _offerCountdownTimer?.cancel();
      driverOfferSecondsRemaining = 0;
    }
  }

  void _upsertRide(Ride ride) {
    final index = rides.indexWhere((item) => item.id == ride.id);
    if (index == -1) {
      rides = [...rides, ride];
    } else {
      final updated = [...rides];
      updated[index] = ride;
      rides = updated;
    }
  }

  void _startOfferCountdown() {
    _offerCountdownTimer?.cancel();
    driverOfferSecondsRemaining = 15;
    _offerCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (driverOfferSecondsRemaining <= 1) {
        driverOfferSecondsRemaining = 0;
        timer.cancel();
      } else {
        driverOfferSecondsRemaining -= 1;
      }
      notifyListeners();
    });
  }

  bool _requireDriverRole() {
    if (canAccessDriverConsole) {
      return true;
    }
    error = 'Driver role required.';
    notifyListeners();
    return false;
  }

  bool _requireOpsRole() {
    if (canAccessOpsConsole) {
      return true;
    }
    error = 'Ops role required.';
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    _driverSubscription?.cancel();
    _rideSubscription?.cancel();
    _offerCountdownTimer?.cancel();
    super.dispose();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found.');
    return scope!.notifier!;
  }
}

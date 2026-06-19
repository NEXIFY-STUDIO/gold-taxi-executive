import 'driver.dart';
import 'location_point.dart';
import 'vehicle_class.dart';

enum RideStatus {
  draft,
  searching,
  accepted,
  driverArriving,
  arrived,
  inProgress,
  completed,
  cancelled,
  paymentFailed;

  String get label {
    return switch (this) {
      RideStatus.draft => 'Draft',
      RideStatus.searching => 'Searching',
      RideStatus.accepted => 'Driver accepted',
      RideStatus.driverArriving => 'Driver arriving',
      RideStatus.arrived => 'Driver arrived',
      RideStatus.inProgress => 'Ride in progress',
      RideStatus.completed => 'Completed',
      RideStatus.cancelled => 'Cancelled',
      RideStatus.paymentFailed => 'Payment failed',
    };
  }

  bool get isActive =>
      this == RideStatus.searching ||
      this == RideStatus.accepted ||
      this == RideStatus.driverArriving ||
      this == RideStatus.arrived ||
      this == RideStatus.inProgress;

  bool canTransitionTo(RideStatus next) {
    return switch (this) {
      RideStatus.draft =>
        next == RideStatus.searching || next == RideStatus.cancelled,
      RideStatus.searching =>
        next == RideStatus.accepted || next == RideStatus.cancelled,
      RideStatus.accepted =>
        next == RideStatus.driverArriving || next == RideStatus.cancelled,
      RideStatus.driverArriving =>
        next == RideStatus.arrived || next == RideStatus.cancelled,
      RideStatus.arrived =>
        next == RideStatus.inProgress || next == RideStatus.cancelled,
      RideStatus.inProgress =>
        next == RideStatus.completed || next == RideStatus.cancelled,
      RideStatus.completed ||
      RideStatus.cancelled ||
      RideStatus.paymentFailed =>
        false,
    };
  }

  RideStatus transitionTo(RideStatus next) {
    if (!canTransitionTo(next)) {
      throw StateError('Invalid ride transition from $name to ${next.name}.');
    }
    return next;
  }
}

class Ride {
  const Ride({
    required this.id,
    required this.pickup,
    required this.dropoff,
    required this.vehicleClass,
    required this.status,
    required this.estimatedFare,
    required this.finalFare,
    required this.distanceKm,
    required this.durationMinutes,
    required this.createdAt,
    this.driver,
    this.waitMinutes = 0,
    this.surgeMultiplier = 1.0,
  });

  final String id;
  final LocationPoint pickup;
  final LocationPoint dropoff;
  final VehicleClass vehicleClass;
  final RideStatus status;
  final double estimatedFare;
  final double? finalFare;
  final double distanceKm;
  final int durationMinutes;
  final DateTime createdAt;
  final Driver? driver;
  final int waitMinutes;
  final double surgeMultiplier;

  Ride copyWith({
    RideStatus? status,
    Driver? driver,
    double? finalFare,
    int? waitMinutes,
  }) {
    return Ride(
      id: id,
      pickup: pickup,
      dropoff: dropoff,
      vehicleClass: vehicleClass,
      status: status ?? this.status,
      estimatedFare: estimatedFare,
      finalFare: finalFare ?? this.finalFare,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      createdAt: createdAt,
      driver: driver ?? this.driver,
      waitMinutes: waitMinutes ?? this.waitMinutes,
      surgeMultiplier: surgeMultiplier,
    );
  }

  Ride transitionTo(
    RideStatus nextStatus, {
    Driver? driver,
    double? finalFare,
    int? waitMinutes,
  }) {
    final validatedStatus = status.transitionTo(nextStatus);

    return copyWith(
      status: validatedStatus,
      driver: driver,
      finalFare: finalFare,
      waitMinutes: waitMinutes,
    );
  }

  factory Ride.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String? ?? 'searching';
    final status = RideStatus.values.firstWhere(
      (value) => value.name == rawStatus,
      orElse: () => RideStatus.searching,
    );

    final rawClass = json['vehicle_class'] as String? ?? 'standard';
    final vehicleClass = VehicleClass.values.firstWhere(
      (value) => value.name == rawClass,
      orElse: () => VehicleClass.standard,
    );

    return Ride(
      id: json['id']?.toString() ?? '',
      pickup: LocationPoint(
        latitude: (json['pickup_latitude'] as num?)?.toDouble() ?? 47.3769,
        longitude: (json['pickup_longitude'] as num?)?.toDouble() ?? 8.5417,
        label: json['pickup_address'] as String? ?? 'Pickup',
      ),
      dropoff: LocationPoint(
        latitude: (json['dropoff_latitude'] as num?)?.toDouble() ?? 47.4581,
        longitude: (json['dropoff_longitude'] as num?)?.toDouble() ?? 8.5555,
        label: json['dropoff_address'] as String? ?? 'Dropoff',
      ),
      vehicleClass: vehicleClass,
      status: status,
      estimatedFare: (json['estimated_price'] as num?)?.toDouble() ?? 0,
      finalFare: (json['final_price'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

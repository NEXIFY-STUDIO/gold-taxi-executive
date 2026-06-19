import 'location_point.dart';
import 'vehicle_class.dart';

enum DriverStatus {
  offline,
  idle,
  busy,
  goingOffline;

  String get label {
    return switch (this) {
      DriverStatus.offline => 'Offline',
      DriverStatus.idle => 'Online',
      DriverStatus.busy => 'Busy',
      DriverStatus.goingOffline => 'Going offline',
    };
  }
}

class Driver {
  const Driver({
    required this.id,
    required this.name,
    required this.vehicleName,
    required this.plateNumber,
    required this.vehicleClass,
    required this.location,
    required this.heading,
    required this.rating,
    required this.status,
    required this.photoUrl,
  });

  final String id;
  final String name;
  final String vehicleName;
  final String plateNumber;
  final VehicleClass vehicleClass;
  final LocationPoint location;
  final double heading;
  final double rating;
  final DriverStatus status;
  final String photoUrl;

  Driver copyWith({
    LocationPoint? location,
    double? heading,
    DriverStatus? status,
  }) {
    return Driver(
      id: id,
      name: name,
      vehicleName: vehicleName,
      plateNumber: plateNumber,
      vehicleClass: vehicleClass,
      location: location ?? this.location,
      heading: heading ?? this.heading,
      rating: rating,
      status: status ?? this.status,
      photoUrl: photoUrl,
    );
  }

  factory Driver.fromJson(Map<String, dynamic> json) {
    final rawClass = json['vehicle_class'] as String? ?? 'standard';
    final vehicleClass = VehicleClass.values.firstWhere(
      (value) => value.name == rawClass,
      orElse: () => VehicleClass.standard,
    );

    final status = switch (json['status']?.toString()) {
      'offline' => DriverStatus.offline,
      'busy' => DriverStatus.busy,
      'goingOffline' => DriverStatus.goingOffline,
      'online' => DriverStatus.idle,
      _ => (json['is_busy'] == true) ? DriverStatus.busy : DriverStatus.idle,
    };

    return Driver(
      id: json['id']?.toString() ?? '',
      name: json['display_name'] as String? ?? 'Driver',
      vehicleName: json['vehicle_name'] as String? ?? 'Verified vehicle',
      plateNumber: json['plate_number'] as String? ?? 'N/A',
      vehicleClass: vehicleClass,
      location: LocationPoint(
        latitude: (json['latitude'] as num?)?.toDouble() ?? 47.3769,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 8.5417,
        label: 'Driver location',
      ),
      heading: (json['heading'] as num?)?.toDouble() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      status: status,
      photoUrl: json['photo_url'] as String? ?? '',
    );
  }
}

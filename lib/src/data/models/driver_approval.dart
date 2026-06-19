import 'vehicle_class.dart';

enum DriverApplicationVehicleClass {
  basic('Basic', VehicleClass.standard),
  premium('Premium', VehicleClass.comfort),
  executive('Executive', VehicleClass.premium);

  const DriverApplicationVehicleClass(this.label, this.driverVehicleClass);

  final String label;
  final VehicleClass driverVehicleClass;

  static DriverApplicationVehicleClass fromName(Object? value) {
    return DriverApplicationVehicleClass.values.firstWhere(
      (item) => item.name == value?.toString(),
      orElse: () => DriverApplicationVehicleClass.premium,
    );
  }
}

enum DriverApplicationStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const DriverApplicationStatus(this.label);

  final String label;

  static DriverApplicationStatus fromName(Object? value) {
    return DriverApplicationStatus.values.firstWhere(
      (item) => item.name == value?.toString(),
      orElse: () => DriverApplicationStatus.pending,
    );
  }
}

class DriverApplicationInput {
  const DriverApplicationInput({
    required this.fullName,
    required this.phone,
    required this.vehicleLabel,
    required this.licensePlate,
    required this.vehicleClass,
  });

  final String fullName;
  final String phone;
  final String vehicleLabel;
  final String licensePlate;
  final DriverApplicationVehicleClass vehicleClass;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'vehicleLabel': vehicleLabel.trim(),
      'licensePlate': licensePlate.trim().toUpperCase(),
      'vehicleClass': vehicleClass.name,
    };
  }
}

class DriverApplication {
  const DriverApplication({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.vehicleLabel,
    required this.licensePlate,
    required this.vehicleClass,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.rejectionReason,
  });

  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String vehicleLabel;
  final String licensePlate;
  final DriverApplicationVehicleClass vehicleClass;
  final DriverApplicationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? rejectionReason;

  factory DriverApplication.fromJson(Map<String, dynamic> json) {
    final createdAt = _readDateTime(json['createdAt']) ?? DateTime.now();
    return DriverApplication(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      vehicleLabel: json['vehicleLabel']?.toString() ?? '',
      licensePlate: json['licensePlate']?.toString() ?? '',
      vehicleClass: DriverApplicationVehicleClass.fromName(
        json['vehicleClass'],
      ),
      status: DriverApplicationStatus.fromName(json['status']),
      createdAt: createdAt,
      updatedAt: _readDateTime(json['updatedAt']) ?? createdAt,
      rejectionReason: json['rejectionReason']?.toString(),
    );
  }
}

class DriverApprovalInput {
  const DriverApprovalInput({
    required this.targetUid,
    required this.name,
    required this.phone,
    required this.vehicleLabel,
    required this.licensePlate,
    required this.vehicleClass,
  });

  final String targetUid;
  final String name;
  final String phone;
  final String vehicleLabel;
  final String licensePlate;
  final VehicleClass vehicleClass;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'targetUid': targetUid.trim(),
      'name': name.trim(),
      'phone': phone.trim(),
      'vehicleLabel': vehicleLabel.trim(),
      'licensePlate': licensePlate.trim().toUpperCase(),
      'vehicleClass': vehicleClass.name,
    };
  }
}

DateTime? _readDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

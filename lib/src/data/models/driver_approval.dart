import 'vehicle_class.dart';

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

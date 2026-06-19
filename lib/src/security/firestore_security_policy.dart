class FirestoreSecurityPolicy {
  static const List<String> userSelfEditableFields = [
    'displayName',
    'phoneNumber',
    'updatedAt',
  ];

  static const List<String> userCreateFields = [
    'uid',
    'role',
    'displayName',
    'phoneNumber',
    'createdAt',
    'updatedAt',
  ];

  static const List<String> rideServerOnlyFields = [
    'passengerId',
    'driverId',
    'vehicleId',
    'status',
    'pickup',
    'dropoff',
    'vehicleClass',
    'estimatedFare',
    'finalFare',
    'paymentStatus',
    'currency',
    'createdAt',
    'updatedAt',
  ];

  static const List<String> paymentServerOnlyFields = [
    'rideId',
    'userId',
    'driverId',
    'provider',
    'amount',
    'currency',
    'status',
    'providerRef',
    'createdAt',
    'updatedAt',
  ];

  static const bool ridesAreServerAuthoritative = true;
  static const bool paymentsAreServerAuthoritative = true;
}

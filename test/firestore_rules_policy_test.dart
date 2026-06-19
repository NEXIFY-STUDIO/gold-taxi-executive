import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/security/firestore_security_policy.dart';

void main() {
  test('Firestore security policy keeps rides and payments server-only', () {
    expect(FirestoreSecurityPolicy.ridesAreServerAuthoritative, isTrue);
    expect(FirestoreSecurityPolicy.paymentsAreServerAuthoritative, isTrue);

    expect(
      FirestoreSecurityPolicy.rideServerOnlyFields,
      containsAll([
        'passengerId',
        'driverId',
        'status',
        'estimatedFare',
        'finalFare',
        'paymentStatus',
      ]),
    );

    expect(
      FirestoreSecurityPolicy.paymentServerOnlyFields,
      containsAll([
        'rideId',
        'userId',
        'driverId',
        'provider',
        'amount',
        'status',
        'providerRef',
      ]),
    );
  });

  test('user profile edits stay limited to display fields only', () {
    expect(
      FirestoreSecurityPolicy.userSelfEditableFields,
      orderedEquals(['displayName', 'phoneNumber', 'updatedAt']),
    );
    expect(
      FirestoreSecurityPolicy.userCreateFields,
      orderedEquals([
        'uid',
        'role',
        'displayName',
        'phoneNumber',
        'createdAt',
        'updatedAt',
      ]),
    );
  });
}

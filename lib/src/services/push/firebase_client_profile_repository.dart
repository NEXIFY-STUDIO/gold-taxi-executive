import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/app_user_role.dart';
import 'client_profile_repository.dart';

class FirebaseClientProfileRepository implements ClientProfileRepository {
  FirebaseClientProfileRepository({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    this.region = 'europe-west6',
  })  : _auth = auth,
        _functions = functions;

  FirebaseAuth? _auth;
  FirebaseFunctions? _functions;
  final String region;
  AppUserRole _role = AppUserRole.passenger;

  FirebaseAuth get _clientAuth => _auth ??= FirebaseAuth.instance;

  FirebaseFunctions get _clientFunctions =>
      _functions ??= FirebaseFunctions.instanceFor(region: region);

  @override
  AppUserRole get userRole => _role;

  @override
  Future<void> bootstrapProfiles() async {
    await _ensureSignedIn();

    final response = await _clientFunctions
        .httpsCallable('bootstrapUserProfile')
        .call(<String, dynamic>{
      'displayName': 'GoldTaxi Passenger',
      'phoneNumber': '',
    });
    _role = AppUserRole.fromBackendValue(
      (response.data as Map<Object?, Object?>)['role'],
    );
  }

  @override
  Future<List<PushAudience>> availableAudiences() async => [
        PushAudience.passenger,
        if (_role.canAccessDriverTools) PushAudience.driver,
      ];

  @override
  Future<void> registerNotificationToken({
    required String token,
    required PushAudience audience,
  }) async {
    await _ensureSignedIn();
    if (audience == PushAudience.driver && !_role.canAccessDriverTools) {
      return;
    }
    await _clientFunctions
        .httpsCallable('registerDeviceToken')
        .call(<String, dynamic>{
      'token': token,
      'role': audience.name,
    });
  }

  Future<void> _ensureSignedIn() async {
    if (_clientAuth.currentUser != null) {
      return;
    }
    await _clientAuth.signInAnonymously();
  }
}

import 'package:cloud_functions/cloud_functions.dart';

import '../../models/app_user_role.dart';
import '../auth/auth_gateway.dart';
import '../auth/firebase_auth_gateway.dart';
import 'client_profile_repository.dart';

class FirebaseClientProfileRepository implements ClientProfileRepository {
  FirebaseClientProfileRepository({
    GoldTaxiAuthGateway? authGateway,
    FirebaseFunctions? functions,
    this.region = 'europe-west6',
  })  : _authGatewayOverride = authGateway,
        _functions = functions;

  final GoldTaxiAuthGateway? _authGatewayOverride;
  FirebaseFunctions? _functions;
  final String region;
  GoldTaxiAuthGateway? _authGateway;
  AppUserRole _role = AppUserRole.passenger;

  GoldTaxiAuthGateway get _clientAuthGateway =>
      _authGateway ??= _authGatewayOverride ??
          FirebaseAuthGateway(functions: _clientFunctions, region: region);

  FirebaseFunctions get _clientFunctions =>
      _functions ??= FirebaseFunctions.instanceFor(region: region);

  @override
  AppUserRole get userRole => _role;

  @override
  Future<void> bootstrapProfiles() async {
    final profile = await _clientAuthGateway.ensureSignedInProfile();
    _role = profile.role;
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
    await bootstrapProfiles();
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
}

import '../../models/app_user_role.dart';

enum PushAudience { passenger, driver }

abstract class ClientProfileRepository {
  Future<void> bootstrapProfiles();

  Future<List<PushAudience>> availableAudiences();

  AppUserRole get userRole;

  Future<void> registerNotificationToken({
    required String token,
    required PushAudience audience,
  });
}

class NoopClientProfileRepository implements ClientProfileRepository {
  const NoopClientProfileRepository();

  @override
  Future<void> bootstrapProfiles() async {}

  @override
  Future<List<PushAudience>> availableAudiences() async => [
        PushAudience.passenger,
      ];

  @override
  AppUserRole get userRole => AppUserRole.passenger;

  @override
  Future<void> registerNotificationToken({
    required String token,
    required PushAudience audience,
  }) async {}
}

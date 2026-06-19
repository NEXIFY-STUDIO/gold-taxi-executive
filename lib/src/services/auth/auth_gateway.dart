import '../../models/app_user_role.dart';

enum AuthProviderKind { guest, google }

class AuthSession {
  const AuthSession({
    required this.uid,
    required this.provider,
    this.displayName,
    this.email,
  });

  final String uid;
  final AuthProviderKind provider;
  final String? displayName;
  final String? email;

  bool get isGuest => provider == AuthProviderKind.guest;
  bool get isGoogle => provider == AuthProviderKind.google;
}

class AuthProfile {
  const AuthProfile({
    required this.session,
    required this.role,
  });

  final AuthSession session;
  final AppUserRole role;
}

abstract class GoldTaxiAuthGateway {
  bool get supportsGoogleSignIn;

  AuthProfile? get currentProfile;

  Future<AuthProfile> ensureSignedInProfile();

  Future<AuthProfile> signInWithGoogle();

  Future<AuthProfile> signOutToGuest();
}

class NoopGoldTaxiAuthGateway implements GoldTaxiAuthGateway {
  NoopGoldTaxiAuthGateway({
    AuthProfile? profile,
  }) : _profile = profile ??
            const AuthProfile(
              session: AuthSession(
                uid: 'mock-passenger',
                provider: AuthProviderKind.guest,
                displayName: 'GoldTaxi Guest',
              ),
              role: AppUserRole.passenger,
            );

  final AuthProfile _profile;

  @override
  bool get supportsGoogleSignIn => false;

  @override
  AuthProfile? get currentProfile => _profile;

  @override
  Future<AuthProfile> ensureSignedInProfile() async => _profile;

  @override
  Future<AuthProfile> signInWithGoogle() async => _profile;

  @override
  Future<AuthProfile> signOutToGuest() async => _profile;
}

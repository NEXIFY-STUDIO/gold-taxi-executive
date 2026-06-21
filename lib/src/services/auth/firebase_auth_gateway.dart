import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../models/app_user_role.dart';
import 'auth_gateway.dart';

class FirebaseAuthGateway implements GoldTaxiAuthGateway {
  FirebaseAuthGateway({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    this.region = 'europe-west6',
  })  : _authOverride = auth,
        _functionsOverride = functions;

  final FirebaseAuth? _authOverride;
  final FirebaseFunctions? _functionsOverride;
  final String region;

  FirebaseAuth? _auth;
  FirebaseFunctions? _functions;
  AuthProfile? _currentProfile;

  FirebaseAuth get _clientAuth =>
      _auth ??= _authOverride ?? FirebaseAuth.instance;

  FirebaseFunctions get _clientFunctions => _functions ??=
      _functionsOverride ?? FirebaseFunctions.instanceFor(region: region);

  @override
  bool get supportsGoogleSignIn => true;

  @override
  AuthProfile? get currentProfile => _currentProfile;

  @override
  Future<AuthProfile> ensureSignedInProfile() async {
    _ensureFirebaseReady();
    if (_clientAuth.currentUser == null) {
      await _clientAuth.signInAnonymously();
    }
    return _bootstrapCurrentUser();
  }

  @override
  Future<AuthProfile> signInWithGoogle() async {
    _ensureFirebaseReady();

    final currentUser = _clientAuth.currentUser;
    if (currentUser != null && currentUser.isAnonymous) {
      try {
        if (kIsWeb) {
          await currentUser.linkWithPopup(_googleProvider());
        } else {
          await currentUser.linkWithProvider(_googleProvider());
        }
        return _bootstrapCurrentUser();
      } on FirebaseAuthException catch (error) {
        if (!_shouldFallbackToProviderSignIn(error)) {
          rethrow;
        }
      }
    }

    if (kIsWeb) {
      await _clientAuth.signInWithPopup(_googleProvider());
    } else {
      await _clientAuth.signInWithProvider(_googleProvider());
    }
    return _bootstrapCurrentUser();
  }

  @override
  Future<AuthProfile> signOutToGuest() async {
    _ensureFirebaseReady();
    await _clientAuth.signOut();
    await _clientAuth.signInAnonymously();
    return _bootstrapCurrentUser();
  }

  void _ensureFirebaseReady() {
    if (Firebase.apps.isEmpty) {
      throw StateError(
        'Firebase is not initialized. Call initializeFirebaseServices(config) '
        'before authentication operations.',
      );
    }
  }

  GoogleAuthProvider _googleProvider() {
    return GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters(<String, String>{
        'prompt': 'select_account',
      });
  }

  bool _shouldFallbackToProviderSignIn(FirebaseAuthException error) {
    return switch (error.code) {
      'account-exists-with-different-credential' ||
      'credential-already-in-use' ||
      'email-already-in-use' ||
      'provider-already-linked' ||
      'operation-not-supported-in-this-environment' =>
        true,
      _ => false,
    };
  }

  Future<AuthProfile> _bootstrapCurrentUser() async {
    final user = _clientAuth.currentUser;
    if (user == null) {
      throw StateError('Firebase auth user is not available.');
    }

    final response = await _clientFunctions
        .httpsCallable('bootstrapUserProfile')
        .call(<String, dynamic>{
      'displayName': _displayNameFor(user),
      'phoneNumber': user.phoneNumber ?? '',
    });
    final role = AppUserRole.fromBackendValue(
      (response.data as Map<Object?, Object?>)['role'],
    );
    final profile = AuthProfile(
      session: AuthSession(
        uid: user.uid,
        provider:
            user.isAnonymous ? AuthProviderKind.guest : AuthProviderKind.google,
        displayName: _displayNameFor(user),
        email: user.email,
      ),
      role: role,
    );
    _currentProfile = profile;
    return profile;
  }

  String _displayNameFor(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }
    return 'GoldTaxi Passenger';
  }
}

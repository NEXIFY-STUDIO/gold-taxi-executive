import 'package:flutter/material.dart';
import 'dart:async';

import '../../config/app_config.dart';
import '../../data/repositories/firebase_ride_repository.dart';
import '../../data/repositories/mock_ride_repository.dart';
import '../../data/repositories/ride_repository.dart';
import '../../models/app_user_role.dart';
import '../../services/auth/auth_gateway.dart';
import '../../services/auth/firebase_auth_gateway.dart';
import '../../services/push/client_profile_repository.dart';
import '../../services/push/firebase_client_profile_repository.dart';
import '../../services/push/firebase_push_messaging_client.dart';
import '../../services/push/push_notification_service.dart';
import '../../state/app_state.dart';
import 'app_shell.dart';

class AppModule extends StatefulWidget {
  const AppModule({
    super.key,
    required this.config,
    required this.scaffoldMessengerKey,
  });

  final AppConfig config;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  @override
  State<AppModule> createState() => _AppModuleState();
}

class _AppModuleState extends State<AppModule> {
  RideRepository? _repository;
  AppState? _state;
  PushNotificationService? _pushService;
  Object? _initializationError;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeModule());
  }

  Future<void> _initializeModule() async {
    try {
      final authGateway = widget.config.useFirebaseRuntime
          ? FirebaseAuthGateway()
          : NoopGoldTaxiAuthGateway();
      final repository = widget.config.useFirebaseRuntime
          ? FirebaseRideRepository(authGateway: authGateway)
          : MockRideRepository();
      final role = await _resolveUserRole(repository);

      final pushService = PushNotificationService(
        messagingClient: widget.config.useFirebaseRuntime
            ? FirebasePushMessagingClient()
            : const NoopPushMessagingClient(),
        profileRepository: widget.config.useFirebaseRuntime
            ? FirebaseClientProfileRepository(authGateway: authGateway)
            : const NoopClientProfileRepository(),
        scaffoldMessengerKey: widget.scaffoldMessengerKey,
        onOpenNotification: (_) {},
        vapidKey: widget.config.fcmWebVapidKey.isEmpty
            ? null
            : widget.config.fcmWebVapidKey,
      );
      final state = AppState(
        repository: repository,
        config: widget.config,
        userRole: role,
        authGateway: authGateway,
        authProfile: repository is FirebaseRideRepository
            ? repository.authProfile
            : authGateway.currentProfile,
        refreshUserRole: repository is FirebaseRideRepository
            ? repository.refreshUserProfile
            : null,
        onAuthChanged: pushService.refreshProfileAndToken,
      );
      await state.start();
      pushService.setOpenNotificationHandler(state.setShellIndex);
      await pushService.initialize();

      if (!mounted) {
        pushService.dispose();
        state.dispose();
        repository.dispose();
        return;
      }

      setState(() {
        _repository = repository;
        _state = state;
        _pushService = pushService;
        _initializationError = null;
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializationError = error;
        _isInitializing = false;
      });
    }
  }

  Future<AppUserRole> _resolveUserRole(RideRepository repository) async {
    if (repository is! FirebaseRideRepository) {
      return AppUserRole.passenger;
    }
    await repository.initialize();
    return repository.userRole;
  }

  void _retryInitialization() {
    _pushService?.dispose();
    _state?.dispose();
    _repository?.dispose();
    setState(() {
      _pushService = null;
      _state = null;
      _repository = null;
      _initializationError = null;
      _isInitializing = true;
    });
    unawaited(_initializeModule());
  }

  @override
  void dispose() {
    _pushService?.dispose();
    _state?.dispose();
    _repository?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'GoldTaxi app startup failed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _initializationError.toString(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _retryInitialization,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isInitializing || _state == null || _pushService == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return PushScope(
      state: _pushService!,
      child: AppStateScope(
        state: _state!,
        child: const AppShell(),
      ),
    );
  }
}

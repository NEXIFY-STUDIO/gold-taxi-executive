import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/models/app_user_role.dart';
import 'package:goldtaxi_bolt_v2_5/src/services/push/client_profile_repository.dart';
import 'package:goldtaxi_bolt_v2_5/src/services/push/push_notification_service.dart';

void main() {
  test('initializes, registers a token and handles tap routing', () async {
    final client = FakePushMessagingClient(
      supported: true,
      token: 'token-123',
      permissionOnRequest: PushPermissionState.granted,
    );
    final repository = FakeClientProfileRepository();
    final tappedShells = <int>[];
    final service = PushNotificationService(
      messagingClient: client,
      profileRepository: repository,
      scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
      onOpenNotification: tappedShells.add,
      vapidKey: 'test-vapid',
    );

    addTearDown(() {
      service.dispose();
      client.dispose();
    });

    await service.initialize();

    expect(service.permissionState, PushPermissionState.granted);
    expect(service.token, 'token-123');
    expect(repository.bootstrapped, isTrue);
    expect(repository.registeredAudiences, [PushAudience.passenger]);

    client.pushOpenedMessage(
      const PushMessage(
        title: 'Driver accepted',
        body: 'Your driver is on the way.',
        data: {'shellIndex': '0'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(tappedShells, [0]);
    expect(service.lastMessage, isNotNull);
  });

  test('driver role registers both passenger and driver audiences', () async {
    final client = FakePushMessagingClient(
      supported: true,
      token: 'token-456',
    );
    final repository = FakeClientProfileRepository(
      audiences: const [
        PushAudience.passenger,
        PushAudience.driver,
      ],
      userRole: AppUserRole.driver,
    );
    final service = PushNotificationService(
      messagingClient: client,
      profileRepository: repository,
      scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
      onOpenNotification: (_) {},
      vapidKey: 'test-vapid',
    );

    addTearDown(() {
      service.dispose();
      client.dispose();
    });

    await service.initialize();

    expect(repository.registeredAudiences, [
      PushAudience.passenger,
      PushAudience.driver,
    ]);
  });

  test('keeps unsupported state when the platform is unavailable', () async {
    final service = PushNotificationService(
      messagingClient: FakePushMessagingClient(supported: false),
      profileRepository: FakeClientProfileRepository(),
      scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
      onOpenNotification: (_) {},
    );

    addTearDown(service.dispose);

    await service.initialize();

    expect(service.permissionState, PushPermissionState.unsupported);
  });
}

class FakePushMessagingClient implements PushMessagingClient {
  FakePushMessagingClient({
    required this.supported,
    this.token,
    this.permissionOnRequest = PushPermissionState.notRequested,
  });

  final bool supported;
  final String? token;
  final PushPermissionState permissionOnRequest;

  final _tokenRefresh = StreamController<String>.broadcast();
  final _messages = StreamController<PushMessage>.broadcast();
  final _openedMessages = StreamController<PushMessage>.broadcast();

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<PushPermissionState> requestPermission() async => permissionOnRequest;

  @override
  Future<String?> getToken({String? vapidKey}) async => token;

  @override
  Stream<String> get onTokenRefresh => _tokenRefresh.stream;

  @override
  Stream<PushMessage> get onMessage => _messages.stream;

  @override
  Stream<PushMessage> get onMessageOpenedApp => _openedMessages.stream;

  @override
  Future<PushMessage?> getInitialMessage() async => null;

  void pushOpenedMessage(PushMessage message) {
    _openedMessages.add(message);
  }

  void dispose() {
    _tokenRefresh.close();
    _messages.close();
    _openedMessages.close();
  }
}

class FakeClientProfileRepository implements ClientProfileRepository {
  FakeClientProfileRepository({
    this.audiences = const [PushAudience.passenger],
    this.userRole = AppUserRole.passenger,
  });

  bool bootstrapped = false;
  final registeredAudiences = <PushAudience>[];
  final List<PushAudience> audiences;

  @override
  final AppUserRole userRole;

  @override
  Future<void> bootstrapProfiles() async {
    bootstrapped = true;
  }

  @override
  Future<List<PushAudience>> availableAudiences() async => audiences;

  @override
  Future<void> registerNotificationToken({
    required String token,
    required PushAudience audience,
  }) async {
    registeredAudiences.add(audience);
  }
}

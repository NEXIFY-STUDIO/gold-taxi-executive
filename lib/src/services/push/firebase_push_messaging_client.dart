import 'package:firebase_messaging/firebase_messaging.dart';

import 'push_notification_service.dart';

class FirebasePushMessagingClient implements PushMessagingClient {
  FirebasePushMessagingClient({FirebaseMessaging? messaging})
      : _messaging = messaging;

  FirebaseMessaging? _messaging;

  FirebaseMessaging get _client => _messaging ??= FirebaseMessaging.instance;

  @override
  Future<bool> isSupported() => _client.isSupported();

  @override
  Future<PushPermissionState> requestPermission() async {
    final settings = await _client.requestPermission();
    return _mapPermission(settings.authorizationStatus);
  }

  @override
  Future<String?> getToken({String? vapidKey}) async {
    if (vapidKey == null || vapidKey.isEmpty) {
      return _client.getToken();
    }
    return _client.getToken(vapidKey: vapidKey);
  }

  @override
  Stream<String> get onTokenRefresh => _client.onTokenRefresh;

  @override
  Stream<PushMessage> get onMessage =>
      FirebaseMessaging.onMessage.map(_mapMessage);

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(_mapMessage);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final message = await _client.getInitialMessage();
    if (message == null) return null;
    return _mapMessage(message);
  }

  PushPermissionState _mapPermission(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional =>
        PushPermissionState.granted,
      AuthorizationStatus.denied => PushPermissionState.denied,
      AuthorizationStatus.notDetermined => PushPermissionState.notRequested,
    };
  }

  PushMessage _mapMessage(RemoteMessage message) {
    final data = <String, String>{};
    message.data.forEach((key, value) {
      data[key] = value.toString();
    });

    return PushMessage(
      title: message.notification?.title ?? data['title'],
      body: message.notification?.body ?? data['body'],
      data: data,
    );
  }
}

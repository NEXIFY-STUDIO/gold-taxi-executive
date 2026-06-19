import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'client_profile_repository.dart';

enum PushPermissionState { unsupported, notRequested, granted, denied }

class PushMessage {
  const PushMessage({
    required this.data,
    this.title,
    this.body,
  });

  final String? title;
  final String? body;
  final Map<String, String> data;

  int get shellIndex => int.tryParse(data['shellIndex'] ?? '') ?? 0;
}

abstract class PushMessagingClient {
  Future<bool> isSupported();

  Future<PushPermissionState> requestPermission();

  Future<String?> getToken({String? vapidKey});

  Stream<String> get onTokenRefresh;

  Stream<PushMessage> get onMessage;

  Stream<PushMessage> get onMessageOpenedApp;

  Future<PushMessage?> getInitialMessage();
}

class NoopPushMessagingClient implements PushMessagingClient {
  const NoopPushMessagingClient();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<PushPermissionState> requestPermission() async =>
      PushPermissionState.unsupported;

  @override
  Future<String?> getToken({String? vapidKey}) async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream<String>.empty();

  @override
  Stream<PushMessage> get onMessage => const Stream<PushMessage>.empty();

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      const Stream<PushMessage>.empty();

  @override
  Future<PushMessage?> getInitialMessage() async => null;
}

class PushNotificationService extends ChangeNotifier {
  PushNotificationService({
    required PushMessagingClient messagingClient,
    required ClientProfileRepository profileRepository,
    required GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
    required void Function(int shellIndex) onOpenNotification,
    this.vapidKey,
  })  : _messagingClient = messagingClient,
        _profileRepository = profileRepository,
        _scaffoldMessengerKey = scaffoldMessengerKey,
        _onOpenNotification = onOpenNotification;

  final PushMessagingClient _messagingClient;
  final ClientProfileRepository _profileRepository;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey;
  final void Function(int shellIndex) _onOpenNotification;
  final String? vapidKey;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<PushMessage>? _messageSub;
  StreamSubscription<PushMessage>? _openedSub;
  bool _initialized = false;

  PushPermissionState _permissionState = PushPermissionState.notRequested;
  PushPermissionState get permissionState => _permissionState;

  String? _token;
  String? get token => _token;

  PushMessage? _lastMessage;
  PushMessage? get lastMessage => _lastMessage;

  String? _lastError;
  String? get lastError => _lastError;
  List<PushAudience> _audiences = const [PushAudience.passenger];

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final supported = await _messagingClient.isSupported();
      if (!supported) {
        _setPermissionState(PushPermissionState.unsupported);
        return;
      }

      await _profileRepository.bootstrapProfiles();
      _audiences = await _profileRepository.availableAudiences();
      await _wireStreams();
      await _syncTokenIfPossible();
    } catch (error) {
      _lastError = error.toString();
      _setPermissionState(PushPermissionState.unsupported);
    }
  }

  Future<void> requestPermission() async {
    if (_permissionState == PushPermissionState.unsupported) return;
    final result = await _messagingClient.requestPermission();
    _setPermissionState(result);
    if (result == PushPermissionState.granted) {
      await _syncTokenIfPossible();
    }
  }

  Future<void> _syncTokenIfPossible() async {
    try {
      final token = await _messagingClient.getToken(vapidKey: vapidKey);
      if (token == null || token.isEmpty) {
        if (kIsWeb && (vapidKey == null || vapidKey!.isEmpty)) {
          _lastError = 'Web push VAPID key is missing.';
          _setPermissionState(PushPermissionState.unsupported);
        }
        notifyListeners();
        return;
      }

      _token = token;
      _lastError = null;
      _setPermissionState(PushPermissionState.granted);
      await _registerTokenForAudiences(token);
      notifyListeners();
    } catch (error) {
      _lastError = error.toString();
      notifyListeners();
    }
  }

  Future<void> _wireStreams() async {
    _tokenRefreshSub?.cancel();
    _messageSub?.cancel();
    _openedSub?.cancel();

    _tokenRefreshSub = _messagingClient.onTokenRefresh.listen((token) async {
      _token = token;
      await _registerTokenForAudiences(token);
      notifyListeners();
    });

    _messageSub = _messagingClient.onMessage.listen(_handleMessage);
    _openedSub =
        _messagingClient.onMessageOpenedApp.listen(_handleOpenedMessage);

    final initialMessage = await _messagingClient.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
    }
  }

  void _handleMessage(PushMessage message) {
    _lastMessage = message;
    _showSnack(
      message.title ?? 'GoldTaxi notification',
      message.body ?? '',
    );
    notifyListeners();
  }

  void _handleOpenedMessage(PushMessage message) {
    _lastMessage = message;
    _onOpenNotification(message.shellIndex);
    notifyListeners();
  }

  void _showSnack(String title, String body) {
    final messenger = _scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(body.isEmpty ? title : '$title · $body'),
      ),
    );
  }

  void _setPermissionState(PushPermissionState value) {
    if (_permissionState == value) return;
    _permissionState = value;
    notifyListeners();
  }

  Future<void> _registerTokenForAudiences(String token) async {
    for (final audience in _audiences) {
      await _profileRepository.registerNotificationToken(
        token: token,
        audience: audience,
      );
    }
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    _messageSub?.cancel();
    _openedSub?.cancel();
    super.dispose();
  }
}

class PushScope extends InheritedNotifier<PushNotificationService> {
  const PushScope({
    super.key,
    required PushNotificationService state,
    required super.child,
  }) : super(notifier: state);

  static PushNotificationService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PushScope>();
    assert(scope != null, 'PushScope not found.');
    return scope!.notifier!;
  }
}

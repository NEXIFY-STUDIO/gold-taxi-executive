import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../config/app_config.dart';

bool _servicesInitialized = false;

Future<void> initializeFirebaseServices(AppConfig config) async {
  if (!config.useFirebaseRuntime) {
    return;
  }

  if (_servicesInitialized) {
    return;
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  if (!kIsWeb) {
    _servicesInitialized = true;
    return;
  }

  final webProvider = _resolveWebAppCheckProvider(config);
  if (webProvider == null) {
    throw StateError(
      'Missing FIREBASE_WEB_APP_CHECK_SITE_KEY or FIREBASE_APP_CHECK_DEBUG_TOKEN. '
      'Set one of these in environment before running Firebase web mode.',
    );
  }

  await FirebaseAppCheck.instance.activate(
    webProvider: webProvider,
  );
  await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

  _servicesInitialized = true;
}

WebProvider? _resolveWebAppCheckProvider(AppConfig config) {
  if (config.webAppCheckDebugToken.isNotEmpty) {
    return WebDebugProvider(
      debugToken: config.webAppCheckDebugToken,
    );
  }

  if (config.webAppCheckSiteKey.isNotEmpty) {
    return ReCaptchaV3Provider(config.webAppCheckSiteKey);
  }

  return null;
}

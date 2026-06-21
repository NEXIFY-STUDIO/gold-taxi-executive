import 'package:flutter/material.dart';

import 'src/app/gold_taxi_app.dart';
import 'src/config/app_config.dart';
import 'src/services/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  await initializeFirebaseServices(config);
  runApp(GoldTaxiApp(config: config));
}

import 'package:flutter/material.dart';

import 'src/app/gold_taxi_app.dart';
import 'src/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(GoldTaxiApp(config: AppConfig.fromEnvironment()));
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goldtaxi_bolt_v2_5/src/config/app_config.dart';
import 'package:goldtaxi_bolt_v2_5/src/ui/screens/app_shell_loader.dart';

void main() {
  testWidgets('loads the /app shell through the deferred loader',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/app',
        routes: {
          '/app': (_) => AppShellLoader(
                config: const AppConfig(),
                scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
              ),
        },
      ),
    );

    expect(find.text('Loading the app shell'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Book your ride'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

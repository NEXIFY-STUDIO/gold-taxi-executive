import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:goldtaxi_bolt_v2_5/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('landing, booking shell and bottom tabs render end to end', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('GoldTaxi'), findsWidgets);
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Book your ride'), findsOneWidget);
    expect(find.text('Passenger'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('Ops'), findsOneWidget);

    await tester.tap(find.text('Driver'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Driver shift'), findsOneWidget);
    expect(find.text('Go online'), findsOneWidget);

    await tester.tap(find.text('Ops'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Live operations'), findsOneWidget);
    expect(find.text('Ride control'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saff_app/config/environment_config.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('shows the four tabs and switches between them', (tester) async {
    await pumpApp(tester, config: devConfig());
    for (final label in ['Today', 'Chat', 'Learn', 'Stats']) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('Chat').last);
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);
    await tester.tap(find.text('Stats').last);
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('Today says the real project is used without emulators', (
    tester,
  ) async {
    await pumpApp(tester, config: devConfig());
    expect(
      find.text('This build uses the real Firebase project.'),
      findsOneWidget,
    );
  });

  testWidgets('Today shows which emulators are reachable', (tester) async {
    await pumpApp(
      tester,
      config: devConfig(emulators: true),
      probe: FakeProbe({EmulatorPorts.auth}),
    );
    expect(find.text('Reachable'), findsOneWidget);
    expect(find.text('Not reachable'), findsNWidgets(3));
  });

  testWidgets('Settings has the crash trigger in dev only', (tester) async {
    final router = await pumpApp(tester, config: devConfig());
    router.go('/today/settings');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trigger-test-crash')), findsOneWidget);
  });

  testWidgets('Settings has no crash trigger in prod', (tester) async {
    final router = await pumpApp(tester, config: prodConfig());
    router.go('/today/settings');
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    expect(find.byKey(const ValueKey('trigger-test-crash')), findsNothing);
  });

  testWidgets('tapping the trigger throws a StateError', (tester) async {
    final router = await pumpApp(tester, config: devConfig());
    router.go('/today/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trigger-test-crash')));
    final error = tester.takeException();
    expect(error, isA<StateError>());
  });
}

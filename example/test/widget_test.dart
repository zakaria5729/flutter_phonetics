/// Author: Zakaria Hossain
/// Description: Widget tests for the example demo application.
library;

import 'package:flutter/material.dart';
import 'package:flutter_phonetics_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settle(WidgetTester tester, bool Function() isDone) async {
  for (var i = 0; i < 200 && !isDone(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
}

Future<void> showTallScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the search box shows variants from the background isolate', (
    tester,
  ) async {
    await showTallScreen(tester);
    await tester.pumpWidget(const PhoneticsDemoApp());
    await settle(tester, () => find.text('মাশুদ').evaluate().isNotEmpty);

    expect(find.text('isolate'), findsOneWidget);
    expect(find.text('মাশুদ'), findsWidgets);
    expect(find.text('95%'), findsWidgets);
    expect(find.text('মাসূদ'), findsWidgets);
    expect(find.text('97%'), findsWidgets);
  });

  testWidgets('Cancel stops the heavy job running on its own instance', (
    tester,
  ) async {
    await showTallScreen(tester);
    await tester.pumpWidget(const PhoneticsDemoApp());
    await settle(tester, () => find.text('মাশুদ').evaluate().isNotEmpty);

    await tester.tap(find.text('Stress test'));
    await settle(tester, () => find.text('Cancel').evaluate().isNotEmpty);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await settle(
      tester,
      () => find.textContaining('Cancelled after').evaluate().isNotEmpty,
    );

    expect(find.textContaining('Cancelled after'), findsOneWidget);
    expect(find.text('Stress test'), findsOneWidget);
  });

  testWidgets('three calls at once: cancelPrevious keeps only the last', (
    tester,
  ) async {
    await showTallScreen(tester);
    await tester.pumpWidget(const PhoneticsDemoApp());

    await tester.tap(find.text('Run 3 calls'));
    await settle(
      tester,
      () => find.textContaining('Call 3:').evaluate().isNotEmpty,
    );

    expect(find.textContaining('Call 1: cancelled'), findsOneWidget);
    expect(find.textContaining('Call 2: cancelled'), findsOneWidget);
    expect(find.textContaining('Call 3: done'), findsOneWidget);
  });

  testWidgets('three calls at once: queue finishes all of them', (
    tester,
  ) async {
    await showTallScreen(tester);
    await tester.pumpWidget(const PhoneticsDemoApp());

    await tester.tap(find.text('queue'));
    await tester.pump();
    await tester.tap(find.text('Run 3 calls'));
    await settle(
      tester,
      () => find.textContaining('Call 3:').evaluate().isNotEmpty,
    );

    expect(find.textContaining('done in'), findsNWidgets(3));
    expect(find.textContaining('cancelled'), findsNothing);
  });

  testWidgets('the switch changes the shared instance mode', (tester) async {
    await showTallScreen(tester);
    await tester.pumpWidget(const PhoneticsDemoApp());
    await settle(tester, () => find.text('মাশুদ').evaluate().isNotEmpty);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(
      find.byWidgetPredicate((widget) => widget is Switch && widget.value),
      findsOneWidget,
    );
  });

  testWidgets('the English switch searches with the English module', (
    tester,
  ) async {
    await showTallScreen(tester);
    await tester.pumpWidget(const PhoneticsDemoApp());
    await settle(tester, () => find.text('মাশুদ').evaluate().isNotEmpty);

    await tester.tap(find.text('English'));
    await settle(tester, () => find.text('Filip').evaluate().isNotEmpty);

    expect(find.text('Philip'), findsWidgets);
    expect(find.text('Filip'), findsWidgets);
    expect(find.text('মাশুদ'), findsNothing);
  });
}

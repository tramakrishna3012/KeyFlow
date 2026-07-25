import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keyflow_app/main.dart';

void main() {
  testWidgets('KeyFlowApp renders without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KeyFlowApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Bottom navigation shows all 5 tabs', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KeyFlowApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Translate'), findsOneWidget);
    expect(find.text('Emoji'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}

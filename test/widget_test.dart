// DDE-Mart provider app — smoke test (original).

import 'package:dde_provider/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots to provider sign-in offline', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DdeProviderApp()));
    await tester.pumpAndSettle();

    expect(find.text('Provider sign in'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentabilidad_flete/shared/widgets/feedback_link.dart';

void main() {
  testWidgets('hides feedback when WhatsApp number is empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FeedbackLink(phoneNumber: '')),
    ));

    expect(find.text('¿Algo no cierra? Contanos'), findsNothing);
  });

  testWidgets('shows feedback link for a digits-only WhatsApp number',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FeedbackLink(phoneNumber: '5493515550000')),
    ));

    expect(find.text('¿Algo no cierra? Contanos'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_match_app/main.dart';
import 'package:travel_match_app/service/api_service.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    final api = ApiService(baseUrl: "http://localhost:3000");

    await tester.pumpWidget(
      MaterialApp(
        home: Swipetrip(api: api),
      ),
    );

    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}

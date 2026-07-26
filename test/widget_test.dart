import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:engelsizclub/main.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://qycrkqwqrysypvqaipqn.supabase.co',
      anonKey: 'sb_publishable_N7UfnXDF97YsuDTsFTq9zQ_lhnNtMgF',
    );
  });

  testWidgets('Auth splash shows EngelsizClub', (WidgetTester tester) async {
    await tester.pumpWidget(const MetoCareApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('EngelsizClub'), findsWidgets);
    expect(find.text('Başlayalım'), findsOneWidget);
  });
}

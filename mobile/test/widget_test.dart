import 'package:flutter_test/flutter_test.dart';

import 'package:efpic_live/main.dart';

void main() {
  testWidgets('Home screen shows app title', (WidgetTester tester) async {
    await tester.pumpWidget(const EfpicLiveApp());
    await tester.pumpAndSettle();

    expect(find.text('EFPIC LIVE'), findsOneWidget);
    expect(find.text('Nav galeriju'), findsOneWidget);
  });
}

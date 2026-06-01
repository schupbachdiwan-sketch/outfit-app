import 'package:flutter_test/flutter_test.dart';
import 'package:outfit_app/app.dart';

void main() {
  testWidgets('App launches and shows bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const OutfitApp());
    expect(find.text('衣柜'), findsOneWidget);
    expect(find.text('灵感'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}

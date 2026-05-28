import 'package:flutter_test/flutter_test.dart';
import 'package:outfit_app/app.dart';

void main() {
  testWidgets('App launches and shows welcome text', (WidgetTester tester) async {
    await tester.pumpWidget(const OutfitApp());
    expect(find.text('欢迎使用穿搭助手'), findsOneWidget);
  });
}

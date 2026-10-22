import 'package:flutter_test/flutter_test.dart';
import 'package:tranminhcuong_nhomhhcc/main.dart';

void main() {
  testWidgets('App renders login screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChildPhoneManagerApp());
    expect(find.text('Quản Lý Điện Thoại Trẻ Em'), findsOneWidget);
  });
}

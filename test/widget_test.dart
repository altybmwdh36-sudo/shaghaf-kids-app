import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shaghaf_kids_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('يعرض دخولاً محلياً دون طلب الهاتف أو البريد أو رمز تحقق', (tester) async {
    await tester.pumpWidget(const ShaghafApp());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('✦ شَغَف ✦'), findsOneWidget);
    expect(find.text('اسم المشترك'), findsOneWidget);
    expect(find.text('دخول مجاني'), findsOneWidget);
    expect(find.text('اختر طريقة استلام رمز التحقق'), findsNothing);
    expect(find.text('رمز التحقق'), findsNothing);
  });
}

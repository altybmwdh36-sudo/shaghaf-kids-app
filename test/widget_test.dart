import 'package:flutter_test/flutter_test.dart';
import 'package:shaghaf_kids_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('يعرض شاشة التسجيل ويتطلب التحقق قبل دخول التطبيق', (tester) async {
    await tester.pumpWidget(const ShaghafApp());
    await tester.pumpAndSettle();
    expect(find.text('✦ شَغَف ✦'), findsOneWidget);
    expect(find.text('اسم المشترك'), findsOneWidget);
    expect(find.text('اختر طريقة استلام رمز التحقق'), findsOneWidget);
    expect(find.textContaining('أهلاً زائر'), findsNothing);
  });
}

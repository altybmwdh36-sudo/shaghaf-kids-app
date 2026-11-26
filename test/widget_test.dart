import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shaghaf_kids_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('يفتح التطبيق مباشرة في وضع الزائر دون رمز تحقق', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ShaghafApp());
    await tester.pumpAndSettle();
    expect(find.text('✦ شَغَف ✦'), findsOneWidget);
    expect(find.textContaining('أهلاً زائر'), findsOneWidget);
    expect(find.text('إرسال رمز التحقق'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configured = supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;
  if (configured) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(ShaghafApp(backendConfigured: configured));
}

class ShaghafApp extends StatelessWidget {
  const ShaghafApp({super.key, required this.backendConfigured});
  final bool backendConfigured;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'شَغَف',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5B49)),
      scaffoldBackgroundColor: const Color(0xFFF5F8F6),
      fontFamily: 'Roboto',
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: backendConfigured ? const AuthGate() : const SetupRequiredScreen(),
    ),
  );
}

class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.auto_stories_rounded, size: 64, color: Color(0xFF0B5B49)),
        SizedBox(height: 16),
        Text('شَغَف', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Text('يلزم إكمال إعداد الاتصال الآمن بالخادم قبل تسجيل الدخول. لم يتم إنشاء حساب تجريبي أو تجاوز التحقق.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
      ]),
    )),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snapshot) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return const SignInScreen();
      return const ShaghafHome();
    },
  );
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _useEmail = true;
  bool _busy = false;
  String? _message;

  @override
  void dispose() { _email.dispose(); _phone.dispose(); super.dispose(); }

  Future<void> _sendCode() async {
    final value = (_useEmail ? _email.text : _phone.text).trim();
    if (value.isEmpty) { setState(() => _message = 'أدخل البريد الإلكتروني أو رقم الهاتف أولاً.'); return; }
    setState(() { _busy = true; _message = null; });
    try {
      if (_useEmail) {
        await Supabase.instance.client.auth.signInWithOtp(email: value);
      } else {
        await Supabase.instance.client.auth.signInWithOtp(phone: value);
      }
      if (mounted) setState(() => _message = 'تم طلب رمز التحقق. افحص بريدك أو رسائل هاتفك ثم أدخل الرمز في شاشة التحقق.');
      if (mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtpScreen(destination: value, isEmail: _useEmail)));
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _message = 'تعذر إرسال الرمز: ${e.message}');
    } catch (_) {
      if (mounted) setState(() => _message = 'تعذر الاتصال بالخادم. تحقق من إعدادات Supabase والإنترنت.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.auto_stories_rounded, size: 58, color: Color(0xFF0B5B49)),
        const SizedBox(height: 10),
        const Text('منصة شَغَف', textAlign: TextAlign.center, style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
        const Text('تعلم نافع، علوم، اختراعات، وتحفيز على الدراسة', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        SegmentedButton<bool>(segments: const [
          ButtonSegment(value: true, label: Text('البريد الإلكتروني'), icon: Icon(Icons.email_outlined)),
          ButtonSegment(value: false, label: Text('رسالة SMS'), icon: Icon(Icons.sms_outlined)),
        ], selected: {_useEmail}, onSelectionChanged: (s) => setState(() { _useEmail = s.first; _message = null; })),
        const SizedBox(height: 16),
        if (_useEmail) TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()))
        else TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف مع مفتاح الدولة', hintText: '+967…', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _sendCode, child: Text(_busy ? 'جارٍ إرسال الرمز…' : 'إرسال رمز التحقق')),
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_message!, textAlign: TextAlign.center)),
        const SizedBox(height: 8),
        const Text('لا يتم إنشاء عضوية أو فتح المحتوى إلا بعد التحقق من الرمز.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]))),
    )))),
  );
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.destination, required this.isEmail});
  final String destination;
  final bool isEmail;
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() { _code.dispose(); super.dispose(); }
  Future<void> _verify() async {
    if (_code.text.trim().length < 4) { setState(() => _error = 'أدخل رمز التحقق الذي وصلك.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: widget.isEmail ? OtpType.email : OtpType.sms,
        email: widget.isEmail ? widget.destination : null,
        phone: widget.isEmail ? null : widget.destination,
        token: _code.text.trim(),
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) { if (mounted) setState(() => _error = e.message); }
    catch (_) { if (mounted) setState(() => _error = 'تعذر التحقق. حاول مجدداً.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('التحقق من العضوية')), body: Padding(
    padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('أدخل الرمز المرسل إلى ${widget.destination}', textAlign: TextAlign.center),
      const SizedBox(height: 18),
      TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(labelText: 'رمز التحقق', border: OutlineInputBorder())),
      FilledButton(onPressed: _busy ? null : _verify, child: Text(_busy ? 'جارٍ التحقق…' : 'تأكيد الرمز')),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
    ]),
  ));
}

class ShaghafHome extends StatefulWidget {
  const ShaghafHome({super.key});
  @override
  State<ShaghafHome> createState() => _ShaghafHomeState();
}

class _ShaghafHomeState extends State<ShaghafHome> {
  int _tab = 0;
  String _category = 'الكل';
  final _search = TextEditingController();
  static const categories = ['الكل','تعليم وعلوم','تحفيز دراسي','اختراعات','الفضاء والكون','القرآن والقيم','قصص ومعرفة','فكاهة هادفة'];
  static const resources = [
    ('تعليم وعلوم','علوم ناسا للأطفال','مواد علمية وفضائية من مكتبة ناسا','https://images.nasa.gov/'),
    ('تحفيز دراسي','التعلم وتنمية المهارات','مصادر تعلم وأنشطة تعليمية من خان أكاديمي','https://www.khanacademy.org/'),
    ('اختراعات','الابتكار والتقنية','مواد تعليمية عن العلوم والهندسة والابتكار','https://www.sciencebuddies.org/'),
    ('الفضاء والكون','استكشف الفضاء','صور ومواد علمية من وكالة ناسا','https://science.nasa.gov/'),
    ('القرآن والقيم','القرآن الكريم','مصدر للاستماع والقراءة والتعلم','https://quran.com/'),
    ('قصص ومعرفة','مكتبة المعرفة','مواد معرفية مفتوحة من أرشيف الإنترنت','https://archive.org/'),
    ('فكاهة هادفة','ألغاز وتحديات ذهنية','أفكار وأنشطة ذهنية مرحة وآمنة','https://www.riddles.com/'),
  ];
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  Future<void> _logout() async { await Supabase.instance.client.auth.signOut(); }
  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final items = resources.where((r) => (_category == 'الكل' || r.$1 == _category) && (q.isEmpty || '${r.$1} ${r.$2} ${r.$3}'.toLowerCase().contains(q))).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('شَغَف • المعرفة تصنع المستقبل'), actions: [IconButton(onPressed: _logout, tooltip: 'تسجيل الخروج', icon: const Icon(Icons.logout))]),
      body: _tab == 0 ? Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن موضوع نافع…', border: OutlineInputBorder()))),
        SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, children: categories.map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) => setState(() => _category = c))).toList())),
        Expanded(child: items.isEmpty ? const Center(child: Text('لا توجد نتائج مطابقة.')) : ListView.builder(itemCount: items.length, itemBuilder: (_, i) {
          final r = items[i];
          return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: ListTile(leading: const CircleAvatar(child: Icon(Icons.play_lesson_outlined)), title: Text(r.$2, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${r.$1} • ${r.$3}'), trailing: const Icon(Icons.open_in_new), onTap: () async { final uri = Uri.parse(r.$4); if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); } })),
        })),
      ]) : const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('سيتم تفعيل المفضلة وسجل المشاهدة بعد ربط خدمة المحتوى وقاعدة البيانات.', textAlign: TextAlign.center))),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (v) => setState(() => _tab = v), destinations: const [NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'اكتشف'), NavigationDestination(icon: Icon(Icons.bookmark_outline), label: 'مكتبتي')]),
    );
  }
}

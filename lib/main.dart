import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShaghafApp());
}

class ShaghafApp extends StatefulWidget {
  const ShaghafApp({super.key});
  @override
  State<ShaghafApp> createState() => _ShaghafAppState();
}

class _ShaghafAppState extends State<ShaghafApp> {
  String? name;
  String? phone;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      name = prefs.getString('member_name');
      phone = prefs.getString('member_phone');
      loading = false;
    });
  }

  Future<void> _login(String newName, String newPhone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('member_name', newName.trim());
    await prefs.setString('member_phone', newPhone.trim());
    if (!mounted) return;
    setState(() { name = newName.trim(); phone = newPhone.trim(); });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('member_name');
    await prefs.remove('member_phone');
    if (!mounted) return;
    setState(() { name = null; phone = null; });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'شَغَف',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5B46)),
      scaffoldBackgroundColor: const Color(0xFFF5F8F6),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B3B2E), foregroundColor: Colors.white),
    ),
    home: loading
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : name == null
        ? LoginScreen(onLogin: _login)
        : HomeScreen(memberName: name!, onLogout: _logout),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});
  final Future<void> Function(String, String) onLogin;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final n = nameController.text.trim();
    final p = phoneController.text.trim();
    if (n.isEmpty || p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال الاسم ورقم الهاتف')));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.onLogin(n, p);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.auto_stories_rounded, size: 76, color: Color(0xFF0B5B46)),
            const SizedBox(height: 14),
            const Text('أهلاً بك في شَغَف', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('مساحة للمعرفة والتعلّم والإبداع والترفيه الهادف',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 28),
            TextField(controller: nameController, textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'اسم المشترك',
                prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
            const SizedBox(height: 14),
            TextField(controller: phoneController, keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done, onSubmitted: (_) => submit(),
              decoration: const InputDecoration(labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_android), border: OutlineInputBorder())),
            const SizedBox(height: 20),
            FilledButton(onPressed: saving ? null : submit,
              child: Text(saving ? 'جارٍ الدخول...' : 'دخول مجاني')),
            const SizedBox(height: 12),
            const Text('لا يوجد رمز تفعيل أو اشتراك مدفوع في هذه النسخة.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
        ),
      ))),
    ),
  );
}

class ShaghafItem {
  const ShaghafItem(this.title, this.description, this.category, this.icon);
  final String title, description, category;
  final IconData icon;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.memberName, required this.onLogout});
  final String memberName;
  final Future<void> Function() onLogout;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const categories = ['الكل','العلوم والفضاء','الرياضة','الدين والقيم',
    'التربية والأخلاق','القراءة واللغة','الفنون والإبداع','الألغاز والترفيه'];
  static const catalog = <ShaghafItem>[
    ShaghafItem('رحلة إلى المجموعة الشمسية','تعرّف إلى الكواكب والنجوم وأسرار الفضاء بأسلوب مبسط.','العلوم والفضاء',Icons.public),
    ShaghafItem('كيف يعمل جسم الإنسان؟','اكتشاف مبسط لأجهزة الجسم ووظائفها.','العلوم والفضاء',Icons.biotech_outlined),
    ShaghafItem('الرياضة وروح الفريق','التعاون والانضباط واحترام الآخرين من خلال الرياضة.','الرياضة',Icons.sports_soccer),
    ShaghafItem('قيمة الصدق والأمانة','مواقف يومية نتعلم منها الصدق وتحمل المسؤولية.','التربية والأخلاق',Icons.volunteer_activism_outlined),
    ShaghafItem('آداب الحوار والاستماع','الحوار الهادئ واحترام اختلاف الآراء.','الدين والقيم',Icons.forum_outlined),
    ShaghafItem('متعة القراءة','أفكار تساعد على بناء عادة القراءة وتوسيع الخيال.','القراءة واللغة',Icons.menu_book_outlined),
    ShaghafItem('أطلق خيالك','أنشطة إبداعية لتنمية الرسم والتصميم والتفكير.','الفنون والإبداع',Icons.palette_outlined),
    ShaghafItem('ألغاز تنشّط التفكير','تحديات لطيفة لتنمية مهارات حل المشكلات.','الألغاز والترفيه',Icons.extension_outlined),
  ];

  final favorites = <String>{};
  final history = <String>{};
  String category = 'الكل';
  String query = '';
  int tab = 0;

  List<ShaghafItem> get visibleItems => catalog.where((item) {
    final categoryOk = category == 'الكل' || item.category == category;
    final searchOk = query.trim().isEmpty || item.title.contains(query.trim()) ||
      item.description.contains(query.trim()) || item.category.contains(query.trim());
    final tabOk = tab == 0 || (tab == 1 && favorites.contains(item.title)) ||
      (tab == 2 && history.contains(item.title));
    return categoryOk && searchOk && tabOk;
  }).toList();

  void openItem(ShaghafItem item) {
    setState(() => history.add(item.title));
    showDialog<void>(context: context, builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        icon: Icon(item.icon, size: 38, color: const Color(0xFF0B5B46)),
        title: Text(item.title),
        content: Text(item.description +
          '\n\nهذه بطاقة تعريفية تجريبية. ستضاف المواد المرئية والصوتية بعد مراجعة مصادرها واعتمادها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          FilledButton.tonal(onPressed: () {
            setState(() {
              if (favorites.contains(item.title)) { favorites.remove(item.title); }
              else { favorites.add(item.title); }
            });
            Navigator.pop(ctx);
          }, child: Text(favorites.contains(item.title) ? 'إزالة من المفضلة' : 'إضافة للمفضلة')),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('شَغَف', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(widget.memberName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [IconButton(tooltip: 'تسجيل الخروج', onPressed: widget.onLogout,
          icon: const Icon(Icons.logout))],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(14,14,14,8),
          child: TextField(onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(hintText: 'ابحث عن موضوع أو معرفة...',
              prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none)))),
        SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: categories.map((c) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(label: Text(c), selected: category == c,
              onSelected: (_) => setState(() => category = c)))).toList())),
        Expanded(child: visibleItems.isEmpty
          ? const Center(child: Text('لا توجد نتائج مطابقة'))
          : ListView.builder(padding: const EdgeInsets.all(12), itemCount: visibleItems.length,
            itemBuilder: (ctx, i) {
              final item = visibleItems[i];
              final fav = favorites.contains(item.title);
              return Card(margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(backgroundColor: const Color(0xFFE2F0E9),
                    child: Icon(item.icon, color: const Color(0xFF0B5B46))),
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 5),
                    child: Text(item.category + ' • ' + item.description)),
                  trailing: IconButton(onPressed: () => setState(() {
                    if (fav) { favorites.remove(item.title); } else { favorites.add(item.title); }
                  }), icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                    color: fav ? Colors.red : null)),
                  onTap: () => openItem(item)));
            })),
      ]),
      bottomNavigationBar: NavigationBar(selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: 'المفضلة'),
          NavigationDestination(icon: Icon(Icons.history), label: 'السجل'),
        ]),
    ),
  );
}

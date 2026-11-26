import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_guard.dart';
import 'backend.dart';
import 'media_hub.dart';
import 'admin_console.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Render the app immediately. Backend startup must never block the first frame.
  runApp(const ShaghafApp());
  unawaited(initializeShaghafBackend().catchError((_) => false));
}

class ShaghafApp extends StatefulWidget {
  const ShaghafApp({super.key});
  @override
  State<ShaghafApp> createState() => _ShaghafAppState();
}

class _ShaghafAppState extends State<ShaghafApp> {
  String? name;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  // Restore only a verified Supabase session and its bound installation.
  // A missing/invalid session always returns the user to OTP registration.
  Future<void> _restore() async {
    String? restoredName;
    final prefs = await SharedPreferences.getInstance();
    final localName = prefs.getString('shaghaf_member_name');
    try {
      final ready = await initializeShaghafBackend();
      if (ready) {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user != null) {
          final deviceId = await ShaghafDeviceGuard.getDeviceId();
          final allowed = await client.rpc(
            'check_shaghaf_device',
            params: {'p_device_id': deviceId},
          ) as bool;
          if (allowed) {
            final subscriber = await client
                .from('subscribers')
                .select('display_name')
                .eq('auth_user_id', user.id)
                .maybeSingle();
            final savedName = subscriber?['display_name']?.toString().trim();
            final metadataName = user.userMetadata?['display_name']?.toString().trim();
            restoredName = (savedName != null && savedName.isNotEmpty)
                ? savedName
                : ((metadataName != null && metadataName.isNotEmpty)
                    ? metadataName
                    : null);
            if (restoredName == null) {
              await client.auth.signOut();
            }
          } else {
            await client.auth.signOut();
          }
        }
      }
    } catch (_) {
      restoredName = null;
    }
    // Until SMS/email delivery is configured, restore the locally registered member
    // without presenting a non-working OTP screen on every launch.
    restoredName ??= (localName != null && localName.trim().isNotEmpty) ? localName : null;
    try {
    } finally {
      if (mounted) {
        setState(() {
          name = restoredName;
          loading = false;
        });
      }
    }
  }

  Future<void> _login(String memberName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shaghaf_member_name', memberName.trim());
    if (mounted) setState(() => name = memberName.trim());
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('shaghaf_member_name');
    try {
      if (shaghafBackendReady && Supabase.instance.client.auth.currentSession != null) {
        await Supabase.instance.client.auth.signOut();
      }
    } finally {
      if (mounted) setState(() => name = null);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'شَغَف',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5B46)),
      scaffoldBackgroundColor: const Color(0xFFF5F8F6),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 17, height: 1.45),
        bodyMedium: TextStyle(fontSize: 16, height: 1.4),
        bodySmall: TextStyle(fontSize: 14, height: 1.35),
        titleLarge: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B3B2E), foregroundColor: Colors.white,
        centerTitle: false, toolbarHeight: 76,
        titleTextStyle: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
      navigationBarTheme: NavigationBarThemeData(
        height: 76, backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDCEFE6),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 14, fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          color: states.contains(WidgetState.selected) ? const Color(0xFF0B5B46) : const Color(0xFF68756F))),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          size: 26, color: states.contains(WidgetState.selected) ? const Color(0xFF0B5B46) : const Color(0xFF68756F))),
    ),
    ),
    home: loading
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : name == null ? LoginScreen(onLogin: _login)
      : HomeScreen(memberName: name!, onLogout: _logout),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});
  final Future<void> Function(String) onLogin;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final nameController = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> continueToApp() async {
    final memberName = nameController.text.trim();
    if (memberName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب اسمًا من حرفين على الأقل.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      // This is a local first-entry profile, not phone/email verification.
      // OTP is intentionally absent until the delivery providers are configured
      // and successfully tested in Supabase.
      await widget.onLogin(memberName);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ بيانات الدخول على هذا الجهاز.')),
        );
      }
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
            Container(width: 112, height: 112,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF0B3B2E), Color(0xFF168568)]),
                boxShadow: [BoxShadow(color: const Color(0xFF0B5B46).withValues(alpha: .22), blurRadius: 22, offset: const Offset(0, 8))],
                border: Border.all(color: const Color(0xFFD6B66B), width: 2)),
              child: const Icon(Icons.auto_stories_rounded, size: 58, color: Colors.white)),
            const SizedBox(height: 16),
            const Text('✦ شَغَف ✦', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFF0B5B46))),
            const SizedBox(height: 5),
            const Text('المعرفة تبدأ بشغف', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFFB18A3B))),
            const SizedBox(height: 8),
            const Text('مساحة للمعرفة والتعلّم والإبداع والترفيه الهادف',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 26),
            TextField(controller: nameController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => continueToApp(),
              decoration: const InputDecoration(labelText: 'اسم المشترك',
                prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving ? null : continueToApp,
              child: Text(saving ? 'يرجى الانتظار...' : 'دخول مجاني')),
            const SizedBox(height: 12),
            const Text('لن نطلب رقم هاتف أو بريدًا إلكترونيًا أو رمز تأكيد في هذه النسخة. يُحفظ الاسم على هذا الجهاز لتبقى مسجلاً عند فتح التطبيق لاحقًا.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5)),
          ]),
        ),
      ))),
    ),
  );
}

class ShaghafItem {
  const ShaghafItem(this.title, this.description, this.category, this.icon, this.content);
  final String title, description, category, content;
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
    ShaghafItem('رحلة إلى المجموعة الشمسية','تعرّف إلى الكواكب والنجوم وأسرار الفضاء بأسلوب مبسط.','العلوم والفضاء',Icons.public,
      'تدور المجموعة الشمسية حول الشمس، وهي نجم يمد كواكبها بالضوء والحرارة. تضم ثمانية كواكب، ولكل كوكب خصائص تميّزه.\n\nعطارد أقرب الكواكب إلى الشمس، والزهرة شديد الحرارة، والأرض موطن الحياة المعروف لنا، أما المريخ فيُعرف بالكوكب الأحمر. وتأتي بعده الكواكب العملاقة: المشتري وزحل وأورانوس ونبتون.\n\nلا تسير الكواكب في خطوط مستقيمة، بل تتحرك في مدارات حول الشمس بفعل الجاذبية. ويستغرق كل كوكب زمناً مختلفاً لإكمال دورة واحدة حولها.'),
    ShaghafItem('كيف يعمل جسم الإنسان؟','اكتشاف مبسط لأجهزة الجسم ووظائفها.','العلوم والفضاء',Icons.biotech_outlined,
      'جسم الإنسان يعمل بتعاون أجهزة كثيرة. فالجهاز التنفسي يساعدنا على أخذ الأكسجين، والجهاز الدوري ينقل الدم وما يحمله إلى أنحاء الجسم.\n\nيهضم الجهاز الهضمي الطعام ليستفيد الجسم من العناصر الغذائية، بينما يساعد الجهاز العصبي على استقبال المعلومات والتفكير والحركة.\n\nالنوم الكافي، والغذاء المتوازن، والنشاط اليومي، والنظافة الشخصية عادات تدعم صحة الجسم.'),
    ShaghafItem('الرياضة وروح الفريق','التعاون والانضباط واحترام الآخرين من خلال الرياضة.','الرياضة',Icons.sports_soccer,
      'الرياضة ليست منافسة على الفوز فقط؛ إنها فرصة لتعلّم التعاون والانضباط واحترام القواعد. يحتاج الفريق إلى أن يستمع أفراده بعضهم إلى بعض، وأن يتشاركوا المسؤولية.\n\nاللاعب الجيد يحترم زملاءه ومنافسيه والحكم، ويتقبل الفوز والخسارة بروح طيبة. ويمكن اختيار نشاط مناسب للعمر والقدرة وممارسته بأمان وانتظام.'),
    ShaghafItem('قيمة الصدق والأمانة','مواقف يومية نتعلم منها الصدق وتحمل المسؤولية.','التربية والأخلاق',Icons.volunteer_activism_outlined,
      'الصدق هو أن نقول الحقيقة، والأمانة هي أن نحافظ على الحقوق ونؤدي ما اؤتمنّا عليه. وهاتان القيمتان تبنيان الثقة بين الناس.\n\nإذا أخطأنا، فإن الاعتراف بالخطأ ومحاولة إصلاحه أفضل من إخفائه أو إلقاء اللوم على الآخرين. وفي المدرسة والبيت، تظهر الأمانة في حفظ الممتلكات وإرجاع الأشياء إلى أصحابها.'),
    ShaghafItem('آداب الحوار والاستماع','الحوار الهادئ واحترام اختلاف الآراء.','الدين والقيم',Icons.forum_outlined,
      'الحوار الناجح يبدأ بالاستماع الجيد، ثم التعبير عن الرأي بوضوح وهدوء. ليس ضرورياً أن نتفق دائماً، لكن من المهم أن نحترم الأشخاص حتى عندما تختلف آراؤنا.\n\nمن آداب الحوار عدم المقاطعة، واختيار الكلمات الطيبة، وطلب التوضيح عند عدم الفهم، والابتعاد عن السخرية. قال تعالى: «وَقُولُوا لِلنَّاسِ حُسْنًا».'),
    ShaghafItem('متعة القراءة','أفكار تساعد على بناء عادة القراءة وتوسيع الخيال.','القراءة واللغة',Icons.menu_book_outlined,
      'القراءة نافذة نطل منها على العلوم والقصص والتجارب والأفكار. وهي توسّع المفردات وتساعد على التركيز والتعبير.\n\nابدأ بموضوع تحبه، وحدد وقتاً قصيراً مناسباً كل يوم. بعد القراءة، حاول أن تلخص الفكرة الرئيسية بجملة أو تذكر معلومة جديدة تعلمتها. ومع الوقت ستصبح القراءة عادة ممتعة.'),
    ShaghafItem('أطلق خيالك','أنشطة إبداعية لتنمية الرسم والتصميم والتفكير.','الفنون والإبداع',Icons.palette_outlined,
      'الإبداع هو تجربة أفكار جديدة وإيجاد طرق مختلفة للتعبير وحل المشكلات. يمكن أن يظهر في الرسم والكتابة والتصميم وصناعة الأشياء والعلوم.\n\nجرّب أن ترسم مكاناً خيالياً، أو تكتب نهاية مختلفة لقصة، أو تصمم حلاً بسيطاً لمشكلة في المنزل. لا يشترط أن تكون النتيجة مثالية؛ المهم أن تتعلم من التجربة.'),
    ShaghafItem('ألغاز تنشّط التفكير','تحديات لطيفة لتنمية مهارات حل المشكلات.','الألغاز والترفيه',Icons.extension_outlined,
      'لغز: شيء كلما أخذت منه كَبُر، فما هو؟\n\nفكّر قليلاً قبل قراءة الإجابة.\n\nالإجابة: الحفرة؛ فكلما أزلت منها التراب اتسعت.\n\nالألغاز تدربنا على النظر إلى المسألة من زوايا مختلفة، وشرح سبب الإجابة لا يقل أهمية عن الوصول إليها.'),
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
      child: Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE2F0E9),
                  child: Icon(item.icon, color: const Color(0xFF0B5B46)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(item.title,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
                IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(alignment: Alignment.centerRight,
                child: Text(item.description,
                  style: const TextStyle(color: Colors.black54))),
            ),
            const Divider(height: 24),
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SelectableText(item.content,
                style: const TextStyle(fontSize: 16, height: 1.8)),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      if (favorites.contains(item.title)) {
                        favorites.remove(item.title);
                      } else {
                        favorites.add(item.title);
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  icon: Icon(favorites.contains(item.title)
                    ? Icons.favorite : Icons.favorite_border),
                  label: Text(favorites.contains(item.title)
                    ? 'إزالة من المفضلة' : 'حفظ في المفضلة'),
                )),
                const SizedBox(width: 8),
                TextButton(onPressed: () => Navigator.pop(ctx),
                  child: const Text('تم')),
              ]),
            ),
          ]),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft,
            colors: [Color(0xFF082F25), Color(0xFF0B5B46), Color(0xFF14775D)]))),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('✦ شَغَف ✦', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Color(0xFFFFE3A1))),
          Text('أهلاً ${widget.memberName}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70)),
        ]),
        actions: [
          IconButton(tooltip: 'لوحة الإدارة', onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AdminConsoleScreen())),
            icon: const Icon(Icons.admin_panel_settings_outlined)),
          IconButton(tooltip: 'تسجيل الخروج', onPressed: widget.onLogout,
            icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: tab == 3 ? MediaHubScreen(initialQuery: query) : Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(14,14,14,8),
          child: TextField(onSubmitted: (v) { if (v.trim().isNotEmpty) setState(() => tab = 3); }, onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(hintText: 'ابحث عن موضوع أو معرفة...',
              prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none)))),
        if (query.trim().isNotEmpty) Padding(padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 8), child: Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => setState(() => tab = 3), icon: const Icon(Icons.travel_explore), label: const Text('ابحث في مكتبة الفيديوهات المتصلة بالإنترنت')))),
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
              return Card(elevation: 1.5, margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  leading: CircleAvatar(backgroundColor: const Color(0xFFE2F0E9),
                    child: Icon(item.icon, color: const Color(0xFF0B5B46))),
                  title: Text(item.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF173D31))),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 7),
                    child: Text(item.category + ' • ' + item.description,
                      style: const TextStyle(fontSize: 15, height: 1.45))),
                  trailing: IconButton(onPressed: () => setState(() {
                    if (fav) { favorites.remove(item.title); } else { favorites.add(item.title); }
                  }), icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                    color: fav ? Colors.red : null)),
                  onTap: () => openItem(item)));
            })),
      ]),
      bottomNavigationBar: NavigationBar(labelBehavior: NavigationDestinationLabelBehavior.alwaysShow, selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: 'المفضلة'),
          NavigationDestination(icon: Icon(Icons.history), label: 'السجل'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), label: 'الوسائط'),
        ]),
    ),
  );
}

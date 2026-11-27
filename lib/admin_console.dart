import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend.dart';

const _green = Color(0xFF0B5B46);

class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});
  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool authorized = false;
  String? error;
  int tab = 0;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (!shaghafBackendConfigured) {
      setState(() => error = 'لم يتم إعداد اتصال قاعدة البيانات بعد. يلزم إعداد مفاتيح المشروع في إعدادات البناء.');
      return;
    }
    setState(() { busy = true; error = null; });

    final clientReady = await initializeShaghafBackend();
    if (!clientReady) {
      if (mounted) {
        setState(() {
          error = 'تعذر تهيئة اتصال Supabase. تحقق من رابط المشروع ومفتاح Publishable في إعدادات البناء.';
          busy = false;
        });
      }
      return;
    }

    final client = Supabase.instance.client;
    var signedInThisAttempt = false;
    var loginAuthorized = false;
    try {
      await client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
      signedInThisAttempt = true;

      final user = client.auth.currentUser;
      if (user == null) {
        throw const AuthException('تم تسجيل الدخول لكن تعذر قراءة بيانات الحساب. حاول مرة أخرى.');
      }

      final profile = await client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile?['role']?.toString() != 'admin') {
        throw const AuthException(
          'تم التحقق من الحساب، لكن لا توجد له صلاحية مدير. تحقق من سجل profiles وأن role تساوي admin.',
        );
      }

      loginAuthorized = true;
      if (mounted) setState(() => authorized = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => error = 'تعذر قراءة صلاحية المدير من profiles: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = 'حدث خطأ أثناء التحقق من صلاحية المدير. تحقق من الإنترنت وسياسات RLS.');
      }
    } finally {
      // Never leave an authenticated but unverified account signed in.
      if (signedInThisAttempt && !loginAuthorized) {
        try {
          await client.auth.signOut();
        } catch (_) {
          // Preserve the original sign-in/authorization error for the user.
        }
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> signOut() async {
    if (shaghafBackendReady) await Supabase.instance.client.auth.signOut();
    if (mounted) setState(() => authorized = false);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: Text(authorized ? 'إدارة شغف' : 'دخول المدير'),
        backgroundColor: const Color(0xFF0B3B2E),
        foregroundColor: Colors.white,
        actions: [if (authorized) IconButton(onPressed: signOut, tooltip: 'خروج المدير', icon: const Icon(Icons.logout))],
      ),
      body: authorized
        ? Column(children: [
            NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.analytics_outlined), label: 'الإحصائيات'),
                NavigationDestination(icon: Icon(Icons.video_library_outlined), label: 'الفيديوهات'),
                NavigationDestination(icon: Icon(Icons.comment_outlined), label: 'التعليقات'),
                NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'البلاغات'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'الإعدادات'),
              ]),
            Expanded(child: IndexedStack(index: tab, children: const [
              _AdminStats(), _VideoAdmin(), _CommentAdmin(), _ReportAdmin(), _SettingsAdmin(),
            ])),
          ])
        : _loginForm(),
    ),
  );

  Widget _loginForm() => Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.admin_panel_settings, size: 68, color: _green),
        const SizedBox(height: 12),
        const Text('لوحة تحكم المدير', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('الدخول مخصص لحساب إداري معتمد فقط.', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        TextField(controller: email, keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: password, obscureText: true,
          decoration: const InputDecoration(labelText: 'كلمة المرور', border: OutlineInputBorder())),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12),
          child: Text(error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: busy ? null : signIn,
          icon: const Icon(Icons.lock_open), label: Text(busy ? 'جارٍ التحقق...' : 'دخول آمن')),
        const SizedBox(height: 12),
        const Text('لا يتم إنشاء حساب مدير من داخل التطبيق. تُمنح الصلاحية من قاعدة البيانات بواسطة مالك المشروع.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
    ),
  ));
}

class _AdminStats extends StatefulWidget {
  const _AdminStats();
  @override
  State<_AdminStats> createState() => _AdminStatsState();
}

class _AdminStatsState extends State<_AdminStats> {
  bool loading = true;
  String? error;
  Map<String, int> counts = {};
  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final db = Supabase.instance.client;
      final members = (await db.from('subscribers').select('id')).length;
      final videos = (await db.from('videos').select('id')).length;
      final comments = (await db.from('comments').select('id')).length;
      final pending = (await db.from('comments').select('id').eq('status', 'pending')).length;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day).toUtc();
      final weekStart = DateTime(now.year, now.month, now.day - now.weekday + 1).toUtc();
      final monthStart = DateTime(now.year, now.month, 1).toUtc();
      final newToday = (await db.from('subscribers').select('id').gte('created_at', today.toIso8601String())).length;
      final newWeek = (await db.from('subscribers').select('id').gte('created_at', weekStart.toIso8601String())).length;
      final newMonth = (await db.from('subscribers').select('id').gte('created_at', monthStart.toIso8601String())).length;
      if (mounted) setState(() => counts = {'إجمالي المشتركين': members, 'مشتركون جدد اليوم': newToday, 'مشتركون جدد هذا الأسبوع': newWeek, 'مشتركون جدد هذا الشهر': newMonth, 'الفيديوهات': videos, 'التعليقات': comments, 'تعليقات قيد المراجعة': pending});
    } catch (_) { if (mounted) setState(() => error = 'تعذر تحميل الإحصائيات. تحقق من الجداول وصلاحيات قاعدة البيانات.'); }
    finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(onRefresh: load, child: ListView(
    padding: const EdgeInsets.all(16), children: [
      Row(children: [const Expanded(child: Text('ملخص المنصة', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold))),
        IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
      if (loading) const LinearProgressIndicator(),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
      ...counts.entries.map((e) => Card(child: ListTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFFE1F0E8), child: Icon(Icons.insights, color: _green)),
        title: Text(e.key), trailing: Text('${e.value}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))))),
      const Padding(padding: EdgeInsets.only(top: 12), child: Text('تعرض هذه اللوحة أعداد المشتركين والفيديوهات والتعليقات المسجلة في قاعدة بيانات شغف.',
        style: TextStyle(color: Colors.black54))),
    ],
  ));
}

class _VideoAdmin extends StatefulWidget {
  const _VideoAdmin();
  @override
  State<_VideoAdmin> createState() => _VideoAdminState();
}

class _VideoAdminState extends State<_VideoAdmin> {
  final title = TextEditingController();
  final description = TextEditingController();
  final category = TextEditingController(text: 'العلوم والفضاء');
  final sourceUrl = TextEditingController();
  final discoveryTopic = TextEditingController();
  final Set<String> discoveryCategories = {'التعليم والمعرفة', 'العلوم والاكتشاف'};
  String language = 'العربية';
  bool busy = false;
  bool discovering = false;
  String? message;
  List<Map<String, dynamic>> existingVideos = [];

  @override
  void initState() { super.initState(); loadVideos(); }

  @override
  void dispose() { title.dispose(); description.dispose(); category.dispose(); sourceUrl.dispose(); discoveryTopic.dispose(); super.dispose(); }

  Future<void> loadVideos() async {
    try {
      final db = Supabase.instance.client;
      final rows = await db.from('videos')
        .select('id,title,video_url,description,category,language,status,created_at,video_views(id),video_likes(user_id)')
        .order('created_at', ascending: false).limit(100);
      final enriched = rows.map<Map<String, dynamic>>((raw) {
        final video = Map<String, dynamic>.from(raw);
        video['views_count'] = (video['video_views'] as List? ?? const []).length;
        video['likes_count'] = (video['video_likes'] as List? ?? const []).length;
        video.remove('video_views');
        video.remove('video_likes');
        return video;
      }).toList();
      if (mounted) setState(() => existingVideos = enriched);
    } catch (_) { if (mounted) setState(() => message = 'تعذر تحميل قائمة الفيديوهات.'); }
  }

  Future<void> changeVideoStatus(Map<String, dynamic> video, String status) async {
    if (status == 'published') {
      var reviewed = false;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('مراجعة ما قبل النشر'),
            content: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(video['title']?.toString() ?? 'فيديو بدون عنوان',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('القسم: ${video['category'] ?? 'غير محدد'} • اللغة: ${video['language'] ?? 'غير محددة'}'),
                const SizedBox(height: 8),
                const Text('افتح الفيديو وافحصه كاملاً، بما في ذلك الصوت والصورة المصغرة والمصدر وملاءمته للفئة العمرية وحقوق استخدامه.'),
                const SizedBox(height: 8),
                SelectableText(video['video_url']?.toString() ?? ''),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: reviewed,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('أؤكد أنني راجعت المحتوى كاملاً وتحققت من ملاءمته ومصدره.'),
                  onChanged: (value) => setDialogState(() => reviewed = value ?? false),
                ),
              ],
            )),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء')),
              FilledButton(
                onPressed: reviewed ? () => Navigator.pop(dialogContext, true) : null,
                child: const Text('تأكيد النشر'),
              ),
            ],
          ),
        ),
      );
      if (approved != true) return;
    }
    try {
      await Supabase.instance.client.from('videos').update({'status': status}).eq('id', video['id']);
      await loadVideos();
    } catch (_) { if (mounted) setState(() => message = 'تعذر تعديل حالة الفيديو.'); }
  }

  Future<void> deleteVideo(Map<String, dynamic> video) async {
    try {
      await Supabase.instance.client.from('videos').delete().eq('id', video['id']);
      await loadVideos();
    } catch (_) { if (mounted) setState(() => message = 'تعذر حذف الفيديو.'); }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await http.get(uri, headers: const {
      'Accept': 'application/json',
      'User-Agent': 'ShaghafApp/1.0 (educational video discovery)',
    }).timeout(const Duration(seconds: 18));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  String _cleanText(dynamic value, [int max = 1000]) {
    final valueText = value?.toString().replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    return valueText.length > max ? valueText.substring(0, max) : valueText;
  }

  Future<bool> _saveSearchCandidate({
    required String title,
    required String description,
    required String categoryName,
    required String url,
    required String source,
    String languageName = 'غير محددة',
  }) async {
    if (title.isEmpty || !url.startsWith('https://')) return false;
    final db = Supabase.instance.client;
    final exists = await db.from('videos').select('id')
        .eq('video_url', url).maybeSingle();
    if (exists != null) return false;
    await db.from('videos').insert({
      'title': title.substring(0, title.length > 180 ? 180 : title.length),
      'description': [description, 'المصدر: $source'].where((v) => v.isNotEmpty).join('\n\n'),
      'category': categoryName,
      'language': languageName,
      'video_url': url,
      'status': 'pending',
      'allow_comments': false,
      'created_by': db.auth.currentUser!.id,
    });
    return true;
  }

  Future<void> discoverVideos() async {
    if (discoveryCategories.isEmpty && discoveryTopic.text.trim().isEmpty) {
      setState(() => message = 'اختر قسماً أو اكتب موضوعاً مخصصاً للبحث.');
      return;
    }
    setState(() { discovering = true; message = null; });
    var imported = 0;
    var checked = 0;
    final errors = <String>[];
    final selected = discoveryCategories.toList();
    if (discoveryTopic.text.trim().isNotEmpty) selected.add(discoveryTopic.text.trim());
    final topics = <String, String>{
      'التعليم والمعرفة': 'educational science learning lessons',
      'التحفيز والدراسة': 'study motivation student success learning',
      'الاختراعات والهندسة': 'inventions engineering robotics technology',
      'الدين والأخلاق': 'Islam Islamic education morals Quran',
      'قصص الأنبياء والصالحين': 'prophets stories Islamic history',
      'القرآن الكريم': 'Quran recitation education',
      'العلوم والاكتشاف': 'science discovery nature space astronomy',
      'الفكاهة النظيفة': 'family friendly clean educational comedy',
      'الطبيعة والوثائقيات': 'nature environment documentary',
    };
    final nasaTopics = <String, String>{
      'التعليم والمعرفة': 'science education Earth science',
      'الاختراعات والهندسة': 'engineering technology robotics',
      'العلوم والاكتشاف': 'space science astronomy',
      'الطبيعة والوثائقيات': 'Earth oceans nature',
    };
    for (final selectedName in selected) {
      final categoryName = topics.containsKey(selectedName) ? selectedName : 'بحث مخصص';
      final terms = topics[selectedName] ?? selectedName;
      try {
        final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
          'action': 'query', 'format': 'json', 'generator': 'search',
          'gsrsearch': 'filetype:video $terms', 'gsrnamespace': '6',
          'gsrlimit': '4', 'prop': 'imageinfo', 'iiprop': 'url|mime|extmetadata',
          'iiextmetadatafilter': 'LicenseShortName|LicenseUrl|Artist|Credit|ImageDescription',
        });
        final data = await _getJson(uri);
        final pages = (data['query']?['pages'] as Map?)?.values ?? const [];
        for (final rawPage in pages) {
          final page = Map<String, dynamic>.from(rawPage as Map);
          final infos = page['imageinfo'] as List? ?? const [];
          if (infos.isEmpty) continue;
          final info = Map<String, dynamic>.from(infos.first as Map);
          final ext = Map<String, dynamic>.from(info['extmetadata'] as Map? ?? {});
          String meta(String key) => _cleanText((ext[key] as Map?)?['value'], 700);
          final license = meta('LicenseShortName');
          final direct = _cleanText(info['url'], 1000);
          final pageUrl = _cleanText(info['descriptionurl'], 1000);
          final mime = _cleanText(info['mime']).toLowerCase();
          final allowed = RegExp(r'^(CC BY 4\.0|CC BY-SA 4\.0|CC BY 3\.0|CC BY-SA 3\.0|CC0 1\.0|Public domain)', caseSensitive: false).hasMatch(license);
          if (!allowed || !['video/mp4', 'video/webm'].contains(mime) ||
              !RegExp(r'^https://upload\.wikimedia\.org/wikipedia/commons/.+\.(mp4|webm)$', caseSensitive: false).hasMatch(direct) ||
              !pageUrl.startsWith('https://commons.wikimedia.org/wiki/File:')) continue;
          checked++;
          final titleText = _cleanText(page['title']).replaceFirst(RegExp(r'^File:', caseSensitive: false), '');
          final desc = [meta('ImageDescription'), 'صفحة الملف: $pageUrl',
            'المؤلف: ${meta('Artist')}', 'الاعتماد: ${meta('Credit')}',
            'الرخصة: $license ${meta('LicenseUrl')}'].where((v) => v.trim().isNotEmpty).join('\n');
          if (await _saveSearchCandidate(title: titleText, description: desc,
              categoryName: categoryName, url: direct, source: 'Wikimedia Commons')) imported++;
        }
      } catch (_) { errors.add('Wikimedia Commons'); }

      try {
        final q = Uri.https('archive.org', '/advancedsearch.php', {
          'q': 'mediatype:movies AND (title:"$terms" OR description:"$terms")',
          'fl[]': 'identifier,title,description,creator,licenseurl', 'rows': '4', 'output': 'json',
        });
        final data = await _getJson(q);
        final docs = data['response']?['docs'] as List? ?? const [];
        for (final rawDoc in docs) {
          final doc = Map<String, dynamic>.from(rawDoc as Map);
          final identifier = _cleanText(doc['identifier'], 120);
          final license = _cleanText(doc['licenseurl'], 500);
          if (!RegExp(r'creativecommons\.org/(licenses/by(-sa)?/4\.0|publicdomain/zero/1\.0)', caseSensitive: false).hasMatch(license) ||
              !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(identifier)) continue;
          final meta = await _getJson(Uri.https('archive.org', '/metadata/$identifier'));
          final files = meta['files'] as List? ?? const [];
          Map? mp4;
          for (final rawFile in files) {
            if (rawFile is Map && _cleanText(rawFile['name']).toLowerCase().endsWith('.mp4') &&
                !_cleanText(rawFile['name']).contains('/') && _cleanText(rawFile['source']) != 'metadata') {
              mp4 = rawFile; break;
            }
          }
          if (mp4 == null) continue;
          final fileName = _cleanText(mp4['name'], 300);
          final direct = 'https://archive.org/download/${Uri.encodeComponent(identifier)}/${Uri.encodeComponent(fileName)}';
          checked++;
          final desc = [_cleanText(doc['description'], 900), 'المؤلف: ${_cleanText(doc['creator'], 200)}',
            'الرخصة: $license', 'صفحة المصدر: https://archive.org/details/$identifier']
              .where((v) => v.trim().isNotEmpty).join('\n');
          if (await _saveSearchCandidate(title: _cleanText(doc['title'], 180),
              description: desc, categoryName: categoryName, url: direct,
              source: 'Internet Archive')) imported++;
        }
      } catch (_) { errors.add('Internet Archive'); }

      final nasaTerm = nasaTopics[selectedName];
      if (nasaTerm != null) {
        try {
          final uri = Uri.https('images-api.nasa.gov', '/search', {
            'q': nasaTerm, 'media_type': 'video', 'page_size': '4',
          });
          final data = await _getJson(uri);
          final items = data['collection']?['items'] as List? ?? const [];
          for (final rawItem in items) {
            final item = Map<String, dynamic>.from(rawItem as Map);
            final metaList = item['data'] as List? ?? const [];
            if (metaList.isEmpty) continue;
            final meta = Map<String, dynamic>.from(metaList.first as Map);
            final asset = _cleanText(item['href'], 1000);
            if (!asset.startsWith('https://images-assets.nasa.gov/')) continue;
            final response = await http.get(Uri.parse(asset), headers: const {
              'User-Agent': 'ShaghafApp/1.0',
            }).timeout(const Duration(seconds: 18));
            if (response.statusCode < 200 || response.statusCode >= 300) continue;
            final assets = jsonDecode(response.body);
            if (assets is! List) continue;
            String? direct;
            for (final value in assets.whereType<String>()) {
              if (RegExp(r'^https://images-assets\.nasa\.gov/video/[a-zA-Z0-9_./-]+\.mp4(?:\?.*)?$', caseSensitive: false).hasMatch(value)) {
                direct = value; break;
              }
            }
            if (direct == null) continue;
            checked++;
            if (await _saveSearchCandidate(title: _cleanText(meta['title'], 180),
                description: _cleanText(meta['description'], 1000),
                categoryName: categoryName, url: direct,
                source: 'NASA Image and Video Library', languageName: 'الإنجليزية')) imported++;
          }
        } catch (_) { errors.add('NASA'); }
      }
    }
    if (mounted) setState(() => message =
        'اكتمل البحث في المصادر المجانية الثلاثة: أُضيف $imported فيديو إلى قائمة المراجعة من $checked نتيجة مفحوصة. لم يُنشر أي فيديو تلقائياً.'
        '${errors.isEmpty ? '' : ' تعذر الوصول إلى بعض المصادر: ${errors.toSet().join('، ')}'}');
    await loadVideos();
    if (mounted) setState(() => discovering = false);
  }

  Future<void> chooseVideoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: false, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final extension = (file.extension ?? '').toLowerCase();
      if (!const {'mp4', 'm4v', 'mov', 'webm'}.contains(extension)) {
        setState(() => message = 'الصيغ المدعومة حالياً: MP4 وM4V وMOV وWEBM.');
        return;
      }
      if (file.size > 50 * 1024 * 1024) {
        setState(() => message = 'حجم الملف يتجاوز 50 ميجابايت. اختر فيديو أصغر حالياً؛ يمكن رفع الحد عند تجهيز خدمة فيديو مخصصة.');
        return;
      }
      setState(() {
        selectedVideoFile = file;
        sourceUrl.clear();
        message = 'تم اختيار الفيديو. سيُرفع إلى مساحة تخزين شغف ثم يدخل المراجعة.';
      });
    } catch (_) {
      if (mounted) setState(() => message = 'تعذر اختيار ملف الفيديو من الجهاز.');
    }
  }

  Future<void> publish() async {
    final source = sourceUrl.text.trim();
    final uri = Uri.tryParse(source);
    final extension = uri?.path.toLowerCase().split('.').last ?? '';
    final hasUpload = selectedVideoFile != null;
    if (title.text.trim().isEmpty ||
        (!hasUpload && (uri == null || uri.scheme != 'https' ||
          !const {'mp4', 'm4v', 'mov', 'webm', 'm3u8'}.contains(extension)))) {
      setState(() => message = 'أدخل عنوان الفيديو واختر ملفاً من جهازك أو أدخل رابط HTTPS مباشر لفيديو.');
      return;
    }
    setState(() { busy = true; message = null; });
    try {
      final db = Supabase.instance.client;
      var videoUrl = source;
      if (hasUpload) {
        final file = selectedVideoFile!;
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) throw StateError('تعذر قراءة بيانات ملف الفيديو.');
        final ext = (file.extension ?? 'mp4').toLowerCase();
        final contentType = switch (ext) {
          'webm' => 'video/webm',
          'mov' => 'video/quicktime',
          'm4v' => 'video/x-m4v',
          _ => 'video/mp4',
        };
        final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final path = '${db.auth.currentUser!.id}/${DateTime.now().microsecondsSinceEpoch}_$safeName';
        await db.storage.from('shaghaf-videos').uploadBinary(
          path, bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
        videoUrl = db.storage.from('shaghaf-videos').getPublicUrl(path);
      }
      await db.from('videos').insert({
        'title': title.text.trim(), 'description': description.text.trim(),
        'category': category.text.trim(), 'language': language,
        'video_url': videoUrl, 'status': 'pending',
        'allow_comments': true, 'created_by': db.auth.currentUser!.id,
      });
      title.clear(); description.clear(); sourceUrl.clear();
      setState(() {
        selectedVideoFile = null;
        message = 'تم رفع الفيديو إلى تخزين شغف وإرساله للمراجعة. لن يظهر للمشتركين قبل اعتماده ونشره من المدير.';
      });
      await loadVideos();
    } catch (e) {
      if (mounted) setState(() => message =
        'تعذر رفع الفيديو أو تسجيله. تحقق من صلاحية رفع الملفات في Storage وسعة التخزين واتصال الإنترنت. (${e.runtimeType})');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('اكتشاف الفيديوهات حسب محتوى شَغَف', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    const Text('اختر الأقسام التي تريد إثراءها، أو اكتب موضوعاً خاصاً. يبحث المحرك في Wikimedia Commons وInternet Archive وNASA، وتدخل النتائج المؤهلة قائمة المراجعة فقط. لا يظهر أي فيديو للمشتركين قبل مراجعته واعتماده.'),
    const SizedBox(height: 10),
    const Text('الأقسام الأساسية', style: TextStyle(fontWeight: FontWeight.bold)),
    ...[
      'التعليم والمعرفة', 'التحفيز والدراسة', 'الاختراعات والهندسة',
      'الدين والأخلاق', 'قصص الأنبياء والصالحين', 'القرآن الكريم',
      'العلوم والاكتشاف', 'الفكاهة النظيفة', 'الطبيعة والوثائقيات',
    ].map((name) => CheckboxListTile(
      dense: true, contentPadding: EdgeInsets.zero,
      title: Text(name), value: discoveryCategories.contains(name),
      onChanged: discovering ? null : (checked) => setState(() {
        if (checked == true) {
          if (discoveryCategories.length >= 5) {
            message = 'يمكن اختيار خمسة أقسام كحد أقصى في كل عملية بحث.';
          } else {
            discoveryCategories.add(name);
          }
        } else {
          discoveryCategories.remove(name);
        }
      }),
    )),
    const SizedBox(height: 8),
    TextField(controller: discoveryTopic, maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'موضوع مخصص يبحث عنه المدير',
        hintText: 'مثال: قصص النساء في القرآن أو اختراعات العلماء المسلمين',
        border: OutlineInputBorder(),
      )),
    const SizedBox(height: 10),
    FilledButton.tonalIcon(
      onPressed: discovering ? null : discoverVideos,
      icon: discovering ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.travel_explore),
      label: Text(discovering ? 'جارٍ البحث في المصادر...' : 'ابحث واجلب المرشحين للمراجعة'),
    ),
    const Text('محرك شغف يبحث مباشرة في Wikimedia Commons وInternet Archive وNASA فقط، دون الحاجة إلى مفتاح YouTube. كل نتيجة تدخل قائمة المراجعة ولا تُنشر تلقائياً؛ يجب فحص الفيديو كاملاً قبل اعتماده.',
      style: TextStyle(fontSize: 12, color: Colors.black54)),
    const Divider(height: 30),
    const Text('إضافة فيديو يدوياً', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الفيديو', border: OutlineInputBorder())),
    const SizedBox(height: 10),
    TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'وصف الفيديو', border: OutlineInputBorder())),
    const SizedBox(height: 10),
    TextField(controller: category, decoration: const InputDecoration(labelText: 'القسم / التصنيف', border: OutlineInputBorder())),
    const SizedBox(height: 10),
    DropdownButtonFormField<String>(value: language, decoration: const InputDecoration(labelText: 'لغة المحتوى'),
      items: const [DropdownMenuItem(value: 'العربية', child: Text('العربية')), DropdownMenuItem(value: 'الإنجليزية', child: Text('الإنجليزية'))],
      onChanged: (v) { if (v != null) setState(() => language = v); }),
    const SizedBox(height: 10),
    const ListTile(leading: Icon(Icons.verified_user_outlined), title: Text('حالة النشر: قيد المراجعة'), subtitle: Text('كل فيديو جديد يُرسل للمراجعة أولاً. النشر متاح للمدير بعد فحص المحتوى والمصدر.'),),
    const SizedBox(height: 10),
    const Text('رفع فيديو من الجهاز إلى مساحة تخزين شغف', style: TextStyle(fontWeight: FontWeight.bold)),
    OutlinedButton.icon(
      onPressed: busy ? null : chooseVideoFile,
      icon: const Icon(Icons.video_file_outlined),
      label: Text(selectedVideoFile == null ? 'اختيار ملف فيديو' : 'تغيير الفيديو المختار'),
    ),
    if (selectedVideoFile != null)
      Text('الملف: ${selectedVideoFile!.name} • ${(selectedVideoFile!.size / (1024 * 1024)).toStringAsFixed(1)} ميجابايت',
        style: const TextStyle(fontSize: 12, color: Colors.black54)),
    const SizedBox(height: 8),
    const Text('أو يمكنك إدخال رابط HTTPS مباشر لفيديو مستضاف بالفعل.'),
    TextField(controller: sourceUrl, keyboardType: TextInputType.url,
      onChanged: (value) { if (value.trim().isNotEmpty && selectedVideoFile != null) setState(() => selectedVideoFile = null); },
      decoration: const InputDecoration(labelText: 'رابط فيديو مباشر (اختياري عند رفع ملف)', border: OutlineInputBorder())),
    if (message != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(message!)),
    const SizedBox(height: 14),
    FilledButton.icon(onPressed: busy ? null : publish, icon: const Icon(Icons.publish),
      label: Text(busy ? 'جارٍ الإرسال...' : 'إرسال الفيديو للمراجعة')),
    const SizedBox(height: 8),
    const Text('تُرفع الملفات إلى مساحة تخزين شغف وتُسجل بياناتها في قاعدة البيانات، ولا تظهر للمشتركين إلا بعد اعتمادها ونشرها من المدير.',
      style: TextStyle(fontSize: 12, color: Colors.black54)),
    const Divider(height: 32),
    const Text('الفيديوهات المسجلة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
    if (existingVideos.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد فيديوهات مسجلة بعد.')),
    ...existingVideos.map((video) => Card(child: ListTile(
      title: Text(video['title']?.toString() ?? ''),
      subtitle: Text('الحالة: ${video['status']}  •  المشاهدات: ${video['views_count'] ?? 0}  •  الإعجابات: ${video['likes_count'] ?? 0}'),
      trailing: PopupMenuButton<String>(
        onSelected: (action) {
          if (action == 'delete') { deleteVideo(video); }
          else { changeVideoStatus(video, action); }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'published', child: Text('نشر الفيديو')),
          PopupMenuItem(value: 'pending', child: Text('إعادة للمراجعة')),
          PopupMenuItem(value: 'draft', child: Text('تحويل إلى مسودة')),
          PopupMenuItem(value: 'blocked', child: Text('حظر الفيديو')),
          PopupMenuItem(value: 'delete', child: Text('حذف الفيديو')),
        ],
      ),
    ))),
  ]);
}


class _ReportAdmin extends StatefulWidget {
  const _ReportAdmin();
  @override
  State<_ReportAdmin> createState() => _ReportAdminState();
}

class _ReportAdminState extends State<_ReportAdmin> {
  List<Map<String, dynamic>> reports = [];
  bool loading = true;
  String? error;
  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final rows = await Supabase.instance.client.from('content_reports')
        .select('id,video_id,comment_id,reason,status,created_at')
        .order('created_at', ascending: false).limit(100);
      if (mounted) setState(() => reports = List<Map<String, dynamic>>.from(rows));
    } catch (_) { if (mounted) setState(() => error = 'تعذر تحميل البلاغات.'); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> closeReport(Map<String, dynamic> report) async {
    try {
      await Supabase.instance.client.from('content_reports')
        .update({'status': 'closed'}).eq('id', report['id']);
      await load();
    } catch (_) { if (mounted) setState(() => error = 'تعذر تحديث البلاغ.'); }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(onRefresh: load,
    child: loading ? ListView(children: [LinearProgressIndicator()])
      : ListView(padding: const EdgeInsets.all(12), children: [
        const Text('بلاغات المحتوى', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        if (reports.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('لا توجد بلاغات مسجلة.')),
        ...reports.map((r) => Card(child: ListTile(
          title: Text(r['reason']?.toString() ?? ''),
          subtitle: Text('الحالة: ${r['status']}'),
          trailing: r['status'] == 'closed' ? const Icon(Icons.check_circle_outline)
            : IconButton(tooltip: 'إغلاق البلاغ', onPressed: () => closeReport(r), icon: const Icon(Icons.done)),
        ))),
      ]));
}

class _CommentAdmin extends StatefulWidget {
  const _CommentAdmin();
  @override
  State<_CommentAdmin> createState() => _CommentAdminState();
}

class _CommentAdminState extends State<_CommentAdmin> {
  List<Map<String, dynamic>> comments = [];
  bool loading = true;
  String? error;
  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final rows = await Supabase.instance.client.from('comments')
        .select('id, video_id, body, status, created_at').order('created_at', ascending: false).limit(100);
      if (mounted) setState(() => comments = List<Map<String, dynamic>>.from(rows));
    } catch (_) { if (mounted) setState(() => error = 'تعذر تحميل التعليقات.'); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> moderate(Map<String, dynamic> item, String status) async {
    try {
      await Supabase.instance.client.from('comments').update({'status': status}).eq('id', item['id']);
      await load();
    } catch (_) { if (mounted) setState(() => error = 'تعذر تحديث حالة التعليق.'); }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(onRefresh: load, child: loading
    ? ListView(children: [LinearProgressIndicator()])
    : ListView(padding: const EdgeInsets.all(12), children: [
      const Text('مراجعة التعليقات', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
      if (comments.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('لا توجد تعليقات حتى الآن.')),
      ...comments.map((c) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c['body']?.toString() ?? ''),
          const SizedBox(height: 6),
          Text('الحالة: ${c['status']}', style: const TextStyle(color: Colors.black54)),
          Wrap(children: [
            TextButton(onPressed: () => moderate(c, 'approved'), child: const Text('اعتماد')),
            TextButton(onPressed: () => moderate(c, 'rejected'), child: const Text('رفض')),
          ]),
        ],
      )))),
    ]));
}


class _SettingsAdmin extends StatefulWidget {
  const _SettingsAdmin();
  @override
  State<_SettingsAdmin> createState() => _SettingsAdminState();
}

class _SettingsAdminState extends State<_SettingsAdmin> {
  final welcome = TextEditingController();
  final announcement = TextEditingController();
  bool commentsEnabled = true;
  bool maintenanceMode = false;
  bool loading = true;
  bool saving = false;
  String? message;

  @override
  void initState() { super.initState(); load(); }

  @override
  void dispose() { welcome.dispose(); announcement.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() { loading = true; message = null; });
    try {
      final rows = await Supabase.instance.client.from('app_settings')
        .select('key,value');
      final settings = <String, dynamic>{
        for (final row in rows) row['key'].toString(): row['value'],
      };
      final w = settings['welcome_message'];
      final a = settings['announcement'];
      if (w is Map) welcome.text = (w['text'] ?? '').toString();
      if (a is Map) announcement.text = (a['text'] ?? '').toString();
      final c = settings['comments_enabled'];
      final m = settings['maintenance_mode'];
      if (mounted) setState(() {
        commentsEnabled = c is Map ? c['enabled'] != false : true;
        maintenanceMode = m is Map && m['enabled'] == true;
      });
    } catch (_) {
      if (mounted) setState(() => message = 'تعذر تحميل الإعدادات. تحقق من جدول app_settings وصلاحيات المدير.');
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> save() async {
    setState(() { saving = true; message = null; });
    try {
      final db = Supabase.instance.client;
      final actor = db.auth.currentUser?.id;
      final values = <String, Map<String, dynamic>>{
        'welcome_message': {'text': welcome.text.trim()},
        'announcement': {'text': announcement.text.trim()},
        'comments_enabled': {'enabled': commentsEnabled},
        'maintenance_mode': {'enabled': maintenanceMode},
      };
      for (final entry in values.entries) {
        await db.from('app_settings').upsert({
          'key': entry.key, 'value': entry.value, 'updated_by': actor,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      if (mounted) setState(() => message = 'تم حفظ إعدادات المنصة في قاعدة البيانات.');
    } catch (_) {
      if (mounted) setState(() => message = 'تعذر حفظ الإعدادات. تحقق من صلاحيات قاعدة البيانات.');
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('إعدادات المنصة', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    const Text('تُحفظ هذه الخيارات مركزيًا، ويجب أن تقرأها واجهات المشتركين لتطبيقها.'),
    if (loading) const LinearProgressIndicator(),
    const SizedBox(height: 12),
    TextField(controller: welcome, decoration: const InputDecoration(
      labelText: 'رسالة الترحيب', border: OutlineInputBorder())),
    const SizedBox(height: 12),
    TextField(controller: announcement, maxLines: 3, decoration: const InputDecoration(
      labelText: 'إعلان أو تنبيه عام', border: OutlineInputBorder())),
    SwitchListTile(title: const Text('السماح بالتعليقات افتراضيًا'),
      value: commentsEnabled, onChanged: (v) => setState(() => commentsEnabled = v)),
    SwitchListTile(title: const Text('وضع الصيانة'),
      subtitle: const Text('مفتاح إعداد إداري؛ يلزم أن تتحقق واجهة المشتركين منه قبل تفعيله فعليًا.'),
      value: maintenanceMode, onChanged: (v) => setState(() => maintenanceMode = v)),
    if (message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(message!, style: TextStyle(color: message!.startsWith('تم') ? _green : Colors.red))),
    FilledButton.icon(onPressed: saving || loading ? null : save,
      icon: const Icon(Icons.save_outlined), label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ الإعدادات')),
    const SizedBox(height: 8),
    OutlinedButton.icon(onPressed: loading ? null : load,
      icon: const Icon(Icons.refresh), label: const Text('إعادة تحميل الإعدادات')),
  ]);
}

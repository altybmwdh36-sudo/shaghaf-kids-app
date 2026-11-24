import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _green = Color(0xFF0B5B46);
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
bool get _backendConfigured => _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

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
    if (!_backendConfigured) {
      setState(() => error = 'لم يتم إعداد اتصال قاعدة البيانات بعد. يلزم إدخال مفاتيح المشروع في إعدادات البناء.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
      final client = Supabase.instance.client;
      await client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      final profile = await client.from('profiles').select('role').eq('id', client.auth.currentUser!.id).maybeSingle();
      if (profile?['role'] != 'admin') {
        await client.auth.signOut();
        throw const AuthException('هذا الحساب لا يملك صلاحية مدير التطبيق.');
      }
      if (mounted) setState(() => authorized = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on PostgrestException catch (e) {
      if (mounted) setState(() => error = 'تعذر التحقق من صلاحيات المدير: ${e.message}');
    } catch (e) {
      if (mounted) setState(() => error = 'تعذر الاتصال بالخادم. تحقق من إعداد قاعدة البيانات والإنترنت.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> signOut() async {
    if (_backendConfigured) await Supabase.instance.client.auth.signOut();
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
              ]),
            Expanded(child: IndexedStack(index: tab, children: const [
              _AdminStats(), _VideoAdmin(), _CommentAdmin(),
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
      if (mounted) setState(() => counts = {'المشتركون': members, 'الفيديوهات': videos, 'التعليقات': comments, 'تعليقات قيد المراجعة': pending});
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
      const Padding(padding: EdgeInsets.only(top: 12), child: Text('إحصاءات النشاط اليومي والأسبوعي والشهري تُضاف بعد تفعيل تسجيل الأحداث المركزي للمشتركين.',
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
  String language = 'العربية';
  String status = 'pending';
  Uint8List? bytes;
  String? fileName;
  bool busy = false;
  String? message;
  List<Map<String, dynamic>> existingVideos = [];

  @override
  void initState() { super.initState(); loadVideos(); }

  @override
  void dispose() { title.dispose(); description.dispose(); category.dispose(); sourceUrl.dispose(); super.dispose(); }

  Future<void> loadVideos() async {
    try {
      final rows = await Supabase.instance.client.from('videos')
        .select('id,title,status,created_at').order('created_at', ascending: false).limit(100);
      if (mounted) setState(() => existingVideos = List<Map<String, dynamic>>.from(rows));
    } catch (_) { if (mounted) setState(() => message = 'تعذر تحميل قائمة الفيديوهات.'); }
  }

  Future<void> changeVideoStatus(Map<String, dynamic> video, String status) async {
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

  Future<void> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: true);
    if (result != null && result.files.single.bytes != null) {
      setState(() { bytes = result.files.single.bytes; fileName = result.files.single.name; });
    }
  }

  Future<void> publish() async {
    if (title.text.trim().isEmpty || (bytes == null && sourceUrl.text.trim().isEmpty)) {
      setState(() => message = 'أدخل عنوان الفيديو واختر ملفًا أو رابطًا للفيديو.');
      return;
    }
    setState(() { busy = true; message = null; });
    try {
      final db = Supabase.instance.client;
      String? videoUrl = sourceUrl.text.trim().isEmpty ? null : sourceUrl.text.trim();
      if (bytes != null) {
        final path = '${DateTime.now().millisecondsSinceEpoch}_${fileName ?? 'video.mp4'}';
        await db.storage.from('shaghaf-videos').uploadBinary(path, bytes!,
          fileOptions: const FileOptions(contentType: 'video/mp4'));
        videoUrl = db.storage.from('shaghaf-videos').getPublicUrl(path);
      }
      await db.from('videos').insert({
        'title': title.text.trim(), 'description': description.text.trim(),
        'category': category.text.trim(), 'language': language,
        'video_url': videoUrl, 'status': status,
        'allow_comments': true, 'created_by': db.auth.currentUser!.id,
      });
      title.clear(); description.clear(); sourceUrl.clear();
      setState(() { bytes = null; fileName = null; message = 'تم حفظ الفيديو في قاعدة البيانات.'; });
      await loadVideos();
    } catch (e) {
      setState(() => message = 'تعذر نشر الفيديو. تحقق من إعداد التخزين والصلاحيات.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('نشر فيديو جديد', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
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
    DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'حالة الفيديو'),
      items: const [DropdownMenuItem(value: 'pending', child: Text('قيد المراجعة')), DropdownMenuItem(value: 'draft', child: Text('مسودة')), DropdownMenuItem(value: 'published', child: Text('نشر مباشر'))],
      onChanged: (v) { if (v != null) setState(() => status = v); }),
    const SizedBox(height: 10),
    OutlinedButton.icon(onPressed: pickVideo, icon: const Icon(Icons.video_file), label: Text(fileName ?? 'اختيار ملف فيديو')),
    const Center(child: Text('أو أدخل رابط فيديو موثوق')),
    TextField(controller: sourceUrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'رابط الفيديو', border: OutlineInputBorder())),
    if (message != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(message!)),
    const SizedBox(height: 14),
    FilledButton.icon(onPressed: busy ? null : publish, icon: const Icon(Icons.publish),
      label: Text(busy ? 'جارٍ الحفظ...' : 'حفظ ونشر الفيديو')),
    const SizedBox(height: 8),
    const Text('الملفات ترفع إلى التخزين المركزي، وتظهر المواد ذات حالة «منشور» بعد ربط واجهة المشتركين بالمكتبة المركزية.',
      style: TextStyle(fontSize: 12, color: Colors.black54)),
    const Divider(height: 32),
    const Text('الفيديوهات المسجلة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
    if (existingVideos.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد فيديوهات مسجلة بعد.')),
    ...existingVideos.map((video) => Card(child: ListTile(
      title: Text(video['title']?.toString() ?? ''),
      subtitle: Text('الحالة الحالية: ${video['status']}'),
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
    ? const ListView(children: [LinearProgressIndicator()])
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

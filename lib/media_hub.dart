import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend.dart';

const _green = Color(0xFF0B5B46);

class MediaHubScreen extends StatefulWidget {
  const MediaHubScreen({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  State<MediaHubScreen> createState() => _MediaHubScreenState();
}

class _MediaHubScreenState extends State<MediaHubScreen> {
  int section = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      VideoLibraryScreen(initialQuery: widget.initialQuery),
      const AudioLibraryScreen(),
      const NotesLibraryScreen(),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(
            children: [
              Expanded(child: _HubTile(
                icon: Icons.video_library_outlined,
                title: 'الفيديو',
                selected: section == 0,
                onTap: () => setState(() => section = 0),
              )),
              const SizedBox(width: 8),
              Expanded(child: _HubTile(
                icon: Icons.headphones_outlined,
                title: 'الصوت',
                selected: section == 1,
                onTap: () => setState(() => section = 1),
              )),
              const SizedBox(width: 8),
              Expanded(child: _HubTile(
                icon: Icons.edit_note,
                title: 'الكتابة',
                selected: section == 2,
                onTap: () => setState(() => section = 2),
              )),
            ],
          ),
        ),
        Expanded(child: IndexedStack(index: section, children: pages)),
      ],
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE1F0E8) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? _green : Colors.black12),
      ),
      child: Column(
        children: [
          Icon(icon, color: _green),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

class ShaghafVideo {
  const ShaghafVideo({required this.title, required this.description, required this.category, required this.thumbnail, required this.videoUrl, required this.sourceName});
  final String title, description, category, thumbnail, videoUrl, sourceName;
}

const _shaghafVideos = <ShaghafVideo>[
  ShaghafVideo(
    title: 'كيف نطلق المركبات إلى الفضاء؟',
    description: 'تعرّف إلى الصواريخ وكيف تحمل الأقمار والمركبات إلى الفضاء',
    category: 'الفضاء',
    thumbnail: '',
    videoUrl: 'https://spaceplace.nasa.gov/review/launching-into-space/how-do-we-launch-things-into-space_1920x1080.mp4',
    sourceName: 'NASA Space Place • الإنجليزية',
  ),
  ShaghafVideo(
    title: 'ما هو الكسوف الشمسي؟',
    description: 'شرح مصوّر لكيفية مرور القمر بين الشمس والأرض',
    category: 'العلوم',
    thumbnail: '',
    videoUrl: 'https://spaceplace.nasa.gov/review/eclipse-snap/what-is-a-solar-eclipse_1920x1080.mp4',
    sourceName: 'NASA Space Place • الإنجليزية',
  ),
  ShaghafVideo(
    title: 'هل توجد كواكب تشبه الأرض؟',
    description: 'اكتشف الكواكب التي تدور حول نجوم بعيدة وكيف يبحث العلماء عنها',
    category: 'الفضاء',
    thumbnail: '',
    videoUrl: 'https://spaceplace.nasa.gov/review/exoplanet-snap/searching-for-other-planets-like-ours_1920x1080.mp4',
    sourceName: 'NASA Space Place • الإنجليزية',
  ),
  ShaghafVideo(
    title: 'كمية الماء على كوكب الأرض',
    description: 'حقائق علمية مصوّرة عن المياه المالحة والعذبة على كوكبنا',
    category: 'الطبيعة',
    thumbnail: '',
    videoUrl: 'https://spaceplace.nasa.gov/review/water/how-much-water-is-on-earth_1920x1080.mp4',
    sourceName: 'NASA Space Place • الإنجليزية',
  ),
];

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key, this.initialQuery = ''});
  final String initialQuery;
  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  String category = 'الكل';
  String query = '';
  final TextEditingController searchController = TextEditingController();
  List<ShaghafVideo> remoteVideos = [];
  bool loadingRemote = false;
  bool hasMoreRemote = false;
  static const int _pageSize = 30;
  bool connected = false;
  String? connectionMessage;

  @override
  void initState() {
    super.initState();
    query = widget.initialQuery;
    searchController.text = query;
    refreshOnlineVideos();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> refreshOnlineVideos({bool loadMore = false}) async {
    if (!shaghafBackendReady) {
      if (mounted) setState(() {
        connected = false;
        connectionMessage = 'المكتبة المحلية متاحة؛ ربط المكتبة المباشرة يتطلب إعداد خادم شغف.';
      });
      return;
    }
    if (loadingRemote) return;
    if (mounted) setState(() { loadingRemote = true; connectionMessage = null; });
    try {
      final rows = await Supabase.instance.client.rpc('search_published_videos', params: {
        'p_query': query.trim(),
        'p_category': category == 'الكل' ? null : category,
        'p_limit': _pageSize,
        'p_offset': loadMore ? remoteVideos.length : 0,
      }) as List<dynamic>;
      final items = rows.map<ShaghafVideo>((row) {
        final data = Map<String, dynamic>.from(row);
        return ShaghafVideo(
          title: (data['title'] ?? '').toString(),
          description: (data['description'] ?? '').toString(),
          category: (data['category'] ?? 'متنوع').toString(),
          thumbnail: '',
          videoUrl: (data['video_url'] ?? '').toString(),
          sourceName: 'مكتبة شغف • ${data['language'] ?? 'العربية'}',
        );
      }).where((video) => video.title.isNotEmpty && video.videoUrl.startsWith('https://')).toList();
      if (mounted) setState(() {
        remoteVideos = loadMore ? [...remoteVideos, ...items] : items;
        hasMoreRemote = items.length == _pageSize;
        connected = true;
      });
    } catch (_) {
      if (mounted) setState(() {
        connected = false;
        connectionMessage = 'تعذر تحديث المكتبة الآن. اعرض المحتوى المتاح وحاول التحديث لاحقاً.';
      });
    } finally {
      if (mounted) setState(() => loadingRemote = false);
    }
  }

  List<ShaghafVideo> get allVideos => [...remoteVideos, ..._shaghafVideos];

  List<ShaghafVideo> get filteredVideos {
    final q = query.trim().toLowerCase();
    return allVideos.where((video) {
      final categoryMatch = category == 'الكل' || video.category == category;
      final text = '${video.title} ${video.description} ${video.category} ${video.sourceName}'.toLowerCase();
      return categoryMatch && (q.isEmpty || text.contains(q));
    }).toList();
  }

  Future<void> openVideo(ShaghafVideo video) async {
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.black,
      builder: (context) => _ShaghafVideoPlayer(video: video),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = filteredVideos;
    final categories = ['الكل', ...{..._shaghafVideos.map((v) => v.category), ...remoteVideos.map((v) => v.category)}];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: refreshOnlineVideos,
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('اكتشف وشاهد', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(connected ? 'متصل بالإنترنت • مكتبة شغف المحدّثة' : 'مقاطع مختارة مع إمكانية تحديث المكتبة عند الاتصال', style: const TextStyle(color: Colors.black54)),
                if (loadingRemote) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
                if (connectionMessage != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(connectionMessage!, style: const TextStyle(color: Colors.orange, fontSize: 12))),
                const SizedBox(height: 14),
                TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => query = value),
                  onSubmitted: (_) => refreshOnlineVideos(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'ابحث في مكتبة شغف على الإنترنت...', prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => refreshOnlineVideos()),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: categories.map((item) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(label: Text(item), selected: category == item, onSelected: (_) { setState(() => category = item); refreshOnlineVideos(); }),
                    )).toList(),
                  ),
                ),
              ]),
            ),
          ),
          if (videos.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                final video = videos[index];
                return Card(
                  clipBehavior: Clip.antiAlias, margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () => openVideo(video),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(fit: StackFit.expand, children: [
                          video.thumbnail.isEmpty
                              ? Container(color: const Color(0xFF102C43), child: const Icon(Icons.public, color: Colors.white, size: 64))
                              : Image.network(video.thumbnail, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFF102C43), child: const Icon(Icons.public, color: Colors.white, size: 64))),
                          Container(color: Colors.black.withValues(alpha: 0.16)),
                          const Center(child: CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Icon(Icons.play_arrow_rounded, size: 42, color: _green))),
                          Positioned(bottom: 10, right: 10, child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                            child: const Text('شاهد الآن', style: TextStyle(color: Colors.white, fontSize: 11)),
                          )),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const CircleAvatar(backgroundColor: Color(0xFFE1F0E8), child: Icon(Icons.rocket_launch, color: _green)),
                          const SizedBox(width: 11),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(video.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 5),
                            Text(video.description, style: const TextStyle(color: Colors.black54, height: 1.4)),
                            const SizedBox(height: 7),
                            Text('\${video.sourceName}  •  \${video.category}', style: const TextStyle(color: _green, fontSize: 11)),
                          ])),
                          const Icon(Icons.more_vert),
                        ]),
                      ),
                    ]),
                  ),
                );
              }, childCount: videos.length)),
            )
          if (hasMoreRemote)
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: OutlinedButton.icon(
                onPressed: loadingRemote ? null : () => refreshOnlineVideos(loadMore: true),
                icon: const Icon(Icons.expand_more),
                label: Text(loadingRemote ? 'جارٍ التحميل...' : 'تحميل المزيد من الإنترنت'),
              ),
            )),
          if (videos.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('لا توجد نتائج منشورة مطابقة في مكتبة شغف حالياً'))),
          const SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 22),
            child: Text('تُحدّث مكتبة الفيديوهات من خادم شغف، ولا يظهر فيها إلا المحتوى الذي اعتمده المشرفون بعد مراجعة المصدر واللغة وملاءمة العمر.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.5)),
          )),
        ],
      ),
      ),
    );
  }
}

class _ShaghafVideoPlayer extends StatefulWidget {
  const _ShaghafVideoPlayer({required this.video});
  final ShaghafVideo video;
  @override
  State<_ShaghafVideoPlayer> createState() => _ShaghafVideoPlayerState();
}

class _ShaghafVideoPlayerState extends State<_ShaghafVideoPlayer> {
  VideoPlayerController? controller;
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); initializeVideo(); }

  Future<void> initializeVideo() async {
    final next = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
    try {
      await next.initialize();
      await next.setLooping(false);
      if (!mounted) { await next.dispose(); return; }
      setState(() { controller = next; loading = false; });
      await next.play();
    } catch (_) {
      await next.dispose();
      if (mounted) setState(() { loading = false; error = 'تعذّر تحميل الفيديو. تحقق من اتصال الإنترنت وحاول مجدداً.'; });
    }
  }

  @override
  void dispose() { controller?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final player = controller;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
            child: Row(children: [
              const Icon(Icons.play_circle, color: Colors.white), const SizedBox(width: 8),
              const Expanded(child: Text('مشغّل شغف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),
          Expanded(child: Center(
            child: loading ? const CircularProgressIndicator(color: Colors.white)
              : error != null ? Padding(padding: const EdgeInsets.all(24), child: Text(error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center))
              : player != null && player.value.isInitialized ? AspectRatio(aspectRatio: player.value.aspectRatio, child: VideoPlayer(player))
              : const SizedBox.shrink(),
          )),
          if (player != null && player.value.isInitialized)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
              child: Column(children: [
                VideoProgressIndicator(player, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Color(0xFF66D6A8), bufferedColor: Colors.white38, backgroundColor: Colors.white24)),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(onPressed: () => player.seekTo(player.value.position - const Duration(seconds: 10)), icon: const Icon(Icons.replay_10, color: Colors.white)),
                  IconButton.filled(onPressed: () => setState(() { player.value.isPlaying ? player.pause() : player.play(); }), icon: Icon(player.value.isPlaying ? Icons.pause : Icons.play_arrow)),
                  IconButton(onPressed: () => player.seekTo(player.value.position + const Duration(seconds: 10)), icon: const Icon(Icons.forward_10, color: Colors.white)),
                ]),
                const SizedBox(height: 4),
                Text(widget.video.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('المصدر: \${widget.video.sourceName}', style: const TextStyle(color: Colors.white60, fontSize: 11), textAlign: TextAlign.center),
              ]),
            ),
        ]),
      ),
    );
  }
}

class AudioLibraryScreen extends StatefulWidget {
  const AudioLibraryScreen({super.key});
  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen> {
  final FlutterTts tts = FlutterTts();
  int? playingIndex;
  bool speaking = false;
  final lessons = const <Map<String, String>>[
    {'title': 'رحلة إلى الفضاء', 'category': 'الفضاء', 'body': 'الفضاء واسع جداً، وفيه نجوم وكواكب ومجرات. تدور الأرض حول الشمس، ويستغرق دورانها دورة كاملة سنة واحدة. أما القمر فيدور حول الأرض، ونراه بأشكال مختلفة خلال الشهر.'},
    {'title': 'أسرار الماء على الأرض', 'category': 'الطبيعة', 'body': 'الماء أساس الحياة. تغطي المياه معظم سطح الأرض، ومعظمها ماء مالح في المحيطات. نحتاج إلى الماء العذب للشرب والزراعة، لذلك علينا المحافظة عليه وعدم الإسراف فيه.'},
    {'title': 'كيف يعمل العقل أثناء التعلم؟', 'category': 'التعليم', 'body': 'يتعلم العقل عندما ننتبه ونفهم ونتدرب. يساعد النوم الجيد والتكرار والراحة القصيرة على تثبيت المعلومات. وإذا أخطأنا، نستطيع أن نتعلم من الخطأ ونحاول مرة أخرى.'},
    {'title': 'قيمة الصدق', 'category': 'القيم', 'body': 'الصدق أن نقول الحقيقة ونحافظ على الأمانة في كلامنا وأعمالنا. الشخص الصادق يكسب ثقة الناس، ويشعر بالطمأنينة لأنه لا يحتاج إلى إخفاء الحقيقة.'},
  ];

  @override
  void initState() {
    super.initState();
    tts.setLanguage('ar');
    tts.setSpeechRate(0.45);
    tts.setCompletionHandler(() {
      if (mounted) setState(() { speaking = false; playingIndex = null; });
    });
    tts.setCancelHandler(() {
      if (mounted) setState(() { speaking = false; playingIndex = null; });
    });
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  Future<void> playLesson(int index) async {
    if (playingIndex == index && speaking) {
      await tts.stop();
      if (mounted) setState(() { speaking = false; playingIndex = null; });
      return;
    }
    await tts.stop();
    if (mounted) setState(() { playingIndex = index; speaking = true; });
    try {
      await tts.speak(lessons[index]['body']!);
    } catch (_) {
      if (mounted) setState(() { speaking = false; playingIndex = null; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تشغيل القراءة الصوتية. تأكد من توفر صوت عربي على الجهاز.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('المكتبة الصوتية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('استمع إلى دروس قصيرة باللغة العربية. تُقرأ النصوص بصوت الجهاز.'),
        const SizedBox(height: 12),
        ...List.generate(lessons.length, (index) {
          final lesson = lessons[index];
          final active = playingIndex == index && speaking;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE1F0E8),
                child: Icon(active ? Icons.graphic_eq : Icons.headphones, color: _green),
              ),
              title: Text(lesson['title']!, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(lesson['category']!),
              trailing: IconButton(
                tooltip: active ? 'إيقاف' : 'استمع',
                onPressed: () => playLesson(index),
                icon: Icon(active ? Icons.stop_circle : Icons.play_circle_fill, color: _green, size: 32),
              ),
              onTap: () => playLesson(index),
            ),
          );
        }),
        const SizedBox(height: 12),
        const Text('ملاحظة: جودة الصوت وتوفر النطق العربي يعتمدان على محرك تحويل النص إلى كلام المثبّت في الهاتف.'),
      ],
    ),
  );
}

class NotesLibraryScreen extends StatefulWidget {
  const NotesLibraryScreen({super.key});

  @override
  State<NotesLibraryScreen> createState() => _NotesLibraryScreenState();
}

class _NotesLibraryScreenState extends State<NotesLibraryScreen> {
  List<Map<String, String>> notes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    restoreNotes();
  }

  Future<void> restoreNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('shaghaf_notes') ?? '[]';
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      notes = decoded.map((item) => Map<String, String>.from(item as Map)).toList();
    } catch (_) {
      notes = [];
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> persistNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shaghaf_notes', jsonEncode(notes));
  }

  Future<void> editNote({Map<String, String>? existing, int? index}) async {
    final titleController = TextEditingController(text: existing?['title'] ?? '');
    final bodyController = TextEditingController(text: existing?['body'] ?? '');
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(existing == null ? 'كتابة جديدة' : 'تعديل الكتابة'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bodyController,
                  minLines: 5,
                  maxLines: 9,
                  decoration: const InputDecoration(
                    labelText: 'اكتب فكرتك أو قصتك أو ملاحظتك',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (bodyController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, {
                  'title': titleController.text.trim().isEmpty ? 'كتابة بلا عنوان' : titleController.text.trim(),
                  'body': bodyController.text.trim(),
                });
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    bodyController.dispose();
    if (result == null) return;
    setState(() {
      if (index == null) {
        notes.insert(0, result);
      } else {
        notes[index] = result;
      }
    });
    await persistNotes();
  }

  Future<void> deleteNote(int index) async {
    setState(() => notes.removeAt(index));
    await persistNotes();
  }

  @override
  Widget build(BuildContext context) => loading
      ? const Center(child: CircularProgressIndicator())
      : Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('دفتر أفكاري', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  FilledButton.icon(
                    onPressed: () => editNote(),
                    icon: const Icon(Icons.add),
                    label: const Text('كتابة جديدة'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notes.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('ابدأ بكتابة قصة أو فكرة أو ملاحظة. سيتم حفظ كتاباتك على هذا الجهاز.'),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE1F0E8),
                              child: Icon(Icons.edit_note, color: _green),
                            ),
                            title: Text(note['title'] ?? ''),
                            subtitle: Text(
                              note['body'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => editNote(existing: note, index: index),
                            trailing: IconButton(
                              tooltip: 'حذف',
                              onPressed: () => deleteNote(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
}

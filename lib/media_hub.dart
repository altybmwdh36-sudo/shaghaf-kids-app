import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

const _green = Color(0xFF0B5B46);

class MediaHubScreen extends StatefulWidget {
  const MediaHubScreen({super.key});

  @override
  State<MediaHubScreen> createState() => _MediaHubScreenState();
}

class _MediaHubScreenState extends State<MediaHubScreen> {
  int section = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const VideoLibraryScreen(),
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
    title: 'رحلة ممتعة عبر المجموعة الشمسية',
    description: 'جولة بصرية بين الشمس والكواكب للتعرّف إلى عالمنا الفضائي',
    category: 'الفضاء',
    thumbnail: 'https://svs.gsfc.nasa.gov/vis/a020000/a020300/a020391/SolarSystemFlythrough_422ProRes.00001_searchweb.png',
    videoUrl: 'https://svs.gsfc.nasa.gov/vis/a020000/a020300/a020391/SolarSystemFlythrough_1080.mp4',
    sourceName: 'NASA – Goddard Space Flight Center',
  ),
];

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key});
  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  String category = 'الكل';
  String query = '';

  List<ShaghafVideo> get filteredVideos => _shaghafVideos.where((video) {
    final categoryMatch = category == 'الكل' || video.category == category;
    final q = query.trim();
    return categoryMatch && (q.isEmpty || video.title.contains(q) || video.description.contains(q) || video.category.contains(q));
  }).toList();

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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('اكتشف وشاهد', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text('مقاطع معرفية مختارة بعناية من مصادر موثوقة', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن فيديو أو موضوع...', prefixIcon: const Icon(Icons.search),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ['الكل', 'الفضاء', 'العلوم', 'الطبيعة', 'التعليم'].map((item) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(label: Text(item), selected: category == item, onSelected: (_) => setState(() => category = item)),
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
                          Image.network(video.thumbnail, fit: BoxFit.cover,
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
          else
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('لا توجد فيديوهات في هذا التصنيف حالياً'))),
          const SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 22),
            child: Text('تُضاف المقاطع إلى مكتبة شغف بعد التحقق من مصدرها ومناسبتها. هذه بداية المكتبة، وستتوسع مع اعتماد مصادر إضافية.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.5)),
          )),
        ],
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
  final urlController = TextEditingController();
  final player = AudioPlayer();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    urlController.dispose();
    player.dispose();
    super.dispose();
  }

  Future<void> loadAudio() async {
    final uri = Uri.tryParse(urlController.text.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(() => error = 'أدخل رابط ملف صوتي مباشر يبدأ بـ https://');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await player.setUrl(uri.toString());
      await player.play();
      if (mounted) setState(() => loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'تعذّر تشغيل الملف الصوتي. تحقق من الرابط وصيغة الملف.';
        });
      }
    }
  }

  String formatTime(Duration? duration) {
    if (duration == null) return '00:00';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('المكتبة الصوتية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('مشغّل للدروس والقصص والمواد الصوتية من روابط مباشرة.'),
      const SizedBox(height: 16),
      TextField(
        controller: urlController,
        keyboardType: TextInputType.url,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(
          labelText: 'رابط ملف صوتي مباشر',
          hintText: 'https://example.com/audio.mp3',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.link),
        ),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: loading ? null : loadAudio,
        icon: const Icon(Icons.headphones),
        label: Text(loading ? 'جارٍ التحميل...' : 'تحميل وتشغيل الصوت'),
      ),
      if (error != null) Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      ),
      const SizedBox(height: 22),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.graphic_eq, size: 54, color: _green),
              const SizedBox(height: 8),
              const Text('مشغّل شغف الصوتي', style: TextStyle(fontWeight: FontWeight.bold)),
              StreamBuilder<Duration?>(
                stream: player.durationStream,
                builder: (context, snapshot) {
                  final duration = snapshot.data ?? Duration.zero;
                  return StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (context, positionSnapshot) {
                      final position = positionSnapshot.data ?? Duration.zero;
                      final max = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
                      final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();
                      return Column(
                        children: [
                          Slider(
                            value: value,
                            max: max,
                            onChanged: duration == Duration.zero
                                ? null
                                : (v) => player.seek(Duration(milliseconds: v.round())),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formatTime(position)),
                              Text(formatTime(duration)),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              StreamBuilder<PlayerState>(
                stream: player.playerStateStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => player.seek(Duration.zero),
                        icon: const Icon(Icons.stop_circle_outlined),
                      ),
                      IconButton.filled(
                        onPressed: () => playing ? player.pause() : player.play(),
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Text('ستظهر هنا لاحقاً مكتبة شغف الصوتية بعد اعتماد المواد ومصادرها.'),
    ],
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

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

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  final urlController = TextEditingController();
  VideoPlayerController? controller;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    urlController.dispose();
    controller?.dispose();
    super.dispose();
  }

  Future<void> loadVideo() async {
    final uri = Uri.tryParse(urlController.text.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      setState(() => error = 'أدخل رابط فيديو مباشر يبدأ بـ https://');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    final old = controller;
    controller = null;
    await old?.dispose();
    final next = VideoPlayerController.networkUrl(uri);
    try {
      await next.initialize();
      await next.setLooping(false);
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() {
        controller = next;
        loading = false;
      });
      await next.play();
    } catch (_) {
      await next.dispose();
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'تعذّر تشغيل هذا الرابط. تأكد أنه رابط فيديو مباشر ومدعوم.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = controller;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('مكتبة الفيديو', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('مشغّل فيديو فعلي للروابط المباشرة. ستضاف مكتبة شغف المنتقاة عند تجهيز مصادر المحتوى.'),
        const SizedBox(height: 16),
        TextField(
          controller: urlController,
          keyboardType: TextInputType.url,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'رابط فيديو مباشر',
            hintText: 'https://example.com/video.mp4',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: loading ? null : loadVideo,
          icon: const Icon(Icons.play_arrow),
          label: Text(loading ? 'جارٍ تجهيز الفيديو...' : 'تشغيل الفيديو'),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        if (loading) const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        if (player != null && player.value.isInitialized) ...[
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: player.value.aspectRatio,
              child: VideoPlayer(player),
            ),
          ),
          VideoProgressIndicator(player, allowScrubbing: true, padding: const EdgeInsets.symmetric(vertical: 12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'إعادة عشر ثوانٍ',
                onPressed: () => player.seekTo(player.value.position - const Duration(seconds: 10)),
                icon: const Icon(Icons.replay_10),
              ),
              IconButton.filled(
                tooltip: player.value.isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                onPressed: () => setState(() {
                  player.value.isPlaying ? player.pause() : player.play();
                }),
                icon: Icon(player.value.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                tooltip: 'تقديم عشر ثوانٍ',
                onPressed: () => player.seekTo(player.value.position + const Duration(seconds: 10)),
                icon: const Icon(Icons.forward_10),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: _green),
                SizedBox(width: 10),
                Expanded(child: Text('هذه المرحلة توفر المشغّل. لم نضف بعد قناة فيديو عامة أو قائمة مقاطع؛ يجب اعتماد مصادر موثوقة ومراجعة محتواها أولاً.')),
              ],
            ),
          ),
        ),
      ],
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

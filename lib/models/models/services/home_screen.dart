import 'package:flutter/material.dart';
import '../models/member_session.dart';
import '../models/video_item.dart';
import '../services/catalog_service.dart';
import '../services/user_library_service.dart';

class HomeScreen extends StatefulWidget {
  final MemberSession session;
  final Future<void> Function() onLogout;

  const HomeScreen({
    super.key,
    required this.session,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CatalogService _catalogService = CatalogService();
  final UserLibraryService _libraryService = UserLibraryService();

  final TextEditingController _searchController = TextEditingController();
  String _selectedAgeKey = 'all_ages';
  String _selectedPillar = 'الكل';
  int _selectedNavIndex = 0;

  Set<String> _favoriteIds = {};
  List<String> _historyIds = [];
  List> _customItems = [];
  bool _isLoadingLibrary = true;

  static const List<String> _pillars = [
    'الكل',
    'أخي وقرآن',
    'قصص الأنبياء والصحابة',
    'الولاعة والخلقة',
    'الثقة بالله والإيمان وحب الآخرين',
    'علوم وثقافة',
    'المذاكرة وحب الدراسة والاختراع',
    'بناء الشخصية والقيادة والإقناع والنجاح',
    'فكاهة هادفة وبريئة',
  ];

  static const Map<String, String> _ageFilterLabels = {
    'all_ages': 'حتى 20 سنة (الكل)',
    'kids_under_12': 'أطفال حتى 12 سنة',
    'youth_13_to_20': 'ناشئة (13 - 20)',
  };

  @override
  void initState() {
    super.initState();
    _selectedAgeKey = widget.session.ageGroupKey;
    _loadLibraryData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLibraryData() async {
    final favs = await _libraryService.loadFavoriteIds();
    final hist = await _libraryService.loadHistoryIds();
    final customs = await _libraryService.loadCustomItems();
    if (!mounted) return;
    setState(() {
      _favoriteIds = favs;
      _historyIds = hist;
      _customItems = customs;
      _isLoadingLibrary = false;
    });
  }

  List<VideoItem> get _filteredItems {
    final allClean = _catalogService.getAllCleanItems(
      ageGroupKey: _selectedAgeKey,
      query: _searchController.text,
      customItems: _customItems,
    );

    return allClean.where((item) {
      if (_selectedPillar != 'الكل' &&
          item.category != _selectedPillar &&
          !item.matchedPillars.contains(_selectedPillar)) {
        return false;
      }
      if (_selectedNavIndex == 1 && !_favoriteIds.contains(item.id)) {
        return false;
      }
      if (_selectedNavIndex == 2 && !_historyIds.contains(item.id)) {
        return false;
      }
      if (_selectedNavIndex == 3 && !item.isShortClip) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _onToggleFavorite(VideoItem item) async {
    final updated = await _libraryService.toggleFavorite(item.id);
    if (!mounted) return;
    setState(() => _favoriteIds = updated);
  }

  Future<void> _onOpenVideo(VideoItem item) async {
    final updatedHistory = await _libraryService.recordWatch(item.id);
    if (!mounted) return;
    setState(() => _historyIds = updatedHistory);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final isFav = _favoriteIds.contains(item.id);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF0B3B2E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.auditStatus,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B3B2E),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text('المصدر: ${item.sourceName}')),
                    Chip(label: Text('المدة: ${item.durationMinutes} د')),
                    ...item.matchedPillars.map((p) => Chip(label: Text(p))),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7F4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'رابط المشاهدة المعتمد:\n${item.watchUrl}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _onToggleFavorite(item);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                        ),
                        label: Text(isFav ? 'إزالة من المفضلة' : 'إضافة للمفضلة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B3B2E),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddCustomItemDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String chosenPillar = 'علوم وثقافة';

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إضافة محتوى نظيف جديد (وضع المالك)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان المادة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'وصف مختصر',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رابط المشاهدة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: chosenPillar,
                    decoration: const InputDecoration(
                      labelText: 'القسم التربوي',
                      border: OutlineInputBorder(),
                    ),
                    items: _pillars
                        .where((p) => p != 'الكل')
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) chosenPillar = val;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  final newItem = {
                    'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    'title': titleCtrl.text.trim(),
                    'description': descCtrl.text.trim().isEmpty
                        ? 'محتوى تربوي وقيمي مضاف عبر وضع المالك.'
                        : descCtrl.text.trim(),
                    'sourceName': 'إضافة مالك منصة شَغَف',
                    'sourceType': 'educational_platform',
                    'watchUrl': urlCtrl.text.trim().isEmpty
                        ? 'https://www.youtube.com/watch?v=5qap5aO4i9A'
                        : urlCtrl.text.trim(),
                    'embedUrl': '',
                    'thumbnailUrl': '',
                    'category': chosenPillar,
                    'ageGroup': 'all_ages',
                    'durationMinutes': 4,
                    'durationSeconds': 240,
                    'isShortClip': false,
                    'liveOnlineStream': true,
                    'purityScore': 0.99,
                    'alignmentScore': 0.98,
                    'matchedPillars': [chosenPillar],
                    'auditStatus': 'معتمد احترافياً',
                    'isVerifiedClean': true,
                  };
                  final updated = await _libraryService.addCustomItem(newItem);
                  if (!mounted) return;
                  setState(() => _customItems = updated);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('حفظ وإضافة'),
              ),
            ],
          ),
        );
      },
    );

    titleCtrl.dispose();
    descCtrl.dispose();
    urlCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B3B2E),
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'منصة «شَغَف» (حتى 20 سنة)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '${widget.session.guardianOrMemberName} • اشتراك مجاني مفعّل',
                style: const TextStyle(fontSize: 11, color: Color(0xFFD4AF37)),
              ),
            ],
          ),
          actions: [
            if (widget.session.isOwnerMode)
              IconButton(
                tooltip: 'إضافة مادة جديدة',
                onPressed: _showAddCustomItemDialog,
                icon: const Icon(Icons.add_circle_outline),
              ),
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: _isLoadingLibrary
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    color: const Color(0xFFF0F7F4),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'ابحث في الأقسام، العلوم، القصص، أو المذاكرة...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _ageFilterLabels.entries.map((entry) {
                              final selected = _selectedAgeKey == entry.key;
                              return Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChoiceChip(
                                  label: Text(entry.value),
                                  selected: selected,
                                  onSelected: (_) {
                                    setState(() => _selectedAgeKey = entry.key);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _pillars.length,
                      itemBuilder: (context, index) {
                        final pillar = _pillars[index];
                        final selected = _selectedPillar == pillar;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: FilterChip(
                            label: Text(pillar, style: const TextStyle(fontSize: 12)),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _selectedPillar = pillar);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد مواد مطابقة للتصفية الحالية',
                              style: TextStyle(fontSize: 15),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final isFav = _favoriteIds.contains(item.id);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF0B3B2E),
                                    child: Icon(
                                      item.isShortClip
                                          ? Icons.bolt_rounded
                                          : Icons.play_arrow_rounded,
                                      color: const Color(0xFFD4AF37),
                                    ),
                                  ),
                                  title: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        item.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${item.sourceName} • ${item.durationMinutes} د',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF145A46),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    onPressed: () => _onToggleFavorite(item),
                                    icon: Icon(
                                      isFav ? Icons.favorite : Icons.favorite_border,
                                      color: isFav ? Colors.red : null,
                                    ),
                                  ),
                                  onTap: () => _onOpenVideo(item),
                                ),
                              );
                            },
                          ),
                  ),
                ],
 

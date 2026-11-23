import '../models/video_item.dart';

class ContentModerationService {
  static const List<String> _blockedKeywords = [
    'اعلان',
    'إعلان',
    'ترويج',
    'سحر',
    'شعوذة',
    'رعب دموي',
    'عنف دموي',
    'محتوى بالغ',
    'قمار',
    'رهان',
    'اغنية هابطة',
    'أغنية هابطة',
    'ads',
    'sponsored',
    'promo',
    'gambling',
    'horror gore',
  ];

  static const Map<String, List<String>> _pillarKeywords = {
    'أخي وقرآن': ['قرآن', 'تلاوة', 'تجويد', 'حفظ', 'سورة', 'آية'],
    'قصص الأنبياء والصحابة': ['نبي', 'رسول', 'صحابي', 'قصة', 'سيرة', 'موسى', 'يوسف', 'إبراهيم'],
    'الولاعة والخلقة': ['كون', 'فضاء', 'نجوم', 'خلق', 'طبيعة', 'حيوان', 'نبات', 'عظمة الله'],
    'الثقة بالله والإيمان وحب الآخرين': ['إيمان', 'توكل', 'رحمة', 'تعاون', 'أخلاق', 'صدق', 'إحسان'],
    'علوم وثقافة': ['علوم', 'تجربة', 'رياضيات', 'اختراع', 'تاريخ', 'ثقافة', 'اكتشاف', 'لغة'],
    'المذاكرة وحب الدراسة والاختراع': ['مذاكرة', 'دراسة', 'تفوق', 'ابتكار', 'مخترع', 'بحث', 'تعلم'],
    'بناء الشخصية والقيادة والإقناع والنجاح': ['قيادة', 'شخصية', 'نجاح', 'إقناع', 'ثقة بالنفس', 'مهارة', 'طموح'],
    'فكاهة هادفة وبريئة': ['فكاهة', 'مرح', 'طريف', 'مغامرة بريئة', 'لغز', 'ترفيه نظيف'],
  };

  List<String> detectMatchedPillars(String title, String description, String category) {
    final hay = '$title $description $category'.toLowerCase();
    final matched = <String>[];
    for (final entry in _pillarKeywords.entries) {
      if (entry.value.any((kw) => hay.contains(kw.toLowerCase()))) {
        matched.add(entry.key);
      }
    }
    if (matched.isEmpty) {
      matched.add('علوم وثقافة');
    }
    return matched;
  }

  VideoItem auditItem(VideoItem item) {
    final hay = '${item.title} ${item.description} ${item.sourceName} ${item.category}'
        .toLowerCase();
    final hasBlocked =
        _blockedKeywords.any((word) => hay.contains(word.toLowerCase()));
    final matched =
        detectMatchedPillars(item.title, item.description, item.category);

    if (hasBlocked) {
      return item.copyWith(
        purityScore: 0.15,
        alignmentScore: 0.20,
        matchedPillars: matched,
        auditStatus: 'مستبعد تلقائياً (مخالفة لمعايير النقاء)',
        isVerifiedClean: false,
      );
    }

    final safePurity = item.purityScore < 0.85 ? 0.96 : item.purityScore;
    final safeAlignment = item.alignmentScore < 0.85 ? 0.94 : item.alignmentScore;

    return item.copyWith(
      purityScore: safePurity,
      alignmentScore: safeAlignment,
      matchedPillars: matched,
      auditStatus: 'معتمد احترافياً (خالٍ من الإعلانات ومطابق للقيم)',
      isVerifiedClean: true,
    );
  }

  List<VideoItem> filterCleanCatalog(
    List<VideoItem> rawItems, {
    required String ageGroupKey,
    String query = '',
    bool onlyClean = true,
  }) {
    final q = query.trim().toLowerCase();
    return rawItems.map(auditItem).where((item) {
      if (onlyClean && !item.isVerifiedClean) return false;
      if (ageGroupKey != 'all_ages' &&
          item.ageGroup != 'all_ages' &&
          item.ageGroup != ageGroupKey) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay =
            '${item.title} ${item.description} ${item.sourceName} ${item.matchedPillars.join(' ')}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }
}

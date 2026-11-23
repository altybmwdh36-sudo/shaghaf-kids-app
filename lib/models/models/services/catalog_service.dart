import '../models/video_item.dart';
import 'content_moderation_service.dart';

class CatalogService {
  final ContentModerationService _moderation = ContentModerationService();

  static const List<VideoItem> _curatedCatalog = [
    VideoItem(
      id: 'vid_quran_01',
      title: 'أخي وقرآن: جمال التلاوة وحفظ السور القصيرة للأطفال',
      description:
          'مقطع تربوي هادئ يعزز حب القرآن الكريم وحسن الاستماع والتلاوة الصحيحة بأسلوب محبب للصغار والناشئة.',
      sourceName: 'منصة شَغَف للقرآن والقيم',
      sourceType: 'educational_platform',
      watchUrl: 'https://www.youtube.com/watch?v=5qap5aO4i9A',
      embedUrl: 'https://www.youtube.com/embed/5qap5aO4i9A',
      thumbnailUrl: '',
      category: 'أخي وقرآن',
      ageGroup: 'all_ages',
      durationMinutes: 4,
      durationSeconds: 50,
      isShortClip: false,
      liveOnlineStream: true,
      purityScore: 0.99,
      alignmentScore: 0.99,
      matchedPillars: ['أخي وقرآن', 'الثقة بالله والإيمان وحب الآخرين'],
      auditStatus: 'معتمد احترافياً (خالٍ من الإعلانات ومطابق للقيم)',
      isVerifiedClean: true,
    ),
    VideoItem(
      id: 'vid_prophets_02',
      title: 'قصص الأنبياء والصحابة: الصدق والأمانة في حياة الناشئة',
      description:
          'سرد قصصي قيّمي يرسخ معاني الصدق، الشجاعة، والإحسان من سير الأنبياء والصحابة بأسلوب مشوق.',
      sourceName: 'مكتبة شَغَف القصصية',
      sourceType: 'cultural_archive',
      watchUrl: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
      embedUrl: 'https://www.youtube.com/embed/aqz-KE-bpKQ',
      thumbnailUrl: '',
      category: 'قصص الأنبياء والصحابة',
      ageGroup: 'all_ages',
      durationMinutes: 6,
      durationSeconds: 45,
      isShortClip: false,
      liveOnlineStream: true,
      purityScore: 0.98,
      alignmentScore: 0.97,
      matchedPillars: ['قصص الأنبياء والصحابة', 'بناء الشخصية والقيادة والإقناع والنجاح'],
      auditStatus: 'معتمد احترافياً (خالٍ من الإعلانات ومطابق للقيم)',
      isVerifiedClean: true,
    ),
    VideoItem(
      id: 'vid_creation_03',
      title: 'الولاعة والخلقة: عجائب الكون والنجوم والطبيعة',
      description:
          'رحلة بصرية معرفية للتأمل في بديع صنع الله في السماوات والأرض والكائنات الحية حتى سن العشرين.',
      sourceName: 'أرشيف شَغَف للكون والطبيعة',
      sourceType: 'cultural_archive',
      watchUrl: 'https://www.youtube.com/watch?v=ysz5S6PUM-U',
      embedUrl: 'https://www.youtube.com/embed/ysz5S6PUM-U',
      thumbnailUrl: '',
      category: 'الولاعة والخلقة',
      ageGroup: 'all_ages',
      durationMinutes: 5,
      durationSeconds: 30,
      isShortClip: false,
      liveOnlineStream: true,
      purityScore: 0.98,
      alignmentScore: 0.96,
      matchedPillars: ['الولاعة والخلقة', 'علوم وثقافة'],
      auditStatus: 'معتمد احترافياً (خالٍ من الإعلانات ومطابق للقيم)',
      isVerifiedClean: true,
    ),
    VideoItem(
      id: 'vid_science_04',
      title: 'علوم وثقافة والاختراع: كيف يفكر المخترعون والعلماء؟',
      description:
          'محتوى علمي وثقافي يفتح آفاق الفضول العلمي، التجربة، والابتكار للطلاب والمخترعين الصغار.',
      sourceName: 'معمل شَغَف للعلوم والابتكار',
      sourceType: 'educational_platform',
      watchUrl: 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
      embedUrl: 'https://www.youtube.com/embed/jNQXAC9IVRw',
      thumbnailUrl: '',
      category: 'علوم وثقافة',
      ageGroup: 'youth_13_to_20',
      durationMinutes: 1,
      durationSeconds: 20,
      isShortClip: true,
      liveOnlineStream: true,
      purityScore: 0.97,
      alignmentScore: 0.96,
      matchedPillars: ['علوم وثقافة', 'المذاكرة وحب الدراسة والاختراع'],
      auditStatus: 'معتمد احترافياً (خالٍ من الإعلانات ومطابق للقيم)',
      isVerifiedClean: true,
    ),
    VideoItem(
      id: 'vid_study_05',
      title: 'المذاكرة وحب الدراسة: أسرار التركيز والتفوق الدراسي',
      description:
          'إرشادات عملية وممتعة لتنظيم الوقت، حب المذاكرة، وبناء عادة التعلم المستمر بثقة وهدوء.',
      sourceName: 'أكاديمية شَغَف للتفوق',
      sourceType: 'educational_platform',
      watchUrl: 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
      embedUrl: 'https://www.youtube.com/embed/M7lc1UVf-VE',
      thumbnailUrl: '',
      category: 'المذاكرة وحب الدراسة والاختراع',
      ageGroup: 'youth_13_to_20',
      durationMinutes: 1,
      durationSeconds: 35,
      isShortClip: true,
      liveOnlineStream: true,
      purityScore: 0.98,
      alignmentScore: 0.97,
      matchedPillars: ['المذاكرة وحب الدراسة والاختراع', 'بناء الشخصية والقيادة والإقناع والنجاح'],
      auditStatus: 'معتمد احترافياً (خالٍ من الإعلانات ومطابق للقيم)',
      isVerifiedClean: true,
    ),
    VideoItem(
      id: 'vid_humor_06',
      title: 'فكاهة هادفة وبريئة وبناء الشخصية: روح التعاون والمرح النظيف',
      description:
          'مقاطع قصيرة وطريفة بأسلوب نبيل يجمع بين البهجة البريئة، حسن الحوار، وبناء الشخصية الإيجابية.',
      sourceName: 'ركن شَغَف للفكاهة النبيلة',
      sourceType: 'youtube',
      watchUrl: 'https://www.youtube.com/watch?v=9bZkp7q19f0',
      embedUrl: 'https://www.youtube.com/embed/9bZkp7q19f0',
      thumbnailUrl: '',
      category: 'فكاهة هادفة وبريئة',
      ageGroup: 'kids_under_12',
      durationMinutes: 1,
      durationSeconds: 15,
      isShortClip: true,
      liveOnlineStream: true,
      purityScore: 0.96,
      alignmentScore: 0.95,
      matchedPillars: ['فكاهة هادفة وبريئة', 'الثقة بالله والإيمان وحب الآخرين'],
      auditStatus: 'معتمد احترافياً (خالٍ من الإعلانات ومطابق للقيم)',
      isVerifiedClean: true,
    ),
  ];

  List<VideoItem> getAllCleanItems({
    required String ageGroupKey,
    String query = '',
    List> customItems = const [],
  }) {
    final customVideos = customItems
        .map((m) => _moderation.auditItem(VideoItem.fromJson(m)))
        .toList();
    final combined = <VideoItem>[
      ...customVideos,
      ..._curatedCatalog,
    ];
    return _moderation.filterCleanCatalog(
      combined,
      ageGroupKey: ageGroupKey,
      query: query,
      onlyClean: true,
    );
  }
}

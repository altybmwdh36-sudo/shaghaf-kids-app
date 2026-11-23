import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member_session.dart';

class SessionService {
  static const String _sessionKey = 'shaghaf_member_session_v1';

  Future<MemberSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return MemberSession.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveFreeSession({
    required String guardianOrMemberName,
    required String contactInfo,
    required String ageBracketLabel,
    required String ageGroupKey,
    bool isOwnerMode = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final session = MemberSession(
      guardianOrMemberName: guardianOrMemberName.trim().isEmpty
          ? 'عضو شَغَف'
          : guardianOrMemberName.trim(),
      contactInfo: contactInfo.trim(),
      ageBracketLabel: ageBracketLabel,
      ageGroupKey: ageGroupKey,
      subscriptionPlanLabel: 'اشتراك مجاني مفعّل تلقائياً مع الدخول',
      isFreeSubscriptionActivated: true,
      isOwnerMode: isOwnerMode,
      activatedAt: DateTime.now(),
    );
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}


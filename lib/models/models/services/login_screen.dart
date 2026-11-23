import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final Future<void> Function({
    required String guardianOrMemberName,
    required String contactInfo,
    required String ageBracketLabel,
    required String ageGroupKey,
    bool isOwnerMode,
  }) onActivateFreeMembership;

  const LoginScreen({
    super.key,
    required this.onActivateFreeMembership,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  String _selectedAgeKey = 'all_ages';
  bool _isSubmitting = false;

  static const Map<String, String> _ageOptions = {
    'kids_under_12': 'أطفال حتى 12 سنة',
    'youth_13_to_20': 'ناشئة وشباب (13 إلى 20 سنة)',
    'all_ages': 'جميع الأعمار (حتى 20 سنة)',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit({bool asOwner = false}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final ageLabel = _ageOptions[_selectedAgeKey] ?? 'جميع الأعمار (حتى 20 سنة)';
      await widget.onActivateFreeMembership(
        guardianOrMemberName: _nameController.text.trim().isEmpty
            ? (asOwner ? 'مالك منصة شَغَف' : 'ولي أمر / عضو شَغَف')
            : _nameController.text.trim(),
        contactInfo: _contactController.text.trim(),
        ageBracketLabel: ageLabel,
        ageGroupKey: _selectedAgeKey,
        isOwnerMode: asOwner,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B3B2E), Color(0xFF145A46), Color(0xFFF6FBF8)],
              stops: [0.0, 0.34, 0.34],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const Center(
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: Color(0xFFD4AF37),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        size: 40,
                        color: Color(0xFF0B3B2E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'منصة «شَغَف» للأطفال حتى 20 سنة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'الاشتراك المجاني مفعّل تلقائياً مع الدخول — محتوى نقي خالٍ من الإعلانات',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'تسجيل الدخول وتفعيل العضوية المجانية',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B3B2E),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم ولي الأمر أو المستفيد',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _contactController,
                            decoration: const InputDecoration(
                              labelText: 'رقم الجوال أو البريد (اختياري)',
                              prefixIcon: Icon(Icons.phone_android_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'الفئة العمرية المستهدفة:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          ..._ageOptions.entries.map((entry) {
                            return RadioListTile<String>(
                              value: entry.key,
                              groupValue: _selectedAgeKey,
                              title: Text(entry.value),
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedAgeKey = val);
                                }
                              },
                            );
                          }),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : () => _submit(asOwner: false),
                            icon: const Icon(Icons.verified_user_rounded),
                            label: Text(
                              _isSubmitting
                                  ? 'جاري التفعيل...'
                                  : 'دخول وتفعيل الاشتراك المجاني فوراً',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B3B2E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _isSubmitting ? null : () => _submit(asOwner: true),
                            icon: const Icon(Icons.admin_panel_settings_outlined),
                            label: const Text('دخول بوضع المالك / المشرف'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0B3B2E),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

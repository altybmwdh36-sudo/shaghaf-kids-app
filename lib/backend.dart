import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get shaghafBackendConfigured =>
    _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

bool shaghafBackendReady = false;
bool _initializing = false;

Future<bool> initializeShaghafBackend() async {
  if (shaghafBackendReady) return true;
  if (!shaghafBackendConfigured || _initializing) return false;
  _initializing = true;
  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseAnonKey,
    );
    shaghafBackendReady = true;
  } catch (_) {
    shaghafBackendReady = false;
  } finally {
    _initializing = false;
  }
  return shaghafBackendReady;
}

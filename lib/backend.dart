import 'package:supabase_flutter/supabase_flutter.dart';

// This project URL is fixed here so it cannot be confused with the API key.
const _supabaseUrl = 'https://xdkrvwjkaazaybppxtzc.supabase.co';
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get shaghafBackendConfigured => _supabaseAnonKey.isNotEmpty;

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

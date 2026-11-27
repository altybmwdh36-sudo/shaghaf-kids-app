import 'package:supabase_flutter/supabase_flutter.dart';

// This project URL is fixed here so it cannot be confused with the API key.
const _supabaseUrl = 'https://xdkrvwjkaazaybppxtzc.supabase.co';
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get shaghafBackendConfigured => _supabaseAnonKey.isNotEmpty;

bool shaghafBackendReady = false;
Future<bool>? _initializationFuture;

/// All callers share one initialization attempt. This prevents the app startup
/// and screens from racing and one caller incorrectly receiving a temporary
/// "not ready" result while another caller is still initializing Supabase.
Future<bool> initializeShaghafBackend() {
  if (shaghafBackendReady) return Future<bool>.value(true);
  if (!shaghafBackendConfigured) return Future<bool>.value(false);
  return _initializationFuture ??= _initializeBackend();
}

Future<bool> _initializeBackend() async {
  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseAnonKey,
    );
    shaghafBackendReady = true;
    return true;
  } catch (_) {
    shaghafBackendReady = false;
    return false;
  } finally {
    _initializationFuture = null;
  }
}

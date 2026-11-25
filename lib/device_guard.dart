import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A random installation identifier stored in Android secure storage.
/// Reinstalling the app creates a new identifier and requires OTP verification.
class ShaghafDeviceGuard {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'shaghaf_installation_id';

  static Future<String> getDeviceId() async {
    final existing = await _storage.read(key: _storageKey);
    if (existing != null && existing.length == 64) return existing;

    final random = Random.secure();
    final id = List<int>.generate(32, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    await _storage.write(key: _storageKey, value: id);
    return id;
  }
}

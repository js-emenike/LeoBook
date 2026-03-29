// update_service.dart: In-app update checker via Supabase Storage bucket.
// Part of LeoBook App — Services
//
// Checks app-releases/metadata.json for newer APK versions.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUpdateInfo {
  final bool updateAvailable;
  final String currentVersion;
  final String latestVersion;
  final String? downloadUrl;

  const AppUpdateInfo({
    this.updateAvailable = false,
    this.currentVersion = '',
    this.latestVersion = '',
    this.downloadUrl,
  });
}

class UpdateService extends ChangeNotifier {
  static const String _bucket = 'app-releases';
  static const String _metadataFile = 'metadata.json';

  AppUpdateInfo _info = const AppUpdateInfo();
  AppUpdateInfo get info => _info;

  Timer? _timer;

  /// Current app version — matches pubspec.yaml version field.
  static const String appVersion = '9.5.0';

  /// Start periodic checking (every [intervalSeconds]).
  void startPeriodicCheck({int intervalSeconds = 3}) {
    checkForUpdate(); // Immediate first check
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => checkForUpdate(),
    );
  }

  void stopPeriodicCheck() {
    _timer?.cancel();
    _timer = null;
  }

  /// Fetch metadata.json from Supabase Storage and compare versions.
  Future<void> checkForUpdate() async {
    try {
      final supabase = Supabase.instance.client;

      // Download metadata.json as bytes from public bucket
      final bytes = await supabase.storage
          .from(_bucket)
          .download(_metadataFile);

      final jsonStr = utf8.decode(bytes);
      final Map<String, dynamic> metadata = json.decode(jsonStr);

      final latestVersion = metadata['version'] as String? ?? appVersion;
      final downloadUrl = metadata['apk_url'] as String?;

      final isNewer = _isVersionNewer(latestVersion, appVersion);

      _info = AppUpdateInfo(
        updateAvailable: isNewer,
        currentVersion: appVersion,
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[UpdateService] Check failed: $e');
      // Keep previous state on failure
    }
  }

  /// Compare semantic versions: returns true if [remote] > [local].
  bool _isVersionNewer(String remote, String local) {
    final rParts = remote.split('.').map(int.tryParse).toList();
    final lParts = local.split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final r = (i < rParts.length ? rParts[i] : 0) ?? 0;
      final l = (i < lParts.length ? lParts[i] : 0) ?? 0;
      if (r > l) return true;
      if (r < l) return false;
    }
    return false;
  }

  @override
  void dispose() {
    stopPeriodicCheck();
    super.dispose();
  }
}

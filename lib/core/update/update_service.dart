import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../api/api_client.dart';

/// Identifies this app to the backend version gate (GET /app-version).
/// finance-flutter is the financer app.
const String kUpdateAppId = 'financer';

enum UpdateLevel {
  /// Installed build is current — do nothing.
  none,

  /// A newer build exists but the installed one still works — show a dismissible prompt.
  optional,

  /// Installed build is below minRequired — block the app until the user updates.
  forced,
}

class UpdateCheck {
  final UpdateLevel level;
  final String storeUrl;
  final String latest;
  final String releaseNotes;

  const UpdateCheck({
    required this.level,
    required this.storeUrl,
    required this.latest,
    required this.releaseNotes,
  });

  static const none = UpdateCheck(
    level: UpdateLevel.none,
    storeUrl: '',
    latest: '',
    releaseNotes: '',
  );
}

String? _platformName() {
  if (kIsWeb) return null;
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  return null; // desktop / unknown → never gate
}

/// Asks the backend whether the installed build needs (or could use) an update.
/// Fails open: any error (unsupported platform, network, parse) resolves to
/// [UpdateCheck.none] so a flaky check can never lock users out of the app.
final updateCheckProvider = FutureProvider<UpdateCheck>((ref) async {
  final platform = _platformName();
  if (platform == null) return UpdateCheck.none;

  String current;
  try {
    final info = await PackageInfo.fromPlatform();
    current = info.version; // build-name, e.g. "1.0.0"
  } catch (_) {
    return UpdateCheck.none;
  }

  try {
    final api = ref.read(apiClientProvider);
    final data = await api.get('app-version', query: {
      'app': kUpdateAppId,
      'platform': platform,
      'current': current,
    });
    if (data is! Map) return UpdateCheck.none;

    final storeUrl = (data['storeUrl'] ?? '').toString();
    final required = data['updateRequired'] == true;
    final available = data['updateAvailable'] == true;

    UpdateLevel level;
    if (required) {
      level = UpdateLevel.forced;
    } else if (available) {
      level = UpdateLevel.optional;
    } else {
      level = UpdateLevel.none;
    }

    // Never hard-block with no store link to send the user to.
    if (level == UpdateLevel.forced && storeUrl.isEmpty) {
      level = UpdateLevel.none;
    }

    return UpdateCheck(
      level: level,
      storeUrl: storeUrl,
      latest: (data['latest'] ?? '').toString(),
      releaseNotes: (data['releaseNotes'] ?? '').toString(),
    );
  } catch (_) {
    return UpdateCheck.none;
  }
});

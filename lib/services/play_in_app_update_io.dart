import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

Future<bool> playStoreHasNewerVersion() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    final info = await InAppUpdate.checkForUpdate();
    return info.updateAvailability == UpdateAvailability.updateAvailable;
  } catch (e) {
    debugPrint('Play in-app update check: $e');
    return false;
  }
}

Future<bool> startPlayImmediateUpdate() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      return false;
    }
    if (info.immediateUpdateAllowed) {
      await InAppUpdate.performImmediateUpdate();
      return true;
    }
    if (info.flexibleUpdateAllowed) {
      await InAppUpdate.startFlexibleUpdate();
      return true;
    }
  } catch (e) {
    debugPrint('Play in-app update start: $e');
  }
  return false;
}

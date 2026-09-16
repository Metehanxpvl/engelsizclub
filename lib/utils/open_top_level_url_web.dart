// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Leave the Flutter SPA so Firebase can serve a real `.html` file.
bool openTopLevelUrl(String url) {
  final t = url.trim();
  if (t.isEmpty) return false;
  try {
    html.window.location.assign(t);
    return true;
  } catch (_) {
    return false;
  }
}

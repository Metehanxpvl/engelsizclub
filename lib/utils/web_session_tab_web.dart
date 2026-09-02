// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _key = 'engelsizclub_active_tab';

/// Survives a Flutter-web reload after `<input capture>` / gallery.
void persistWebSessionTab(String name) {
  if (name.trim().isEmpty) return;
  try {
    html.window.sessionStorage[_key] = name;
  } catch (_) {}
}

String? readWebSessionTab() {
  try {
    final v = html.window.sessionStorage[_key];
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  } catch (_) {
    return null;
  }
}

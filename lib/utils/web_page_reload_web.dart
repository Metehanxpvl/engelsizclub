// ignore_for_file: depend_on_referenced_packages
// package:web is already a transitive dependency; pubspec must stay unchanged.

import 'package:web/web.dart' as web;

/// Full browser reload so the app boots with prefs-backed theme colors.
void reloadWebPage() {
  web.window.location.reload();
}

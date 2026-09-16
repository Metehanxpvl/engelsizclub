// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js' as js;

/// Leave the Flutter SPA so Firebase can serve a real `.html` file.
bool openTopLevelUrl(String url) {
  final t = url.trim();
  if (t.isEmpty) return false;
  final escaped = t.replaceAll('\\', '\\\\').replaceAll("'", r"\'");
  try {
    js.context.callMethod('eval', [
      '(function(){'
          'var u=\'$escaped\';'
          'var go=function(){window.location.replace(u);};'
          'if(navigator.serviceWorker&&navigator.serviceWorker.getRegistrations){'
          'navigator.serviceWorker.getRegistrations().then(function(rs){'
          'return Promise.all(rs.map(function(r){return r.unregister();}));'
          '}).then(go,go);'
          '}else{go();}'
          '})();'
    ]);
    return true;
  } catch (_) {
    try {
      html.window.location.replace(t);
      return true;
    } catch (_) {
      try {
        html.window.location.href = t;
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}

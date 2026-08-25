// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

html.StyleElement? _style;

const _className = 'kesfet-feed-active';
const _styleId = 'kesfet-iframe-passthrough';

/// Lets Flutter receive vertical swipes by disabling HTML pointer hit-testing
/// on YouTube / WebView platform views while Keşfet is the top route.
void setKesfetIframePointerPassthrough(bool enabled) {
  _style ??= html.StyleElement()
    ..id = _styleId
    ..text = '''
body.$_className iframe,
body.$_className flt-platform-view,
body.$_className flt-platform-view-slot,
body.$_className flt-semantics-host iframe {
  pointer-events: none !important;
}
''';
  if (_style!.parent == null) {
    html.document.head?.append(_style!);
  }
  final body = html.document.body;
  if (body == null) return;
  if (enabled) {
    body.classes.add(_className);
    for (final el in html.document.querySelectorAll('iframe')) {
      el.style.pointerEvents = 'none';
    }
  } else {
    body.classes.remove(_className);
    for (final el in html.document.querySelectorAll('iframe')) {
      el.style.pointerEvents = '';
    }
  }
}

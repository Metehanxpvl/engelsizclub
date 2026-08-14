import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../meto_theme.dart';

/// Mobilde uygulama içi WebView; web'de aynı sekmede / harici açılış.
class InAppWebPage extends StatefulWidget {
  const InAppWebPage({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  /// Platforma uygun aç: mobil WebView, web launchUrl.
  static Future<void> open(
    BuildContext context, {
    required String title,
    required String url,
  }) async {
    final uri = _resolveUri(url);
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçersiz bağlantı.')),
        );
      }
      return;
    }

    if (kIsWeb) {
      final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sayfa açılamadı.')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InAppWebPage(title: title, url: uri.toString()),
      ),
    );
  }

  static Uri? _resolveUri(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('/')) {
      return Uri.parse('https://www.engelsizclub.com$t');
    }
    final u = Uri.tryParse(t);
    if (u == null || !(u.hasScheme && (u.scheme == 'http' || u.scheme == 'https'))) {
      return null;
    }
    return u;
  }

  @override
  State<InAppWebPage> createState() => _InAppWebPageState();
}

class _InAppWebPageState extends State<InAppWebPage> {
  late final WebViewController _controller;
  var _loading = true;
  var _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController(
      onPermissionRequest: (request) => request.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
    _enableNativeFilePicker();
  }

  /// Android WebView hides `<input type="file">` unless this callback is set
  /// *and* `setSynchronousReturnValueForOnShowFileChooser(true)` succeeds.
  /// iOS WKWebView shows the native picker if camera / photo usage strings exist.
  ///
  /// Do not show a Flutter sheet over the WebView — hybrid composition puts the
  /// native view on top, so the sheet is invisible and the chooser appears stuck.
  Future<void> _enableNativeFilePicker() async {
    final platform = _controller.platform;
    if (platform is! AndroidWebViewController) return;
    await platform.setAllowFileAccess(true);
    await platform.setAllowContentAccess(true);
    await platform.setOnShowFileSelector(_androidFileSelector);
  }

  Future<List<String>> _androidFileSelector(FileSelectorParams params) async {
    try {
      if (params.mode == FileSelectorMode.save) {
        return const <String>[];
      }
      final multiple = params.mode == FileSelectorMode.openMultiple;
      final picker = ImagePicker();

      if (params.isCaptureEnabled) {
        final captured = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 92,
        );
        if (captured != null) {
          return _urisFromPaths(<String>[captured.path]);
        }
      }

      if (multiple) {
        final files = await picker.pickMultiImage(imageQuality: 92);
        return _urisFromPaths(files.map((f) => f.path).toList());
      }

      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null) return const <String>[];
      return _urisFromPaths(<String>[picked.path]);
    } catch (e, st) {
      debugPrint('Android WebView file selector failed: $e\n$st');
      return const <String>[];
    }
  }

  List<String> _urisFromPaths(List<String> paths) {
    return [
      for (final path in paths)
        if (path.startsWith('content:') || path.startsWith('file:'))
          path
        else
          Uri.file(path).toString(),
    ];
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Tarayıcıda aç',
            onPressed: _openExternal,
            icon: const Icon(Icons.open_in_browser),
          ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            LinearProgressIndicator(
              value: _progress > 0 && _progress < 100 ? _progress / 100 : null,
              minHeight: 2,
              color: MetoColors.primary,
              backgroundColor: MetoColors.border,
            ),
        ],
      ),
    );
  }
}

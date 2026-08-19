import 'package:flutter/material.dart';

/// Mobil: kullanılmaz (WebView ayrı).
class FullPageIframe extends StatelessWidget {
  const FullPageIframe({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

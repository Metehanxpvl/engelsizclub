import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../meto_theme.dart';

/// Web’de geniş pencerede uygulamayı telefon genişliğinde ortalar.
/// Dar pencerede (telefon, dar tarayıcı) tam genişlik kalır.
class WebDesktopFrame extends StatelessWidget {
  const WebDesktopFrame({
    super.key,
    required this.child,
    this.enabled,
  });

  final Widget child;

  /// Testte kIsWeb yerine zorlamak için. Üretimde boş bırakılır.
  final bool? enabled;

  /// Büyük telefon genişliği. Daha geniş monitörde içerik buna sığar.
  static const maxContentWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    if (!(enabled ?? kIsWeb)) return child;
    return ColoredBox(
      color: const Color(0xFFD7E4DC),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final windowWidth = constraints.maxWidth;
          if (!windowWidth.isFinite || windowWidth <= maxContentWidth) {
            return child;
          }
          final media = MediaQuery.of(context);
          return Center(
            child: SizedBox(
              width: maxContentWidth,
              height: constraints.maxHeight,
              child: MediaQuery(
                data: media.copyWith(
                  size: Size(maxContentWidth, media.size.height),
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: MetoColors.background,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x220D2B1F),
                        blurRadius: 28,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

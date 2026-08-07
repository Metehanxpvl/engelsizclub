import 'package:flutter/material.dart';

import 'content_translator.dart';
import 'locale_controller.dart';

/// Türkçe kaynak metni seçilen dile çevirerek gösterir.
/// Statik UI ve kullanıcı içeriği (ilan, forum) için kullanılabilir.
class L10nText extends StatelessWidget {
  const L10nText(
    this.source, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.from = 'tr',
    this.strutStyle,
  });

  final String source;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String from;
  final StrutStyle? strutStyle;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LocaleController.instance,
        ContentTranslator.instance,
      ]),
      builder: (context, _) {
        final text = ContentTranslator.instance.sync(source, from: from);
        return Text(
          text,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          softWrap: softWrap,
          strutStyle: strutStyle,
        );
      },
    );
  }
}

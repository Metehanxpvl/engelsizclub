import 'package:flutter/material.dart';

import '../sohbet_store.dart';

/// WhatsApp tarzı gönderildi / iletildi / okundu tikleri.
class SohbetReceiptTicks extends StatelessWidget {
  const SohbetReceiptTicks({
    super.key,
    required this.receipt,
    this.color = const Color(0xB3FFFFFF),
    this.readColor = const Color(0xFF7DD3FC),
    this.size = 14,
  });

  final SohbetReceipt receipt;
  final Color color;
  final Color readColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, c, label) = switch (receipt) {
      SohbetReceipt.sending => (
          Icons.access_time,
          color,
          'Gönderiliyor',
        ),
      SohbetReceipt.sent => (Icons.done, color, 'Gönderildi'),
      SohbetReceipt.delivered => (Icons.done_all, color, 'İletildi'),
      SohbetReceipt.read => (Icons.done_all, readColor, 'Okundu'),
    };
    return Tooltip(
      message: label,
      child: Icon(icon, size: size, color: c),
    );
  }
}

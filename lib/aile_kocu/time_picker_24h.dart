import 'package:flutter/material.dart';

/// Aile Koçu zaman seçici — her zaman 24 saat (23:00), AM/PM yok.
Future<TimeOfDay?> pickTime24h(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

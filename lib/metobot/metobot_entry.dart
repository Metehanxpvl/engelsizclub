import 'package:flutter/material.dart';

import 'metobot_page.dart';

/// Named route so the floating chip can hide while MetoBot is open.
const String kMetobotRouteName = MetoBotPage.routeName;

/// Opens MetoBot. More-menu and the draggable chip both call this.
/// Returns an in-app route when the user taps a suggestion chip.
Future<String?> openMetobot(
    BuildContext context, {
  bool isGuest = false,
  VoidCallback? onRequireLogin,
}) {
  return openMetoBot(
    context,
    isGuest: isGuest,
    onRequireLogin: onRequireLogin,
  );
}

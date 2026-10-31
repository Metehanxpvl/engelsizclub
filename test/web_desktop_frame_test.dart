import 'package:engelsizclub/widgets/web_desktop_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wide window keeps the app at phone width', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WebDesktopFrame(
          enabled: true,
          child: ColoredBox(
            key: Key('app-column'),
            color: Color(0xFFFFFFFF),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    final app = tester.getSize(find.byKey(const Key('app-column')));
    expect(app.width, WebDesktopFrame.maxContentWidth);
    expect(app.width, lessThan(1400));
  });

  testWidgets('narrow window stays full width', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WebDesktopFrame(
          enabled: true,
          child: ColoredBox(
            key: Key('app-column'),
            color: Color(0xFFFFFFFF),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    final app = tester.getSize(find.byKey(const Key('app-column')));
    expect(app.width, 390);
  });
}

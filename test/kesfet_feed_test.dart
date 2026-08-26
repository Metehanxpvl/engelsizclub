import 'package:engelsizclub/kesfet/kesfet_store.dart';
import 'package:engelsizclub/kesfet/kesfet_swipe_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same layering as a Keşfet slide: the player sits under a transparent swipe
/// layer, and the PageView itself never handles drags.
class _Feed extends StatefulWidget {
  const _Feed({required this.itemCount});

  final int itemCount;

  @override
  State<_Feed> createState() => _FeedState();
}

class _FeedState extends State<_Feed> {
  final controller = PageController();
  int index = 0;
  int wraps = 0;
  int taps = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PageView.builder(
        controller: controller,
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.itemCount,
        onPageChanged: (i) => setState(() => index = i),
        itemBuilder: (context, i) => Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: ColoredBox(
                color: Colors.black,
                child: Center(child: Text('video $i')),
              ),
            ),
            Positioned.fill(
              child: KesfetSwipeLayer(
                controller: controller,
                itemCount: widget.itemCount,
                reduceMotion: false,
                onTogglePlay: () => taps++,
                onWheel: (_) {},
                onWrapForward: () => wraps++,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<_FeedState> _pumpFeed(WidgetTester tester, int itemCount) async {
  await tester.pumpWidget(_Feed(itemCount: itemCount));
  await tester.pumpAndSettle();
  return tester.state<_FeedState>(find.byType(_Feed));
}

/// Flick: carries release velocity, like a real reels swipe.
Future<void> _flick(WidgetTester tester, double dy) async {
  await tester.fling(find.byType(PageView), Offset(0, dy), 1200);
  await tester.pumpAndSettle();
}

/// Slow drag: covers distance without flick velocity, so the release has to
/// snap on position alone.
Future<void> _slowDrag(WidgetTester tester, double dy) async {
  await tester.timedDrag(
    find.byType(PageView),
    Offset(0, dy),
    const Duration(milliseconds: 2000),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Keşfet vertical swipe', () {
    testWidgets('flick up opens the next clip', (tester) async {
      final state = await _pumpFeed(tester, 5);
      await _flick(tester, -400);
      expect(state.index, 1);
      expect(find.text('video 1'), findsOneWidget);
    });

    testWidgets('flick down goes back', (tester) async {
      final state = await _pumpFeed(tester, 5);
      await _flick(tester, -400);
      await _flick(tester, 400);
      expect(state.index, 0);
    });

    testWidgets('consecutive flicks keep advancing', (tester) async {
      final state = await _pumpFeed(tester, 5);
      await _flick(tester, -400);
      await _flick(tester, -400);
      await _flick(tester, -400);
      expect(state.index, 3);
    });

    testWidgets('slow drag past half a page still advances', (tester) async {
      final state = await _pumpFeed(tester, 5);
      final height = tester.getSize(find.byType(PageView)).height;
      await _slowDrag(tester, -height * 0.7);
      expect(state.index, 1);
    });

    testWidgets('short drag snaps back to the same clip', (tester) async {
      final state = await _pumpFeed(tester, 5);
      final height = tester.getSize(find.byType(PageView)).height;
      await _slowDrag(tester, -height * 0.2);
      expect(state.index, 0);
    });

    testWidgets('flick past the last clip asks for a reshuffle',
        (tester) async {
      final state = await _pumpFeed(tester, 2);
      await _flick(tester, -400);
      expect(state.index, 1);
      await _flick(tester, -400);
      expect(state.wraps, 1);
    });

    testWidgets('tap toggles playback instead of paging', (tester) async {
      final state = await _pumpFeed(tester, 5);
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      expect(state.taps, 1);
      expect(state.index, 0);
    });

    testWidgets('two clips are enough to scroll', (tester) async {
      final state = await _pumpFeed(tester, 2);
      expect(state.controller.position.maxScrollExtent, greaterThan(0));
      await _flick(tester, -400);
      expect(state.index, 1);
    });

    // The reported "Keşfet does not scroll" symptom: the gesture code is fine,
    // but a feed holding a single approved video has nowhere to scroll to.
    testWidgets('a single clip cannot scroll at all', (tester) async {
      final state = await _pumpFeed(tester, 1);
      expect(state.controller.position.maxScrollExtent, 0);
      await _flick(tester, -400);
      expect(state.index, 0);
      expect(state.controller.position.pixels, 0);
      await _flick(tester, 400);
      expect(state.index, 0);
      expect(state.controller.position.pixels, 0);
      expect(state.wraps, 0);
    });
  });

  group('Keşfet store', () {
    test('detects a missing kesfet_* relation so setup can be reported', () {
      expect(
        isKesfetMissingRelation(
          'PostgrestException(message: relation "public.kesfet_videos" '
          'does not exist, code: 42P01)',
        ),
        isTrue,
      );
      expect(
        isKesfetMissingRelation(
          "Could not find the table 'public.kesfet_videos' in the schema cache",
        ),
        isTrue,
      );
      expect(
        isKesfetMissingRelation('Bağlantı yavaş veya yanıt vermiyor.'),
        isFalse,
      );
    });

    test('shuffle keeps every clip and leaves the input untouched', () {
      final input = List<int>.generate(50, (i) => i);
      final copy = List<int>.of(input);
      final shuffled = shuffleKesfetVideos(input);
      expect(input, copy);
      expect(shuffled.length, input.length);
      expect(shuffled.toSet(), input.toSet());
    });
  });
}

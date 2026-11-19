import 'package:engelsizclub/meto_theme.dart';
import 'package:engelsizclub/renk_temasi_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    renkTemasiSurumu.value = 0;
    MetoColors.uygula(metoPaletteById('yesil'));
    MetoColors.geceModuUygula(false);
  });

  testWidgets(
    'pop sheet, wait 350ms, then save — no MaterialApp rebuild while sheet open',
    (tester) async {
      final errors = <Object>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details.exception);
        oldOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldOnError);

      await tester.pumpWidget(
        ValueListenableBuilder<int>(
          valueListenable: renkTemasiSurumu,
          builder: (context, surum, _) {
            return MaterialApp(
              key: ValueKey(surum),
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          builder: (ctx) {
                            return ListTile(
                              title: const Text('pick-mavi'),
                              onTap: () async {
                                Navigator.pop(ctx);
                                await Future<void>.delayed(
                                  const Duration(milliseconds: 350),
                                );
                                await saveAndApplyRenkTemasi(
                                  metoPaletteById('mavi'),
                                );
                              },
                            );
                          },
                        );
                      },
                      child: const Text('open-sheet'),
                    );
                  },
                ),
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('open-sheet'));
      await tester.pumpAndSettle();
      expect(find.text('pick-mavi'), findsOneWidget);

      await tester.tap(find.text('pick-mavi'));
      // Immediately after tap: sheet may still be animating closed, but
      // renkTemasiSurumu must not bump until the 350ms delay finishes.
      await tester.pump();
      expect(renkTemasiSurumu.value, 0);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('pick-mavi'), findsNothing);
      expect(renkTemasiSurumu.value, 1);
      expect(MetoColors.aktif.id, 'mavi');
      expect(errors, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('five sequential color changes do not throw', (tester) async {
    await tester.pumpWidget(
      ValueListenableBuilder<int>(
        valueListenable: renkTemasiSurumu,
        builder: (context, surum, _) {
          return MaterialApp(
            key: ValueKey(surum),
            home: const Scaffold(body: SizedBox.expand()),
          );
        },
      ),
    );

    final ids = ['mavi', 'mor', 'turuncu', 'sari', 'fistik'];
    for (final id in ids) {
      // Simulate post-sheet delay then apply (mobile path).
      await tester.pump(const Duration(milliseconds: 350));
      await saveAndApplyRenkTemasi(metoPaletteById(id));
      await tester.pumpAndSettle();
      expect(MetoColors.aktif.id, id);
      expect(tester.takeException(), isNull);
    }
    expect(renkTemasiSurumu.value, ids.length);
  });

  test('saveAndApply persists palette id', () async {
    await saveAndApplyRenkTemasi(metoPaletteById('turuncu'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('uygulama_renk_temasi_v1'), 'turuncu');
    expect(MetoColors.aktif.id, 'turuncu');
  });
}

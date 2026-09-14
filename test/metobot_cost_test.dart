import 'package:engelsizclub/data/more_menu_data.dart';
import 'package:engelsizclub/metobot/metobot_cost.dart';
import 'package:engelsizclub/metobot/metobot_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('metoBotSendBlock', () {
    final now = DateTime(2026, 9, 14, 12, 0, 0);

    test('ignores empty', () {
      expect(
        metoBotSendBlock(
          text: '   ',
          inFlight: false,
          now: now,
          todayCount: 0,
          dailyCap: 40,
        ),
        MetoBotSendBlock.empty,
      );
    });

    test('blocks in-flight', () {
      expect(
        metoBotSendBlock(
          text: 'merhaba',
          inFlight: true,
          now: now,
          todayCount: 0,
          dailyCap: 40,
        ),
        MetoBotSendBlock.busy,
      );
    });

    test('debounces 800ms', () {
      expect(
        metoBotSendBlock(
          text: 'merhaba',
          inFlight: false,
          now: now,
          lastAttemptAt: now.subtract(const Duration(milliseconds: 400)),
          todayCount: 0,
          dailyCap: 40,
        ),
        MetoBotSendBlock.debounce,
      );
      expect(
        metoBotSendBlock(
          text: 'merhaba',
          inFlight: false,
          now: now,
          lastAttemptAt: now.subtract(const Duration(milliseconds: 801)),
          todayCount: 0,
          dailyCap: 40,
        ),
        isNull,
      );
    });

    test('blocks identical message within 10s', () {
      expect(
        metoBotSendBlock(
          text: 'aynı',
          inFlight: false,
          now: now,
          lastSentText: 'aynı',
          lastSentAt: now.subtract(const Duration(seconds: 9)),
          todayCount: 0,
          dailyCap: 40,
        ),
        MetoBotSendBlock.duplicate,
      );
      expect(
        metoBotSendBlock(
          text: 'aynı',
          inFlight: false,
          now: now,
          lastSentText: 'aynı',
          lastSentAt: now.subtract(const Duration(seconds: 11)),
          todayCount: 0,
          dailyCap: 40,
        ),
        isNull,
      );
    });

    test('daily cap', () {
      expect(
        metoBotSendBlock(
          text: 'merhaba',
          inFlight: false,
          now: now,
          todayCount: 40,
          dailyCap: 40,
        ),
        MetoBotSendBlock.dailyCap,
      );
    });
  });

  group('metoBotMapInvokeError', () {
    test('404 function missing is offline', () {
      final mapped = metoBotMapInvokeError(
        status: 404,
        details: {
          'code': 'NOT_FOUND',
          'message': 'Requested function was not found',
        },
      );
      expect(mapped.code, 'offline');
      expect(mapped.message, kMetoBotOffline);
    });

    test('empty upstream reply is sunucu hatası', () {
      final mapped = metoBotMapInvokeError(fallbackCode: 'upstream');
      expect(mapped.message, kMetoBotServer);
    });

    test('function 500 is sunucu hatası', () {
      final mapped = metoBotMapInvokeError(
        status: 500,
        details: {'code': 'upstream', 'error': 'Şu an yanıt verilemedi, biraz sonra deneyin.'},
      );
      expect(mapped.code, 'upstream');
      expect(mapped.message, kMetoBotServer);
    });

    test('401 is login copy', () {
      final mapped = metoBotMapInvokeError(
        status: 401,
        details: {'code': 'auth', 'error': 'Giriş gerekli.'},
      );
      expect(mapped.code, 'auth');
      expect(mapped.message, kMetoBotAuth);
    });

    test('quota is kota copy', () {
      final mapped = metoBotMapInvokeError(
        status: 429,
        details: {'code': 'quota', 'error': 'Model kotası doldu, biraz sonra deneyin.'},
      );
      expect(mapped.code, 'quota');
      expect(mapped.message, kMetoBotQuota);
    });

    test('daily cap keeps Turkish copy', () {
      final mapped = metoBotMapInvokeError(
        status: 429,
        details: {'code': 'daily_cap', 'error': 'Bugünkü mesaj sınırına ulaşıldı.'},
      );
      expect(mapped.code, 'daily_cap');
      expect(mapped.message, kMetoBotDailyCap);
    });
  });

  group('metoBotLastN', () {
    test('keeps last N', () {
      final all = [
        for (var i = 0; i < 20; i++)
          MetoBotTurn(role: i.isEven ? 'user' : 'assistant', content: '$i'),
      ];
      final sliced = metoBotLastN(all, 12);
      expect(sliced.length, 12);
      expect(sliced.first.content, '8');
      expect(sliced.last.content, '19');
    });
  });

  group('MetoBotLimits', () {
    test('fail-open when missing', () {
      expect(MetoBotLimits.fromSettings(null).dailyUserMessages, 40);
      expect(MetoBotLimits.fromSettings('nope').dailyUserMessages, 40);
    });

    test('reads app_settings map', () {
      final parsed = MetoBotLimits.fromSettings({
        'dailyUserMessages': 25,
        'maxOutputTokens': 512,
        'lastN': 8,
      });
      expect(parsed.dailyUserMessages, 25);
      expect(parsed.lastN, 8);
    });
  });

  test('menu has metobot after aile_kocu', () {
    expect(MoreMenuItem.builtinRoutes.contains('metobot'), isTrue);
    expect(normalizeMoreMenuRoute('metobot'), 'metobot');
    final items = defaultMoreMenuItems();
    final aile = items.indexWhere((e) => e.link == 'aile_kocu');
    final bot = items.indexWhere((e) => e.link == 'metobot');
    expect(aile, greaterThanOrEqualTo(0));
    expect(bot, greaterThan(aile));
    expect(items[bot].title, 'MetoBot');
    final prepared = prepareUserMoreMenu([
      defaultHaritaMenuItem,
      MoreMenuItem(
        id: -1,
        title: 'Aile Koçum',
        subtitle: '',
        linkType: 'route',
        link: 'aile_kocu',
        icon: 'family',
        sortOrder: 10,
        isActive: true,
        isBuiltin: true,
      ),
    ]);
    expect(prepared.any(isMetoBotMenuItem), isTrue);
  });

  group('parseMetoBotSuggestedRoutes', () {
    test('keeps allowed in-app routes', () {
      final parsed = parseMetoBotSuggestedRoutes([
        {'route': 'haklar', 'title': 'Haklar · ÖTV Muafiyetli Araç Alımı'},
        {'route': 'https://evil.example', 'title': 'nope'},
        {'route': '/bilgi-kutuphanesi/premature-bebek', 'title': 'Prematüre'},
      ]);
      expect(parsed.length, 2);
      expect(parsed.first.route, 'haklar');
      expect(parsed.last.route, '/bilgi-kutuphanesi/premature-bebek');
    });

    test('ignores empty and unknown', () {
      expect(parseMetoBotSuggestedRoutes(null), isEmpty);
      expect(
        parseMetoBotSuggestedRoutes([
          {'route': 'sgk', 'title': 'SGK'},
        ]),
        isEmpty,
      );
    });
  });
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../meto_theme.dart';
import '../services/evde_egitim_store.dart';
import '../widgets/guest_timed_guard.dart';

const _kilavuzUrl =
    'https://orgm.meb.gov.tr/meb_iys_dosyalar/2025_05/27125050_evdeegitimhizmetlerikilavuzu2025.pdf';

enum _Wiz {
  hizmet,
  sure,
  rapor,
  raporYazi,
  kayit,
  model,
  kademe,
  ortam,
  kurumYetersizlik,
  kurumSkr,
  kurumOdeme,
  kurumRam,
  kurum,
  results,
}

enum _Sart { ok, no, maybe, info }

class _SartRow {
  const _SartRow({
    required this.status,
    required this.title,
    required this.note,
    this.badgeOverride,
  });

  final _Sart status;
  final String title;
  final String note;
  final String? badgeOverride;

  String get badge =>
      badgeOverride ??
      switch (status) {
        _Sart.ok => 'Sağlıyor',
        _Sart.no => 'Sağlamıyor',
        _Sart.maybe => 'Belirsiz',
        _Sart.info => 'Bilgi',
      };

  String get mark => switch (status) {
        _Sart.ok => '✓',
        _Sart.no => '✕',
        _Sart.maybe => '!',
        _Sart.info => 'i',
      };
}

/// Canlı teslimat HTML: `/evde-egitim`. Bu sayfa aynı Hak Sihirbazı UX’ini yerelde yansıtır.
class EvdeEgitimPage extends StatefulWidget {
  const EvdeEgitimPage({super.key});

  static Future<void> open(
    BuildContext context, {
    bool isGuest = false,
    VoidCallback? onRequireLogin,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GuestTimedGuard(
          isGuest: isGuest,
          tab: 'daha_fazlasi',
          onRequireLogin: onRequireLogin,
          child: const EvdeEgitimPage(),
        ),
      ),
    );
  }

  @override
  State<EvdeEgitimPage> createState() => _EvdeEgitimPageState();
}

class _EvdeEgitimPageState extends State<EvdeEgitimPage> {
  var _showWizard = false;
  var _step = _Wiz.hizmet;
  var _busy = false;
  String? _error;
  String? _saveNote;
  var _saved = false;

  String? _hizmet;
  String? _sure;
  String? _rapor;
  String? _raporYazi;
  String? _kayit;
  String? _egitim;
  String? _kademe;
  String? _ortam;
  String? _kurumYetersizlik;
  String? _kurumSkr;
  String? _kurumOdeme;
  String? _kurumRam;

  bool get _kurum => _hizmet == 'evde_destek_kurum';
  bool get _raporYaziOk =>
      _raporYazi == 'evet' || _raporYazi == 'risk' || _raporYazi == 'ikisi';

  List<_Wiz> get _path => _kurum
      ? const [
          _Wiz.hizmet,
          _Wiz.kurumYetersizlik,
          _Wiz.kurumSkr,
          _Wiz.kurumOdeme,
          _Wiz.kurumRam,
          _Wiz.kurum,
          _Wiz.results,
        ]
      : const [
          _Wiz.hizmet,
          _Wiz.sure,
          _Wiz.rapor,
          _Wiz.raporYazi,
          _Wiz.kayit,
          _Wiz.model,
          _Wiz.kademe,
          _Wiz.ortam,
          _Wiz.results,
        ];

  int get _qCount => _path.length - 1;

  int get _stepIndex {
    final i = _path.indexOf(_step);
    if (_step == _Wiz.results) return _qCount - 1;
    return i < 0 ? 0 : i;
  }

  String _kademeLabel(String? k) {
    if (k == 'ilkogretim') return 'İlköğretim — haftada en az 10 ders saati';
    if (k == 'ortaogretim_ozel') {
      return 'Özel eğitim ortaöğretim — haftada en az 10 ders saati';
    }
    if (k == 'ortaogretim') return 'Diğer ortaöğretim — haftada en az 16 ders saati';
    return '';
  }

  List<_SartRow> _sartRows() {
    final rows = <_SartRow>[];
    if (_hizmet == 'evde_egitim_meb') {
      rows.add(
        const _SartRow(
          status: _Sart.ok,
          title: 'MEB evde eğitim yolu',
          note: 'Öğretmeni okul veya milli eğitim müdürlüğü görevlendirir.',
        ),
      );
    } else if (_hizmet == 'evde_destek_kurum') {
      rows.add(
        const _SartRow(
          status: _Sart.ok,
          title: 'Kurum evde destek (rehabilitasyon merkezi)',
          note: 'Bu yol MEB evde eğitimin yerine geçmez.',
          badgeOverride: 'Ayrıldı',
        ),
      );
      rows.add(
        const _SartRow(
          status: _Sart.info,
          title: 'Aylık saat oranla değişmez',
          note:
              'Devlet ödemeli destek: ayda 8 saat bireysel ve/veya 4 saat grup. Hafif/orta/ağır veya %40/%70 bu saati değiştirmez.',
        ),
      );
      if (_kurumYetersizlik == 'evet') {
        rows.add(
          const _SartRow(
            status: _Sart.ok,
            title: 'Bedensel yetersizlik',
            note:
                'Özel Eğitim Kurumları Yönetmeliği m.25/10 (RG 11.07.2025) evde desteği buna bağlar.',
          ),
        );
      } else if (_kurumYetersizlik == 'hayir') {
        rows.add(
          const _SartRow(
            status: _Sart.no,
            title: 'Bedensel yetersizlik',
            note:
                'Güncel m.25/10 evde desteği bedensel yetersizliğe bağlar. Merkez veya RAM ile teyit edin.',
          ),
        );
      } else if (_kurumYetersizlik == 'emin') {
        rows.add(
          const _SartRow(
            status: _Sart.maybe,
            title: 'Bedensel yetersizlik',
            note: 'RAM veya merkezle teyit edin.',
          ),
        );
      }
      if (_kurumSkr == 'evet') {
        rows.add(
          const _SartRow(
            status: _Sart.ok,
            title: 'Durum Bildirir Sağlık Kurulu Raporu (SKR) — merkeze gidememe',
            note:
                'Hastane sağlık kurulu: 5580 kurumundan yararlanamama veya sağlık riski. Yüzde belgesi değildir.',
          ),
        );
      } else if (_kurumSkr == 'hayir') {
        rows.add(
          const _SartRow(
            status: _Sart.no,
            title: 'Durum Bildirir Sağlık Kurulu Raporu (SKR) — merkeze gidememe',
            note: 'm.25/10 bu belgeyi ister. Engelsiz Club rapor vermez.',
          ),
        );
      } else if (_kurumSkr == 'emin') {
        rows.add(
          const _SartRow(
            status: _Sart.maybe,
            title: 'Durum Bildirir Sağlık Kurulu Raporu (SKR) — merkeze gidememe',
            note: 'Hastane sağlık kurulundan alınır.',
          ),
        );
      }
      if (_kurumOdeme == 'cocuk_cozger') {
        rows.add(
          const _SartRow(
            status: _Sart.ok,
            title: '18 yaş altı — ÇÖZGER (Çocuklar İçin Özel Gereksinim Raporu)',
            note:
                '652 sayılı KHK m.43 çocukta yüzde istemez; özel gereksinim yazması yeter. Saat değişmez.',
          ),
        );
      } else if (_kurumOdeme == 'yetiskin_20') {
        rows.add(
          const _SartRow(
            status: _Sart.ok,
            title: '18+ — Erişkin Engellilik Sağlık Kurulu Raporu (ESKR) en az %20',
            note:
                '652 sayılı KHK m.43’teki tek resmi yüzde bandı. Evde destek saatini değiştirmez; MEB evde eğitime taşınmaz.',
          ),
        );
      } else if (_kurumOdeme == 'yok') {
        rows.add(
          const _SartRow(
            status: _Sart.maybe,
            title: 'Devlet ödemeli destek belgesi',
            note:
                'Yoksa devlet ödemesi açılmayabilir; ücretli kayıt ayrıdır. %40/%70 uydurulmaz.',
          ),
        );
      } else if (_kurumOdeme == 'emin') {
        rows.add(
          const _SartRow(
            status: _Sart.maybe,
            title: 'Devlet ödemeli destek belgesi',
            note: '18 altı ÇÖZGER (Çocuklar İçin Özel Gereksinim Raporu), 18+ en az %20 ESKR (Erişkinler İçin Engellilik Sağlık Kurulu Raporu). RAM veya merkezle sorun.',
          ),
        );
      }
      if (_kurumRam == 'evet') {
        rows.add(
          const _SartRow(
            status: _Sart.ok,
            title: 'RAM (Rehberlik ve Araştırma Merkezi) — Özel Eğitim Değerlendirme Kurulu Raporu',
            note:
                'Destek eğitimi önerilmiş olmalı. Başvuru RAM’adır; Engelsiz Club rapor vermez.',
          ),
        );
      } else if (_kurumRam == 'hayir') {
        rows.add(
          const _SartRow(
            status: _Sart.no,
            title: 'RAM (Rehberlik ve Araştırma Merkezi) — Özel Eğitim Değerlendirme Kurulu Raporu',
            note: 'm.25/10 ve 652 KHK m.43 bu raporu ister.',
          ),
        );
      } else if (_kurumRam == 'emin') {
        rows.add(
          const _SartRow(
            status: _Sart.maybe,
            title: 'RAM (Rehberlik ve Araştırma Merkezi) — Özel Eğitim Değerlendirme Kurulu Raporu',
            note: 'RAM’a eğitsel değerlendirme için gidin.',
          ),
        );
      }
      return rows;
    }
    if (_hizmet == null || _kurum) return rows;

    rows.add(
      const _SartRow(
        status: _Sart.info,
        title: 'Yüzde (%) şartı yok',
        note:
            'Kılavuz 2025 bölüm 2 ve Yönetmelik m.14 %40/%70 istemez. Aranan, Durum Bildirir Sağlık Kurulu Raporu\'nda (SKR) en az 12 hafta veya sağlık riskidir.',
      ),
    );

    if (_sure == 'evet') {
      rows.add(
        const _SartRow(
          status: _Sart.ok,
          title: 'En az 12 hafta okula gidememe veya sağlık riski',
          note: 'Kılavuz bunu sağlık kurulu raporuyla belgelemenizi ister.',
        ),
      );
    } else if (_sure == 'hayir') {
      rows.add(
        const _SartRow(
          status: _Sart.no,
          title: 'En az 12 hafta okula gidememe veya sağlık riski',
          note: 'Bu gerekçe yoksa MEB evde eğitim bu kılavuza göre açılmaz.',
        ),
      );
    } else if (_sure == 'emin') {
      rows.add(
        const _SartRow(
          status: _Sart.maybe,
          title: 'En az 12 hafta okula gidememe veya sağlık riski',
          note: 'Okul veya RAM ile teyit edin.',
        ),
      );
    }

    if (_rapor == 'var') {
      rows.add(
        const _SartRow(
          status: _Sart.ok,
          title: 'Durum Bildirir Sağlık Kurulu Raporu',
          note: 'Hastane sağlık kurulundan çıkar. Engelsiz Club rapor vermez.',
        ),
      );
    } else if (_rapor == 'yok') {
      rows.add(
        const _SartRow(
          status: _Sart.no,
          title: 'Durum Bildirir Sağlık Kurulu Raporu',
          note: 'Bu belge olmadan resmi başvuru tamamlanmaz.',
        ),
      );
    } else if (_rapor == 'alinacak') {
      rows.add(
        const _SartRow(
          status: _Sart.maybe,
          title: 'Durum Bildirir Sağlık Kurulu Raporu',
          note: 'Raporu aldıktan sonra okul veya RAM’a verin.',
        ),
      );
    }

    if (_raporYaziOk) {
      rows.add(
        const _SartRow(
          status: _Sart.ok,
          title: 'Raporda 12 hafta veya sağlık riski yazıyor',
          note: 'Yönetmelik m.14 ve Kılavuz bölüm 2 bunu ister. Yüzde yazması gerekmez.',
        ),
      );
    } else if (_raporYazi == 'hayir') {
      rows.add(
        const _SartRow(
          status: _Sart.no,
          title: 'Raporda 12 hafta veya sağlık riski yazıyor',
          note:
              'Engelli raporu yüzdesi bu şartın yerine geçmez. Hastaneden Durum Bildirir Sağlık Kurulu Raporu (SKR) alın.',
        ),
      );
    } else if (_raporYazi == 'emin') {
      rows.add(
        const _SartRow(
          status: _Sart.maybe,
          title: 'Raporda 12 hafta veya sağlık riski yazıyor',
          note: 'Belgeyi okuyun veya hastane / RAM ile teyit edin. Yüzde aranmaz.',
        ),
      );
    }

    if (_kayit == 'evet') {
      rows.add(
        const _SartRow(
          status: _Sart.ok,
          title: 'Okula kayıt',
          note: 'Dilekçeyi kayıtlı okul müdürlüğüne verin; okul RAM’a iletir.',
        ),
      );
    } else if (_kayit == 'hayir') {
      rows.add(
        const _SartRow(
          status: _Sart.maybe,
          title: 'Okula kayıt',
          note: 'Kayıt yoksa yazılı talebi doğrudan RAM’a götürün.',
        ),
      );
    }

    if (_egitim == 'yuz_yuze') {
      rows.add(
        const _SartRow(
          status: _Sart.ok,
          title: 'Yüz yüze eğitim (öncelikli yol)',
          note: 'Öğretmen eve gelir. Ev ortamının elverişli olması beklenir.',
        ),
      );
    } else if (_egitim == 'uzaktan_canli') {
      rows.add(
        const _SartRow(
          status: _Sart.maybe,
          title: 'Uzaktan canlı ders',
          note:
              'Tek başına seçmek yetmez; il/ilçe özel eğitim hizmetleri kurulu karar vermelidir.',
        ),
      );
    }

    if (_kademe != null) {
      rows.add(
        _SartRow(
          status: _Sart.ok,
          title: _kademeLabel(_kademe),
          note:
              'Saati sizin yazmanız gerekmez. Planı kurul ve okul yapar; kayıtlı okulun haftalık saatini aşamaz.',
        ),
      );
    }

    if (_ortam == 'evet') {
      rows.add(
        const _SartRow(
          status: _Sart.ok,
          title: 'Ev ortamı elverişli',
          note:
              'Temizlik, ısınma, ışık ve havalandırma yüz yüze ders için yeterli görünüyor.',
        ),
      );
    } else if (_ortam == 'hayir') {
      rows.add(
        const _SartRow(
          status: _Sart.no,
          title: 'Ev ortamı elverişli',
          note:
              'Yüz yüze için ortam uygun değilse kurul uzaktan ders önerebilir.',
        ),
      );
    }

    return rows;
  }

  ({String kind, String title, String text}) _outcome() {
    if (_kurum) {
      if (_kurumYetersizlik == 'hayir' || _kurumSkr == 'hayir') {
        return (
          kind: 'no',
          title: 'Kurum evde destek bu yönetmeliğe göre açılmaz',
          text:
              'm.25/10 bedensel yetersizlik ve Durum Bildirir Sağlık Kurulu Raporu\'nda (SKR) merkeze gidememe veya sağlık riski ister. Saat veya yüzde uydurulmaz.',
        );
      }
      if (_kurumYetersizlik == 'emin' ||
          _kurumSkr == 'emin' ||
          _kurumOdeme == 'emin' ||
          _kurumOdeme == 'yok' ||
          _kurumRam != 'evet' ||
          _kurumYetersizlik == null ||
          _kurumSkr == null) {
        return (
          kind: 'warn',
          title: 'Kurum evde destek için teyit gerekir',
          text:
              'Yanıtlarınıza göre belge veya şart belirsiz. Kararı merkez ve RAM verir; Engelsiz Club hak vaat etmez.',
        );
      }
      return (
        kind: 'ok',
        title: 'Bu yol rehabilitasyon merkezine aittir',
        text:
            'Özel eğitim ve rehabilitasyon merkezi, merkeze gelemeyen çocuğa evde destek verebilir. Bu, MEB evde eğitim değildir.',
      );
    }
    if (_sure == 'hayir' || _raporYazi == 'hayir') {
      return (
        kind: 'no',
        title: 'MEB evde eğitim bu kılavuza göre açılmaz',
        text:
            'En az 12 haftalık süre veya sağlık riski Durum Bildirir Sağlık Kurulu Raporu\'nda (SKR) yoksa okul öğretmeninin eve gelmesi bu yolla planlanmaz. Engelli raporu yüzdesi yeterli sayılmaz.',
      );
    }
    if (_sure == 'emin' ||
        _rapor == 'alinacak' ||
        _raporYazi == 'emin' ||
        _sure == null ||
        _rapor == null ||
        _raporYazi == null) {
      return (
        kind: 'warn',
        title: _missingDocs().isNotEmpty
            ? 'Şu belgeler eksik veya belirsiz'
            : 'Okul veya RAM ile teyit edin',
        text:
            'Yanıtlarınıza göre henüz net bir uygunluk görünmüyor. Resmi kararı Engelsiz Club veremez.',
      );
    }
    if (_rapor == 'yok') {
      return (
        kind: 'warn',
        title: 'Yola yakınsınız; sağlık kurulu raporu eksik',
        text:
            '12 haftalık gerekçe var görünüyor ama Durum Bildirir Sağlık Kurulu Raporu olmadan başvuru tamamlanmaz. Yüzde belgesi bu raporun yerine geçmez.',
      );
    }
    return (
      kind: 'ok',
      title: 'Bu yola uygun görünüyor',
      text:
          'Yanıtlarınız MEB evde eğitim kılavuzundaki ana şartlarla örtüşüyor. Karar yine okul, RAM ve kurulundadır.',
    );
  }

  List<String> _missingDocs() {
    if (_kurum) return const [];
    final list = <String>[
      if (_rapor != 'var') 'Durum Bildirir Sağlık Kurulu Raporu',
      'Veli veya vasi dilekçesi (okul veya RAM’a yazılı talep)',
      if (_kayit == 'evet')
        'Eğitsel Değerlendirme İstek Formu (okula kayıtlı öğrenciler için)',
    ];
    return list;
  }

  String _basvuruNereye() {
    if (_kurum) {
      return 'Çocuğunuzun gittiği veya gideceği özel eğitim ve rehabilitasyon merkezi';
    }
    if (_kayit == 'evet') return 'Kayıtlı okul müdürlüğü (okul RAM’a iletir)';
    if (_kayit == 'hayir') {
      return 'Doğrudan RAM (Rehberlik ve Araştırma Merkezi)';
    }
    return 'Kayıtlıysa okul müdürlüğü, değilse RAM';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? _validate() {
    switch (_step) {
      case _Wiz.hizmet:
        return _hizmet == null ? 'Hizmet türünü seçin.' : null;
      case _Wiz.sure:
        return _sure == null ? 'Bir seçenek işaretleyin.' : null;
      case _Wiz.rapor:
        return _rapor == null ? 'Bir seçenek işaretleyin.' : null;
      case _Wiz.raporYazi:
        return _raporYazi == null ? 'Bir seçenek işaretleyin.' : null;
      case _Wiz.kayit:
        return _kayit == null ? 'Bir seçenek işaretleyin.' : null;
      case _Wiz.model:
        return _egitim == null ? 'Eğitim modelini seçin.' : null;
      case _Wiz.kademe:
        return _kademe == null ? 'Kademe seçin.' : null;
      case _Wiz.kurumYetersizlik:
        return _kurumYetersizlik == null ? 'Bir seçenek işaretleyin.' : null;
      case _Wiz.kurumSkr:
        return _kurumSkr == null ? 'Bir seçenek işaretleyin.' : null;
      case _Wiz.kurumOdeme:
        return _kurumOdeme == null ? 'Bir seçenek işaretleyin.' : null;
      case _Wiz.kurumRam:
        return _kurumRam == null ? 'Bir seçenek işaretleyin.' : null;
      case _Wiz.ortam:
      case _Wiz.kurum:
      case _Wiz.results:
        return null;
    }
  }

  void _next() {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final i = _path.indexOf(_step);
    if (i < _path.length - 1) {
      setState(() {
        _error = null;
        _step = _path[i + 1];
      });
    }
  }

  void _back() {
    final i = _path.indexOf(_step);
    if (i > 0) {
      setState(() {
        _error = null;
        _step = _path[i - 1];
      });
    }
  }

  void _reset() {
    setState(() {
      _step = _Wiz.hizmet;
      _error = null;
      _saveNote = null;
      _saved = false;
      _hizmet = null;
      _sure = null;
      _rapor = null;
      _raporYazi = null;
      _kayit = null;
      _egitim = null;
      _kademe = null;
      _ortam = null;
      _kurumYetersizlik = null;
      _kurumSkr = null;
      _kurumOdeme = null;
      _kurumRam = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await insertEvdeEgitimBasvuru(
        hizmetTuru: _hizmet!,
        kademe: _kurum ? null : _kademe,
        haftalikDersSaati:
            _kurum || _kademe == null ? null : minHaftalikSaat(_kademe!),
        egitimTuru: _kurum ? null : _egitim,
      );
      if (!mounted) return;
      setState(() {
        _saved = true;
        _saveNote =
            'Özet hesabınıza kaydedildi. Ad, soyad ve T.C. yazılmaz. Resmi başvuru okul, RAM veya ilgili kurumadır.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saved = true;
        _saveNote = e.toString().contains('Oturum')
            ? 'Oturum yok. Özet bu cihazda kalır. Ad, soyad ve T.C. alınmaz. Hesaba yazmak için giriş yapın.'
            : 'Kayıt yazılamadı. SQL tabloları kurulmuş olmalı.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      body: Stack(
        children: [
          SafeArea(child: _buildLanding()),
          if (_showWizard) _buildWizard(),
        ],
      ),
    );
  }

  Widget _buildLanding() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: IconButton.styleFrom(
                backgroundColor: MetoColors.muted,
                shape: const CircleBorder(),
              ),
              icon: const Icon(Icons.arrow_back, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evde Eğitim',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: MetoColors.foreground,
                    ),
                  ),
                  Text(
                    'Şartları adım adım görün — ad, soyad ve T.C. sorulmaz',
                    style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A6B4A), Color(0xFF1A5C51)],
              ),
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _BannerIcon(),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Evde Eğitim Sihirbazı',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Birkaç soru. Her yanıtta şartlarınız açılır: sağlıyor / sağlamıyor.',
                              style: TextStyle(
                                color: Color(0xB3FFFFFF),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.white.withValues(alpha: 0.15),
                  child: InkWell(
                    onTap: () => setState(() {
                      _showWizard = true;
                      _step = _Wiz.hizmet;
                    }),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.20),
                          ),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sihirbazı Başlat',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Engelsiz Club başvuru yeri değildir. Kararı okul, RAM (Rehberlik ve Araştırma Merkezi) ve il/ilçe özel eğitim hizmetleri kurulu verir.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB45309),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => _openUrl(_kilavuzUrl),
                    child: const Text('Kılavuz 2025'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Evde Sağlık (Sağlık Bakanlığı, 444 38 33) ayrı bir hizmettir; bu sihirbazda seçilmez.',
          style: TextStyle(fontSize: 13, height: 1.55, color: MetoColors.mutedFg),
        ),
      ],
    );
  }

  Widget _buildWizard() {
    final continueLabel =
        _step == _Wiz.ortam || _step == _Wiz.kurum
            ? 'Sonucu göster'
            : 'Devam';
    return Material(
      color: MetoColors.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _showWizard = false),
                    style: IconButton.styleFrom(
                      backgroundColor: MetoColors.muted,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _step == _Wiz.results
                              ? 'Sonucunuz'
                              : 'Evde Eğitim Sihirbazı',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: MetoColors.foreground,
                          ),
                        ),
                        if (_step != _Wiz.results) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: List.generate(_qCount, (i) {
                              return Expanded(
                                child: Container(
                                  height: 6,
                                  margin: EdgeInsets.only(
                                    right: i < _qCount - 1 ? 6 : 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i <= _stepIndex
                                        ? MetoColors.primary
                                        : MetoColors.muted,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: MetoColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                children: [
                  _buildStep(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFF8C1D18)),
                      ),
                    ),
                  if (_step != _Wiz.results) ...[
                    _SartlarPanel(rows: _sartRows()),
                    const SizedBox(height: 24),
                    _ContinueButton(
                      enabled: !_busy,
                      label: continueLabel,
                      onPressed: _next,
                    ),
                    if (_step == _Wiz.ortam)
                      TextButton(
                        onPressed: () => setState(() {
                          _ortam = null;
                          _error = null;
                          _step = _Wiz.results;
                        }),
                        child: const Text('Bu soruyu atla'),
                      ),
                    if (_step != _Wiz.hizmet)
                      TextButton(
                        onPressed: _back,
                        child: const Text('← Geri'),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Wiz.hizmet:
        return _Question(
          emoji: '🏠',
          title: 'Hangi hizmet?',
          subtitle:
              'İki yol: okul öğretmeninin eve gelmesi veya rehabilitasyon merkezinin evde desteği.',
          children: [
            _OptionTile(
              title: '1) MEB Evde Eğitim',
              subtitle:
                  'Okul öğretmeni eve gelir. 12 hafta + Durum Bildirir Sağlık Kurulu Raporu (SKR). Yüzde aranmaz.',
              selected: _hizmet == 'evde_egitim_meb',
              onTap: () => setState(() => _hizmet = 'evde_egitim_meb'),
            ),
            _OptionTile(
              title: '2) Kurum Evde Destek Eğitimi',
              subtitle:
                  'Özel eğitim ve rehabilitasyon merkezi eve gelir. MEB evde eğitimin yerine geçmez.',
              selected: _hizmet == 'evde_destek_kurum',
              onTap: () => setState(() => _hizmet = 'evde_destek_kurum'),
            ),
          ],
        );
      case _Wiz.sure:
        return _Question(
          emoji: '🩺',
          title: 'Okula gidememe 12 haftayı buluyor mu?',
          subtitle:
              'Sağlık nedeniyle en az 12 hafta okula gidemeyecek mi, ya da gitmesi sağlığını riske atar mı?',
          children: [
            _OptionTile(
              title: 'Evet',
              subtitle: 'Uzun süre okula gidemeyecek veya gitmesi riskli',
              selected: _sure == 'evet',
              onTap: () => setState(() => _sure = 'evet'),
            ),
            _OptionTile(
              title: 'Hayır',
              subtitle: '12 haftalık sağlık gerekçesi yok',
              selected: _sure == 'hayir',
              onTap: () => setState(() => _sure = 'hayir'),
            ),
            _OptionTile(
              title: 'Emin değilim',
              subtitle: 'Okul veya RAM ile soracağız',
              selected: _sure == 'emin',
              onTap: () => setState(() => _sure = 'emin'),
            ),
          ],
        );
      case _Wiz.rapor:
        return _Question(
          emoji: '📋',
          title: 'Sağlık kurulu raporu var mı?',
          subtitle:
              'Bunu gösteren belge Durum Bildirir Sağlık Kurulu Raporu\'dur. Hastaneden çıkar; Engelsiz Club rapor vermez.',
          children: [
            _OptionTile(
              title: 'Var (Durum Bildirir Sağlık Kurulu Raporu elimizde)',
              subtitle: 'Hastane sağlık kurulundan çıkar',
              selected: _rapor == 'var',
              onTap: () => setState(() => _rapor = 'var'),
            ),
            _OptionTile(
              title: 'Henüz yok, alacağız',
              subtitle: 'Hastane sağlık kuruluna başvuracağız',
              selected: _rapor == 'alinacak',
              onTap: () => setState(() => _rapor = 'alinacak'),
            ),
            _OptionTile(
              title: 'Yok (Durum Bildirir Sağlık Kurulu Raporu yok)',
              subtitle: 'Bu belge olmadan resmi başvuru tamamlanmaz',
              selected: _rapor == 'yok',
              onTap: () => setState(() => _rapor = 'yok'),
            ),
          ],
        );
      case _Wiz.raporYazi:
        return _Question(
          emoji: '📝',
          title: 'Raporda 12 hafta veya sağlık riski yazıyor mu?',
          subtitle:
              'Durum Bildirir Sağlık Kurulu Raporu (SKR) süre veya risk belgesidir; yüzde belgesi değildir.',
          info:
              'Yönetmelik m.14 ve Kılavuz bölüm 2 yüzde istemez. Engelli raporu yüzdesi bu şartın yerine geçmez.',
          children: [
            _OptionTile(
              title: 'Evet, en az 12 hafta yazıyor',
              subtitle: 'Hastane raporunda süre belirtilmiş',
              selected: _raporYazi == 'evet',
              onTap: () => setState(() => _raporYazi = 'evet'),
            ),
            _OptionTile(
              title: 'Evet, sağlık riski yazıyor',
              subtitle: 'Okula gitmenin sağlığı riske attığı yazıyor',
              selected: _raporYazi == 'risk',
              onTap: () => setState(() => _raporYazi = 'risk'),
            ),
            _OptionTile(
              title: 'İkisi de yazıyor',
              subtitle: 'Hem süre hem risk belirtilmiş',
              selected: _raporYazi == 'ikisi',
              onTap: () => setState(() => _raporYazi = 'ikisi'),
            ),
            _OptionTile(
              title: 'Bunlar yazmıyor',
              subtitle: 'Yalnızca yüzde veya başka tanı var',
              selected: _raporYazi == 'hayir',
              onTap: () => setState(() => _raporYazi = 'hayir'),
            ),
            _OptionTile(
              title: 'Emin değilim',
              subtitle: 'Belgeyi okuyacağız veya hastane / RAM’a soracağız',
              selected: _raporYazi == 'emin',
              onTap: () => setState(() => _raporYazi = 'emin'),
            ),
          ],
        );
      case _Wiz.kayit:
        return _Question(
          emoji: '🏫',
          title: 'Okula kayıtlı mı?',
          subtitle:
              'Kayıtlıysa dilekçeyi okul müdürlüğüne verin. Kayıt yoksa doğrudan RAM’a gidin.',
          children: [
            _OptionTile(
              title: 'Evet, kayıtlı',
              subtitle: 'Okul, talebi RAM’a iletir',
              selected: _kayit == 'evet',
              onTap: () => setState(() => _kayit = 'evet'),
            ),
            _OptionTile(
              title: 'Hayır, kayıtlı değil',
              subtitle: 'Yazılı talebi RAM’a götürün',
              selected: _kayit == 'hayir',
              onTap: () => setState(() => _kayit = 'hayir'),
            ),
          ],
        );
      case _Wiz.model:
        return _Question(
          emoji: '👩‍🏫',
          title: 'Dersler yüz yüze mi, uzaktan mı?',
          subtitle:
              'Öncelik evde yüz yüze derstir. Uzaktan canlı ders ancak kurul kararıyla olur.',
          children: [
            _OptionTile(
              title: 'Yüz yüze',
              subtitle:
                  'Öğretmen eve gelir. Evde temizlik, ısınma, ışık ve havalandırma yeterli olmalıdır.',
              selected: _egitim == 'yuz_yuze',
              onTap: () => setState(() => _egitim = 'yuz_yuze'),
            ),
            _OptionTile(
              title: 'Uzaktan canlı ders',
              subtitle:
                  'Veli talebi, sağlık riski veya öğretmen bulunamaması halinde kurul karar verir.',
              selected: _egitim == 'uzaktan_canli',
              onTap: () => setState(() => _egitim = 'uzaktan_canli'),
            ),
          ],
        );
      case _Wiz.kademe:
        return _Question(
          emoji: '📚',
          title: 'Hangi kademe?',
          subtitle:
              'Haftalık saat kılavuza göredir. Sizin sayı yazmanız gerekmez; planı kurul ve okul yapar.',
          children: [
            _OptionTile(
              title: 'İlköğretim',
              subtitle: 'Haftada en az 10 ders saati',
              selected: _kademe == 'ilkogretim',
              onTap: () => setState(() => _kademe = 'ilkogretim'),
            ),
            _OptionTile(
              title: 'Özel eğitim ortaöğretim',
              subtitle: 'Haftada en az 10 ders saati',
              selected: _kademe == 'ortaogretim_ozel',
              onTap: () => setState(() => _kademe = 'ortaogretim_ozel'),
            ),
            _OptionTile(
              title: 'Diğer ortaöğretim',
              subtitle: 'Haftada en az 16 ders saati',
              selected: _kademe == 'ortaogretim',
              onTap: () => setState(() => _kademe = 'ortaogretim'),
            ),
          ],
        );
      case _Wiz.ortam:
        return _Question(
          emoji: '🏡',
          title: 'Ev ortamı elverişli mi?',
          subtitle:
              'Yüz yüze ders için evin temiz, ılık, aydınlık ve havalandırılabilir olması beklenir. İsterseniz atlayabilirsiniz.',
          children: [
            _OptionTile(
              title: 'Evet, elverişli',
              subtitle: 'Ders için uygun bir yer var',
              selected: _ortam == 'evet',
              onTap: () => setState(() => _ortam = 'evet'),
            ),
            _OptionTile(
              title: 'Hayır, şu an elverişli değil',
              subtitle: 'Kurul uzaktan ders önerebilir',
              selected: _ortam == 'hayir',
              onTap: () => setState(() => _ortam = 'hayir'),
            ),
          ],
        );
      case _Wiz.kurumYetersizlik:
        return _Question(
          emoji: '♿',
          title: 'Bedensel yetersizlik var mı?',
          subtitle:
              'Özel Eğitim Kurumları Yönetmeliği m.25/10 evde desteği bedensel yetersizliğe bağlar. Saat oranla değişmez.',
          children: [
            _OptionTile(
              title: 'Evet',
              subtitle: 'Bedensel yetersizlik tanısı var',
              selected: _kurumYetersizlik == 'evet',
              onTap: () => setState(() => _kurumYetersizlik = 'evet'),
            ),
            _OptionTile(
              title: 'Hayır',
              subtitle: 'Bedensel yetersizlik yok',
              selected: _kurumYetersizlik == 'hayir',
              onTap: () => setState(() => _kurumYetersizlik = 'hayir'),
            ),
            _OptionTile(
              title: 'Emin değilim',
              subtitle: 'RAM veya merkezle soracağız',
              selected: _kurumYetersizlik == 'emin',
              onTap: () => setState(() => _kurumYetersizlik = 'emin'),
            ),
          ],
        );
      case _Wiz.kurumSkr:
        return _Question(
          emoji: '📋',
          title: 'Merkeze gidememe raporu var mı?',
          subtitle:
              'Durum Bildirir Sağlık Kurulu Raporu\'nda merkeze gidememe veya sağlık riski yazmalıdır. Yüzde belgesi değildir.',
          children: [
            _OptionTile(
              title: 'Var (Durum Bildirir Sağlık Kurulu Raporu elimizde)',
              subtitle: 'Raporda merkeze gidememe veya sağlık riski yazıyor',
              selected: _kurumSkr == 'evet',
              onTap: () => setState(() => _kurumSkr = 'evet'),
            ),
            _OptionTile(
              title: 'Yok (Durum Bildirir Sağlık Kurulu Raporu yok)',
              subtitle: 'Bu belge yok veya merkeze gidememe yazılmamış',
              selected: _kurumSkr == 'hayir',
              onTap: () => setState(() => _kurumSkr = 'hayir'),
            ),
            _OptionTile(
              title: 'Emin değilim',
              subtitle: 'Hastane veya merkezle soracağız',
              selected: _kurumSkr == 'emin',
              onTap: () => setState(() => _kurumSkr = 'emin'),
            ),
          ],
        );
      case _Wiz.kurumOdeme:
        return _Question(
          emoji: '📑',
          title: 'Devlet ödemeli destek için hangi belge?',
          subtitle:
              '652 KHK m.43: 18 altı ÇÖZGER (Çocuklar İçin Özel Gereksinim Raporu, yüzde yok), 18+ en az %20 ESKR (Erişkinler İçin Engellilik Sağlık Kurulu Raporu). Saat değişmez.',
          children: [
            _OptionTile(
              title: '18 yaş altı — ÇÖZGER (Çocuklar İçin Özel Gereksinim Raporu)',
              subtitle: 'Özel gereksinim yazıyor; yüzde aranmaz',
              selected: _kurumOdeme == 'cocuk_cozger',
              onTap: () => setState(() => _kurumOdeme = 'cocuk_cozger'),
            ),
            _OptionTile(
              title: '18+ — en az %20 ESKR (Erişkinler İçin Engellilik Sağlık Kurulu Raporu)',
              subtitle: 'KHK m.43\'teki tek resmi yüzde bandı',
              selected: _kurumOdeme == 'yetiskin_20',
              onTap: () => setState(() => _kurumOdeme = 'yetiskin_20'),
            ),
            _OptionTile(
              title: 'Bu belgeler yok',
              subtitle: 'Devlet ödemesi açılmayabilir',
              selected: _kurumOdeme == 'yok',
              onTap: () => setState(() => _kurumOdeme = 'yok'),
            ),
            _OptionTile(
              title: 'Emin değilim',
              subtitle: 'RAM veya merkezle soracağız',
              selected: _kurumOdeme == 'emin',
              onTap: () => setState(() => _kurumOdeme = 'emin'),
            ),
          ],
        );
      case _Wiz.kurumRam:
        return _Question(
          emoji: '🏫',
          title: 'RAM (Rehberlik ve Araştırma Merkezi) destek eğitimi öneriyor mu?',
          subtitle:
              'Özel Eğitim Değerlendirme Kurulu Raporu destek eğitimi önermelidir.',
          children: [
            _OptionTile(
              title: 'Evet, öneriyor',
              subtitle: 'RAM raporu destek eğitimi yazıyor',
              selected: _kurumRam == 'evet',
              onTap: () => setState(() => _kurumRam = 'evet'),
            ),
            _OptionTile(
              title: 'Hayır / rapor yok',
              subtitle: 'RAM değerlendirmesi yok',
              selected: _kurumRam == 'hayir',
              onTap: () => setState(() => _kurumRam = 'hayir'),
            ),
            _OptionTile(
              title: 'Emin değilim',
              subtitle: 'RAM’a soracağız',
              selected: _kurumRam == 'emin',
              onTap: () => setState(() => _kurumRam = 'emin'),
            ),
          ],
        );
      case _Wiz.kurum:
        return const _Question(
          emoji: '🏥',
          title: 'Kurum evde destek nedir?',
          subtitle:
              'Rehabilitasyon merkezi, merkeze gelemeyen çocuğa evde destek verebilir. Bu, okul öğretmeninin eve gelmesi değildir.',
          info:
              'Aylık 8 saat bireysel ve/veya 4 saat grup. Oran veya derece saati değiştirmez.',
          infoWarn: true,
          children: [],
        );
      case _Wiz.results:
        return _buildResults();
    }
  }

  Widget _buildResults() {
    final out = _outcome();
    final Color bannerBg;
    final Color bannerFg;
    if (out.kind == 'ok') {
      bannerBg = MetoColors.primary.withValues(alpha: 0.07);
      bannerFg = MetoColors.primary;
    } else if (out.kind == 'no') {
      bannerBg = const Color(0xFFFDECEA);
      bannerFg = const Color(0xFF8C1D18);
    } else {
      bannerBg = const Color(0xFFFFFBEB);
      bannerFg = const Color(0xFFB45309);
    }
    final prefix = out.kind == 'ok' ? '✓ ' : out.kind == 'no' ? '✕ ' : '⚠ ';
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bannerBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '$prefix${out.title}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: bannerFg,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            out.text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: MetoColors.mutedFg,
            ),
          ),
        ),
        if (_saveNote != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6EE),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _saveNote!,
              style: const TextStyle(color: Color(0xFF0F5132), fontSize: 13),
            ),
          ),
        ],
        _SartlarPanel(rows: _sartRows()),
        const SizedBox(height: 12),
        if (_kurum)
          _ResultCard(
            icon: '🏥',
            bg: const Color(0xFFF5EEFB),
            color: const Color(0xFF6B21A8),
            title: 'Kurum Evde Destek Eğitimi',
            badge: 'Rehabilitasyon merkezi',
            desc:
                '5580 sayılı Kanun kapsamındaki özel eğitim ve rehabilitasyon merkezinin evde verdiği destektir.',
            steps: const [
              'MEB evde eğitimin yerine geçmez.',
              'Başvuruyu merkeze yapın.',
            ],
            where: _basvuruNereye(),
          )
        else ...[
          _ResultCard(
            icon: '📍',
            bg: const Color(0xFFE0F2FE),
            color: const Color(0xFF075985),
            title: 'Resmi başvuru nereye?',
            badge: _kayit == 'hayir' ? 'RAM' : 'Okul / RAM',
            desc:
                'Engelsiz Club dilekçe kabul etmez. Yazılı talebi aşağıdaki yere verin.',
            steps: _missingDocs().isEmpty
                ? const ['Veli dilekçesi ve sağlık kurulu raporu ile başvurun.']
                : _missingDocs().map((d) => 'Gerekli: $d').toList(),
            where: _basvuruNereye(),
          ),
          const _ResultCard(
            icon: '💻',
            bg: Color(0xFFFEF3C7),
            color: Color(0xFFB45309),
            title: 'e-Okul uyarısı',
            badge: 'Yalnızca okul müdürlüğü',
            desc:
                'Kabul sonrası okul, e-Okul’da «Özel Eğitim Durumu: Evde Eğitim Alıyor» işaretini koyar. Bu işaret olmadan devam-devamsızlık işlemleri oluşmaz.',
            steps: ['Engelsiz Club bu işareti koyamaz.'],
            where: 'Yalnızca kayıtlı okul müdürlüğü',
          ),
        ],
        if (!_saved) ...[
          const SizedBox(height: 8),
          _ContinueButton(
            enabled: !_busy,
            label: 'Özeti kaydet',
            onPressed: _save,
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _reset,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: const BorderSide(color: MetoColors.border),
          ),
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text(
            'Yeniden Sorgula',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(onPressed: _back, child: const Text('← Geri')),
      ],
    );
  }
}

class _SartlarPanel extends StatelessWidget {
  const _SartlarPanel({required this.rows});

  final List<_SartRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: MetoColors.card,
            border: Border.all(color: MetoColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: MetoColors.muted,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Text(
                  'Şartlarınız',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
              ...rows.map((r) {
                final Color bg;
                final Color markBg;
                final Color badgeBg;
                final Color badgeFg;
                switch (r.status) {
                  case _Sart.ok:
                    bg = const Color(0xFFE8F6EE);
                    markBg = const Color(0xFF0F5132);
                    badgeBg = const Color(0xFFC6EBD4);
                    badgeFg = const Color(0xFF0F5132);
                  case _Sart.no:
                    bg = const Color(0xFFFDECEA);
                    markBg = const Color(0xFF8C1D18);
                    badgeBg = const Color(0xFFF8C9C6);
                    badgeFg = const Color(0xFF8C1D18);
                  case _Sart.maybe:
                    bg = const Color(0xFFFFFBEB);
                    markBg = const Color(0xFFB45309);
                    badgeBg = const Color(0xFFFDE68A);
                    badgeFg = const Color(0xFFB45309);
                  case _Sart.info:
                    bg = const Color(0xFFF5EEFB);
                    markBg = const Color(0xFF6B21A8);
                    badgeBg = const Color(0xFFE9D5FF);
                    badgeFg = const Color(0xFF6B21A8);
                }
                return ColoredBox(
                  color: bg,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: markBg,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            r.mark,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                  letterSpacing: 0,
                                  color: MetoColors.foreground,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r.note,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: MetoColors.mutedFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            r.badge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerIcon extends StatelessWidget {
  const _BannerIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.auto_fix_high, color: Colors.white, size: 28),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.children,
    this.info,
    this.infoWarn = false,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String? info;
  final bool infoWarn;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.35,
            letterSpacing: 0,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: MetoColors.mutedFg,
          ),
        ),
        if (info != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: infoWarn
                  ? const Color(0xFFFFFBEB)
                  : const Color(0xFFF5EEFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: infoWarn
                    ? const Color(0xFFFDE68A)
                    : const Color(0xFFD4B3F0),
              ),
            ),
            child: Text(
              info!,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: infoWarn
                    ? const Color(0xFFB45309)
                    : const Color(0xFF6B21A8),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        ...children.map(
          (w) => w is _OptionTile
              ? Padding(padding: const EdgeInsets.only(bottom: 12), child: w)
              : w,
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? MetoColors.primary.withValues(alpha: 0.07)
          : MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? MetoColors.primary : MetoColors.muted,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        letterSpacing: 0,
                        color: selected
                            ? MetoColors.primary
                            : MetoColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? MetoColors.primary : MetoColors.muted,
                    width: 2,
                  ),
                  color: selected ? MetoColors.primary : Colors.transparent,
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: MetoColors.primary,
          disabledBackgroundColor: MetoColors.primary.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.icon,
    required this.bg,
    required this.color,
    required this.title,
    required this.badge,
    required this.desc,
    required this.steps,
    required this.where,
  });

  final String icon;
  final Color bg;
  final Color color;
  final String title;
  final String badge;
  final String desc;
  final List<String> steps;
  final String where;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MetoColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              where,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:engelsizclub/admin_config.dart';
import 'package:engelsizclub/app_sections_store.dart';
import 'package:engelsizclub/pages/uzman_kosesi_cv_detail_page.dart';
import 'package:engelsizclub/pages/uzman_kosesi_kurum_ilan_detail_page.dart';
import 'package:engelsizclub/pages/uzman_kosesi_page.dart';
import 'package:engelsizclub/uzman_kosesi/expert_cv_models.dart';
import 'package:engelsizclub/uzman_kosesi/expert_reviews_store.dart';
import 'package:engelsizclub/uzman_kosesi/kurum_is_ilan_models.dart';
import 'package:engelsizclub/uzman_kosesi/uzman_kose_bolum.dart';
import 'package:engelsizclub/uzman_kosesi/uzman_kosesi_notify.dart';
import 'package:engelsizclub/uzman_kosesi_profiles_store.dart';
import 'package:engelsizclub/widgets/catalog_media.dart';
import 'package:engelsizclub/widgets/uzman_kosesi_home_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default Uzman Köşesi key and title are not empty', () {
    expect(kUzmanKosesSectionKey, 'uzman_kosesi');
    expect(kDefaultUzmanKosesSection.title, 'Uzman Profilleri Köşesi');
    expect(kDefaultUzmanKosesSection.coverImageUrl, isEmpty);
    expect(kDefaultUzmanKosesSection.hasCover, isFalse);
  });

  test('AppSection.fromJson trims fields', () {
    final row = AppSection.fromJson({
      'section_key': ' Uzman_Kosesi ',
      'title': '  Köşe  ',
      'cover_image_url': ' https://x/y.jpg ',
    });
    expect(row.sectionKey, 'uzman_kosesi');
    expect(row.title, 'Köşe');
    expect(row.coverImageUrl, 'https://x/y.jpg');
    expect(row.hasCover, isTrue);
  });

  test('only app admin may edit', () {
    expect(isAppAdmin('sakir.caykara@gmail.com'), isTrue);
    expect(isAppAdmin('uye@example.com'), isFalse);
    expect(isAppAdmin(''), isFalse);
  });

  testWidgets('guest sees default title and no edit icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UzmanKosesHomeSection(userEmail: ''),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Uzman Profilleri Köşesi'), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('admin sees edit icon on the card', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UzmanKosesHomeSection(
              userEmail: 'sakir.caykara@gmail.com',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Uzman Profilleri Köşesi'), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('card spans the same width as two home tiles', (tester) async {
    const gap = 12.0;
    const pad = 16.0;
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UzmanKosesHomeSection(userEmail: ''),
          ),
        ),
      ),
    );
    await tester.pump();
    final box = tester.getSize(find.byType(UzmanKosesHomeSection));
    expect(box.width, 400);
    final titles = find.text('Uzman Profilleri Köşesi');
    expect(tester.getSize(titles.last).width, 400 - pad * 2);
    expect(400 - pad * 2, ((400 - pad * 2 - gap) / 2) * 2 + gap);
  });

  testWidgets('tap opens dedicated page, not forum', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UzmanKosesHomeSection(userEmail: ''),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.byType(UzmanKosesPage), findsOneWidget);
    expect(find.text('Forum'), findsNothing);
    expect(
      find.textContaining('Uzmanlar burada deneyim'),
      findsNothing,
    );
    expect(find.text('Profil oluştur'), findsNothing);
  });

  testWidgets('inner page does not show the home cover image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UzmanKosesPage(userEmail: ''),
      ),
    );
    await tester.pump();
    expect(find.byType(UzmanKosesPage), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
  });

  testWidgets('inner page shows four section filter boxes on top', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UzmanKosesPage(userEmail: ''),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Sağlık Uzmanları'), findsOneWidget);
    expect(find.text('Kurum İş İlanları'), findsOneWidget);
    expect(find.text('Bakım Desteği'), findsOneWidget);
    expect(find.text('Ev Desteği'), findsOneWidget);
    expect(find.text('Tümü'), findsNothing);
    expect(find.text('Bakım ve Ev Desteği'), findsNothing);
    expect(find.text('Tüm iller'), findsOneWidget);
    expect(find.text('Tüm ilçeler'), findsOneWidget);
    expect(find.text('Tüm meslekler'), findsOneWidget);
    expect(find.text('İsim, meslek veya şehir ara'), findsNothing);
    expect(find.text('Onaylı'), findsNothing);
    expect(find.text('İş ilanı yayınla'), findsNothing);
    expect(find.text('Kurum iş ilanı yayınla'), findsOneWidget);

    await tester.tap(find.text('Kurum İş İlanları'));
    await tester.pump();
    expect(find.text('İş ilanı yayınla'), findsNothing);
    expect(find.text('Kurum iş ilanı yayınla'), findsOneWidget);
  });

  test('admin gets approval notice copy when a profile is submitted', () {
    const p = ExpertCvProfile(
      id: 9,
      fullName: 'Ayşe Yılmaz',
      meslekEtiket: 'Fizyoterapist',
      il: 'Ankara',
      ilce: 'Çankaya',
    );
    expect(uzmanOnayBildirimBaslik(p), 'Uzman Onayları: Ayşe Yılmaz');
    expect(uzmanOnayBildirimMetni(p), contains('onay bekliyor'));
    expect(uzmanOnayBildirimMetni(p), contains('Fizyoterapist'));
    expect(uzmanOnayBildirimMetni(p), contains('Ankara / Çankaya'));
    expect(uzmanOnayBildirimRef(9), 'uo:9');
    expect(kUzmanOnayBildirimTip, 'uzman_onay');
  });

  test('admin publish notice invites users to tap the profile', () {
    const p = UzmanKosesProfil(
      fullName: 'Ayşe Yılmaz',
      meslek: 'Fizyoterapist',
      il: 'Ankara',
      ilce: 'Çankaya',
    );
    expect(
      uzmanProfilYayinBildirimBaslik(p),
      'Ayşe Yılmaz · Fizyoterapist profili yayınlandı',
    );
    expect(
      uzmanProfilYayinBildirimMetni(p),
      contains('Fizyoterapist profili Uzman Profilleri Köşesi’nde yayınlandı'),
    );
    expect(uzmanProfilYayinBildirimMetni(p), contains('İncelemek için tıklayın'));
    expect(uzmanProfilYayinBildirimMetni(p), contains('Ankara / Çankaya'));
  });

  test('yer filter matches il then ilce, ignoring Turkish case', () {
    const p = UzmanKosesProfil(
      fullName: 'Ayşe Yılmaz',
      meslek: 'Fizyoterapist',
      il: 'Ankara',
      ilce: 'Çankaya',
    );
    expect(uzmanKosesMatchesYer(p), isTrue);
    expect(uzmanKosesMatchesYer(p, il: 'ankara'), isTrue);
    expect(uzmanKosesMatchesYer(p, il: 'İstanbul'), isFalse);
    expect(uzmanKosesMatchesYer(p, il: 'Ankara', ilce: 'cankaya'), isTrue);
    expect(uzmanKosesMatchesYer(p, il: 'Ankara', ilce: 'Keçiören'), isFalse);
  });

  test('profile card shows meslek, name and il / ilce', () {
    const p = UzmanKosesProfil(
      fullName: 'Ayşe Yılmaz',
      meslek: 'Fizyoterapist',
      il: 'Ankara',
      ilce: 'Çankaya',
      deneyimYili: 8,
      dogrulandi: true,
      photoUrl: 'https://cdn.example.com/ayse.jpg',
    );
    expect(p.meslek, 'Fizyoterapist');
    expect(p.fullName, 'Ayşe Yılmaz');
    expect(p.yerLabel, 'Ankara / Çankaya');
    expect(p.tamSatir, isFalse);
    const wide = UzmanKosesProfil(
      fullName: 'Ayşe Yılmaz',
      meslek: 'Fizyoterapist',
      il: 'Ankara',
      ilce: 'Çankaya',
      kartSpan: 2,
    );
    expect(wide.tamSatir, isTrue);
    expect(p.deneyimYili, 8);
    expect(p.dogrulandi, isTrue);
    expect(p.photoUrl, contains('ayse.jpg'));
  });

  test('meslek list includes uzman ara and bakici roles', () {
    final list = uzmanKosesMeslekSecenekleri();
    expect(list, contains('Fizyoterapist'));
    expect(list, contains('Bakıcı'));
    expect(list, contains('Ev Yardımı'));
  });

  test('filter meslek list includes all catalog jobs not only listed ones', () {
    final onlyFizyo = uzmanKosesListedMeslekler(const [
      UzmanKosesProfil(meslek: 'Fizyoterapist'),
    ]);
    expect(onlyFizyo, ['Fizyoterapist']);
    final filter = uzmanKosesFiltreMeslekleri(extra: onlyFizyo);
    expect(filter, contains('Fizyoterapist'));
    expect(filter, contains('Ergoterapist'));
    expect(filter, contains('Dil Konuşma Terapisti'));
    expect(filter, contains('Özel Eğitim Öğretmeni'));
    expect(filter, contains('Gölge Öğretmen'));
    expect(filter, contains('Psikolog'));
    expect(filter, contains('Bakıcı'));
    expect(filter, contains('Ev Yardımı'));
  });

  test('only destek veren can create a profile', () {
    expect(
      canCreateUzmanKosesProfil(
        isGuest: false,
        userEmail: 'a@b.com',
        userType: 'uzman',
      ),
      isTrue,
    );
    expect(
      canCreateUzmanKosesProfil(
        isGuest: false,
        userEmail: 'a@b.com',
        userType: 'bakici',
      ),
      isTrue,
    );
    expect(
      canCreateUzmanKosesProfil(
        isGuest: false,
        userEmail: 'a@b.com',
        userType: 'aile',
      ),
      isFalse,
    );
    expect(
      canCreateUzmanKosesProfil(
        isGuest: true,
        userEmail: '',
        userType: 'uzman',
      ),
      isFalse,
    );
    expect(
      canCreateUzmanKosesProfil(
        isGuest: false,
        userEmail: 'sakir.caykara@gmail.com',
        userType: 'aile',
      ),
      isFalse,
    );
  });

  testWidgets('therapist profile uses hero layout, cards and sticky actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const preview = ExpertCvProfile(
      fullName: 'Muhammet Baki Ünal',
      meslekEtiket: 'Fizyoterapist',
      calismaSekli: ['Ev ziyareti', 'Klinik'],
      musaitlik: ['Hafta içi'],
      engelliDeneyimi: true,
      meslekDetaylari: {
        'universite': 'Hacettepe Üniversitesi',
        'mezuniyet_yili': '2021',
        'uzmanlik_alanlari': [
          'Pediatrik',
          'Nörolojik rehabilitasyon',
        ],
        'uzmanlik_ilgi': 'Pediatrik rehabilitasyon',
        'engel_gruplari': [
          'Serebral palsi',
          'Down sendromu',
          'İnme',
          'Kas hastalıkları',
        ],
        'seans_suresi': '45–55 dk',
        'ekipman': true,
        'ev_ziyareti': true,
        'belgeler':
            'Duyu bütünleme → Yeşim Ünveren Akademi\nHalliwick → Johan Lambeck',
        'sertifikalar': ['Yutma rehabilitasyonu → Tomris Duymaz'],
      },
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: UzmanKosesCvDetailPage(preview: preview),
      ),
    );
    await tester.pump();
    expect(find.text('Terapist profili'), findsOneWidget);
    expect(find.text('Muhammet Baki Ünal'), findsOneWidget);
    expect(find.text('Pediatrik ve Nörolojik rehabilitasyon'), findsOneWidget);
    expect(find.text('2021 mezunu'), findsOneWidget);
    expect(find.text('Ev ziyareti'), findsWidgets);
    expect(find.text('Klinik'), findsOneWidget);
    expect(find.text('Hafta içi'), findsOneWidget);
    expect(find.text('Seans süresi'), findsOneWidget);
    expect(find.text('45–55 dk'), findsOneWidget);
    expect(find.text('Kendi ekipmanı'), findsOneWidget);
    expect(find.text('Çalıştığı gruplar'), findsOneWidget);
    expect(find.text('Serebral palsi'), findsOneWidget);
    expect(find.text('Uzmanlık alanları'), findsOneWidget);
    expect(find.text('Sertifikalar'), findsOneWidget);
    expect(find.text('Yeşim Ünveren Akademi'), findsOneWidget);
    expect(find.text('Mesaj gönder'), findsOneWidget);
    expect(find.text('Randevu talep et'), findsOneWidget);
    expect(find.text(kUzmanYorumYok), findsOneWidget);
    expect(find.text('Yorumlar'), findsOneWidget);
    expect(find.text('İletişime geç'), findsNothing);
  });

  testWidgets('bakici profile is not therapist layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const preview = ExpertCvProfile(
      fullName: 'Ayşe Demir',
      meslekEtiket: 'Bakıcı',
      ustGrup: 'Bakım ve Ev Desteği',
      calismaSekli: ['Yatılı', 'Gündüz'],
      engelliDeneyimi: true,
      meslekDetaylari: {
        'bakim_turu': ['Yaşlı', 'Engelli'],
        'yapabildikleri': ['Hijyen bakımı', 'Yemek hazırlama'],
        'calisma_duzeni': ['Yatılı'],
        'tercih_sigara': 'Sigara içilmeyen ev',
        kUzmanMezunBolumKey: 'Hasta ve Yaşlı Hizmetleri',
        'seans_suresi': '45–55 dk',
        'ekipman': true,
        'universite': 'Hacettepe Üniversitesi',
        'mezuniyet_yili': '2021',
      },
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: UzmanKosesCvDetailPage(preview: preview),
      ),
    );
    await tester.pump();
    expect(find.text('Terapist profili'), findsNothing);
    expect(find.text('Bakıcı profili'), findsOneWidget);
    expect(find.text('Ayşe Demir'), findsOneWidget);
    expect(find.text('Seans süresi'), findsNothing);
    expect(find.text('Kendi ekipmanı'), findsNothing);
    expect(find.text('Randevu talep et'), findsNothing);
    expect(find.text('Hizmet talep et'), findsOneWidget);
    expect(find.text('Yapabildikleri'), findsOneWidget);
    expect(find.text('Hijyen bakımı'), findsOneWidget);
    expect(find.text('Bakım / hizmet'), findsOneWidget);
    expect(find.text('Çalışma düzeni'), findsOneWidget);
    expect(find.text('Mezun olunan bölüm'), findsOneWidget);
    expect(find.text('Hasta ve Yaşlı Hizmetleri'), findsWidgets);
    expect(find.text('Hacettepe Üniversitesi'), findsNothing);
    expect(find.text('2021 mezunu'), findsNothing);
    expect(find.text('Mesaj gönder'), findsOneWidget);
  });

  testWidgets('profile reviews show stars out of five', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const preview = ExpertCvProfile(fullName: 'Muhammet Baki Ünal');
    await tester.pumpWidget(
      MaterialApp(
        home: UzmanKosesCvDetailPage(
          preview: preview,
          previewReviews: const [
            ExpertReview(
              authorName: 'Ayşe',
              rating: 5,
              body: 'Çok ilgili bir terapist.',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text(kUzmanYorumYok), findsNothing);
    expect(find.text('5.0 / 5'), findsWidgets);
    expect(find.text('Çok ilgili bir terapist.'), findsOneWidget);
  });

  test('admin can delete any expert review, member only own', () {
    expect(
      canDeleteExpertReview(
        viewerEmail: 'sakir.caykara@gmail.com',
        authorEmail: 'uye@engelsizclub.com',
      ),
      isTrue,
    );
    expect(
      canDeleteExpertReview(
        viewerEmail: 'uye@engelsizclub.com',
        authorEmail: 'uye@engelsizclub.com',
      ),
      isTrue,
    );
    expect(
      canDeleteExpertReview(
        viewerEmail: 'uye@engelsizclub.com',
        authorEmail: 'baska@engelsizclub.com',
      ),
      isFalse,
    );
  });

  testWidgets('admin sees delete on another member review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const preview = ExpertCvProfile(fullName: 'Muhammet Baki Ünal');
    await tester.pumpWidget(
      const MaterialApp(
        home: UzmanKosesCvDetailPage(
          preview: preview,
          userEmail: 'sakir.caykara@gmail.com',
          previewReviews: [
            ExpertReview(
              authorName: 'Ayşe',
              authorEmail: 'uye@engelsizclub.com',
              rating: 5,
              body: 'Çok ilgili bir terapist.',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('Yorumu sil (Admin)'), findsOneWidget);
  });

  testWidgets('member does not see delete on another review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const preview = ExpertCvProfile(fullName: 'Muhammet Baki Ünal');
    await tester.pumpWidget(
      const MaterialApp(
        home: UzmanKosesCvDetailPage(
          preview: preview,
          userEmail: 'uye@engelsizclub.com',
          previewReviews: [
            ExpertReview(
              authorName: 'Ayşe',
              authorEmail: 'baska@engelsizclub.com',
              rating: 4,
              body: 'İyi bir uzman.',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('Yorumu sil (Admin)'), findsNothing);
    expect(find.byTooltip('Yorumu sil'), findsNothing);
  });

  testWidgets('profile owner sees unique viewer count', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const preview = ExpertCvProfile(fullName: 'Muhammet Baki Ünal');
    await tester.pumpWidget(
      const MaterialApp(
        home: UzmanKosesCvDetailPage(
          preview: preview,
          previewAsOwner: true,
          previewViewCount: 12,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('12 kişi baktı'), findsOneWidget);
    expect(find.text('Mesaj gönder'), findsNothing);
    expect(find.text(kUzmanIlanSil), findsWidgets);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
    expect(find.text('Düzenle'), findsWidgets);
  });

  testWidgets('members see workplace address, guests see login hint',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const preview = ExpertCvProfile(
      fullName: 'Muhammet Baki Ünal',
      meslekDetaylari: {
        kUzmanIsYeriAdresKey: 'Bağdat Cad. No:10 Kadıköy',
      },
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: UzmanKosesCvDetailPage(
          preview: preview,
          userEmail: 'uye@engelsizclub.com',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('İş yeri adresi'), findsOneWidget);
    expect(find.text('Bağdat Cad. No:10 Kadıköy'), findsOneWidget);
    expect(find.text(kUzmanIsYeriAdresGirisNotu), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: UzmanKosesCvDetailPage(
          preview: preview,
          isGuest: true,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('İş yeri adresi'), findsOneWidget);
    expect(find.text('Bağdat Cad. No:10 Kadıköy'), findsNothing);
    expect(find.text(kUzmanIsYeriAdresGirisNotu), findsOneWidget);
  });

  test('listing filters by query, meslek, city and verified', () {
    const ayse = UzmanKosesProfil(
      fullName: 'Ayşe Yılmaz',
      meslek: 'Fizyoterapist',
      ustGrup: 'Sağlık Uzmanları',
      il: 'Ankara',
      ilce: 'Çankaya',
      dogrulandi: true,
    );
    const mehmet = UzmanKosesProfil(
      fullName: 'Mehmet Demir',
      meslek: 'Bakıcı',
      ustGrup: 'Bakım ve Ev Desteği',
      il: 'İstanbul',
      ilce: 'Kadıköy',
    );
    const ali = UzmanKosesProfil(
      fullName: 'Ali Kaya',
      meslek: 'Fizyoterapist',
      ustGrup: 'Sağlık Uzmanları',
      il: 'İstanbul',
      ilce: 'Beşiktaş',
      kartSpan: 2,
    );
    const all = [ayse, mehmet, ali];

    expect(uzmanKosesMatchesQuery(ayse, 'fizyo ankara'), isTrue);
    expect(uzmanKosesMatchesQuery(ayse, 'ayse'), isFalse);
    expect(uzmanKosesMatchesQuery(mehmet, 'fizyo'), isFalse);
    expect(uzmanKosesMetinIcerir('İstanbul', 'ist'), isTrue);
    expect(
      uzmanKosesListedMeslekler(all),
      ['Bakıcı', 'Fizyoterapist'],
    );
    expect(
      uzmanKosesListedMeslekler(all, ustGrup: 'Bakım ve Ev Desteği'),
      ['Bakıcı'],
    );

    final fizyo = uzmanKosesFiltrele(all, meslek: 'fizyoterapist');
    expect(fizyo.map((p) => p.fullName), ['Ali Kaya', 'Ayşe Yılmaz']);
    expect(
      uzmanKosesFiltrele(all, query: 'kadikoy').single.fullName,
      'Mehmet Demir',
    );
    expect(
      uzmanKosesFiltrele(all, il: 'İstanbul', meslek: 'Fizyoterapist')
          .single
          .fullName,
      'Ali Kaya',
    );
    expect(
      uzmanKosesFiltrele(all, onlyVerified: true).single.fullName,
      'Ayşe Yılmaz',
    );
    expect(uzmanKosesFiltrele(all, query: 'xyz'), isEmpty);
  });

  test('profiles split into saglik, bakim and ev headings', () {
    const fizyo = UzmanKosesProfil(
      fullName: 'Ayşe',
      meslek: 'Fizyoterapist',
      ustGrup: 'Sağlık Uzmanları',
    );
    const bakici = UzmanKosesProfil(
      fullName: 'Mehmet',
      meslek: 'Bakıcı',
      ustGrup: 'Bakım ve Ev Desteği',
    );
    const ev = UzmanKosesProfil(
      fullName: 'Elif',
      meslek: 'Ev Yardımı',
      ustGrup: 'Bakım ve Ev Desteği',
    );
    expect(uzmanKoseBolumFromProfil(fizyo), kUzmanKoseBolumSaglik);
    expect(uzmanKoseBolumFromProfil(bakici), kUzmanKoseBolumBakim);
    expect(uzmanKoseBolumFromProfil(ev), kUzmanKoseBolumEv);
    expect(
      uzmanKosesBolumProfilleri([fizyo, bakici, ev], kUzmanKoseBolumBakim)
          .single
          .fullName,
      'Mehmet',
    );
  });

  test('destek arayan can post kurum job but not expert profile', () {
    expect(
      canCreateUzmanKosesProfil(
        isGuest: false,
        userEmail: 'klinik@example.com',
        userType: 'aile',
      ),
      isFalse,
    );
    expect(
      canCreateKurumIsIlani(
        isGuest: false,
        userEmail: 'klinik@example.com',
      ),
      isTrue,
    );
    expect(
      canCreateKurumIsIlani(isGuest: true, userEmail: ''),
      isFalse,
    );
  });

  test('kurum job listing requires name, meslek, city, address and kvkk', () {
    expect(
      validateKurumIsIlani(
        kurumAdi: 'Yeşilova Klinik',
        arananMeslek: 'Fizyoterapist',
        il: 'Ankara',
        adres: 'Bağdat Cad. No:10',
        aciklama: 'Tam zamanlı fizyoterapist arıyoruz.',
        kvkk: true,
      ),
      isNull,
    );
    expect(
      validateKurumIsIlani(
        kurumAdi: 'Yeşilova Klinik',
        arananMeslek: 'Fizyoterapist',
        il: 'Ankara',
        aciklama: 'Tam zamanlı fizyoterapist arıyoruz.',
        kvkk: true,
      ),
      isNotNull,
    );
    expect(
      KurumIsIlani.fromJson({
        'kurum_adi': 'Klinik',
        'aranan_meslek': 'Fizyoterapist',
        'adres': 'Bağdat Cad. No:10',
        'photo_url': 'https://cdn.example.com/klinik.jpg',
      }).photoUrl,
      contains('klinik.jpg'),
    );
    expect(
      kurumIsIlaniMatches(
        const KurumIsIlani(
          kurumAdi: 'Klinik',
          arananMeslek: 'Fizyoterapist',
          il: 'Ankara',
          ilce: 'Çankaya',
        ),
        meslek: 'fizyoterapist',
        il: 'Ankara',
      ),
      isTrue,
    );
  });

  testWidgets('kurum job detail shows address and photo', (tester) async {
    const ilan = KurumIsIlani(
      kurumAdi: 'Yeşilova Klinik',
      arananMeslek: 'Fizyoterapist',
      il: 'Ankara',
      ilce: 'Çankaya',
      adres: 'Bağdat Cad. No:10 Kadıköy',
      photoUrl: 'https://cdn.example.com/klinik.jpg',
      aciklama: 'Tam zamanlı fizyoterapist arıyoruz.',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: UzmanKosesKurumIlanDetailPage(ilan: ilan),
      ),
    );
    await tester.pump();
    expect(find.text('Bağdat Cad. No:10 Kadıköy'), findsOneWidget);
    expect(find.text('Yeşilova Klinik'), findsOneWidget);
    expect(find.byType(CatalogImage), findsOneWidget);
    expect(find.text('Mesaj gönder'), findsOneWidget);
    expect(find.text('Randevu talep et'), findsOneWidget);
  });

  testWidgets('admin can remove kurum job or message the owner', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const ilan = KurumIsIlani(
      kurumAdi: 'Klinik',
      arananMeslek: 'Fizyoterapist',
      ownerEmail: 'klinik@example.com',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: UzmanKosesKurumIlanDetailPage(
          ilan: ilan,
          userEmail: 'sakir.caykara@gmail.com',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('İlan sahibine mesaj'), findsOneWidget);
    expect(find.text('İlanı kaldır'), findsOneWidget);
    expect(find.text('Başvur / mesaj gönder'), findsNothing);
  });

  testWidgets('admin can remove mistaken expert profile or message owner',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const preview = ExpertCvProfile(
      fullName: 'Yanlış Profil',
      ownerEmail: 'uye@example.com',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: UzmanKosesCvDetailPage(
          preview: preview,
          userEmail: 'sakir.caykara@gmail.com',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('İlan sahibine mesaj'), findsOneWidget);
    expect(find.text('Profili kaldır'), findsOneWidget);
    expect(find.text('Mesaj gönder'), findsNothing);
  });

  testWidgets('visitor does not see listing delete', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const preview = ExpertCvProfile(fullName: 'Muhammet Baki Ünal');
    await tester.pumpWidget(
      const MaterialApp(
        home: UzmanKosesCvDetailPage(preview: preview),
      ),
    );
    await tester.pump();
    expect(find.text(kUzmanIlanSil), findsNothing);
  });
}

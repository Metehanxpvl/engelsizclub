import 'package:engelsizclub/data/duyuru_data.dart';
import 'package:engelsizclub/data/more_menu_data.dart';
import 'package:engelsizclub/features/useful_opportunities/useful_content_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('useful content status', () {
    test('maps approved to published', () {
      expect(normalizeUsefulContentStatus('approved'), 'published');
      expect(normalizeUsefulContentStatus('APPROVED'), 'published');
      expect(isUserVisibleUsefulContent('approved'), isTrue);
      expect(isUserVisibleUsefulContent('published'), isTrue);
      expect(isUserVisibleUsefulContent('pending_review'), isFalse);
      expect(isUserVisibleUsefulContent('rejected'), isFalse);
      expect(isPendingReviewStatus('pending'), isTrue);
    });

    test('user filter keeps only published', () {
      final rows = [
        UsefulContentItem.fromJson({
          'id': '1',
          'title': 'A',
          'status': 'pending_review',
        }),
        UsefulContentItem.fromJson({
          'id': '2',
          'title': 'B',
          'status': 'approved',
        }),
        UsefulContentItem.fromJson({
          'id': '3',
          'title': 'C',
          'status': 'published',
        }),
        UsefulContentItem.fromJson({
          'id': '4',
          'title': 'D',
          'status': 'rejected',
        }),
      ];
      final visible =
          rows.where((e) => isUserVisibleUsefulContent(e.status)).toList();
      expect(visible.map((e) => e.id), ['2', '3']);
      expect(visible.every((e) => e.status == 'published'), isTrue);
    });
  });

  group('hash/dedup', () {
    test('stable hash', () {
      final a = usefulContentHash(
        title: ' Engelli Bursu ',
        summary: 'Başvuru açık',
        sourceUrl: 'https://example.gov.tr/a',
      );
      final b = usefulContentHash(
        title: 'engelli bursu',
        summary: 'başvuru açık',
        sourceUrl: 'https://example.gov.tr/a',
      );
      expect(a, b);
      expect(a.length, 64);
    });

    test('dedup by url hash external_id', () {
      final existingUrls = {'https://a.example/1'};
      final existingHashes = {'abc'};
      final existingExternalIds = {'ext-1'};
      expect(
        isUsefulContentDuplicate(
          existingUrls: existingUrls,
          existingHashes: existingHashes,
          existingExternalIds: existingExternalIds,
          sourceUrl: 'https://a.example/1',
        ),
        isTrue,
      );
      expect(
        isUsefulContentDuplicate(
          existingUrls: existingUrls,
          existingHashes: existingHashes,
          existingExternalIds: existingExternalIds,
          contentHash: 'abc',
        ),
        isTrue,
      );
      expect(
        isUsefulContentDuplicate(
          existingUrls: existingUrls,
          existingHashes: existingHashes,
          existingExternalIds: existingExternalIds,
          externalId: 'ext-1',
        ),
        isTrue,
      );
      expect(
        isUsefulContentDuplicate(
          existingUrls: existingUrls,
          existingHashes: existingHashes,
          existingExternalIds: existingExternalIds,
          sourceUrl: 'https://b.example/2',
          contentHash: 'zz',
        ),
        isFalse,
      );
    });
  });

  group('story image', () {
    UsefulContentItem item({
      String imageUrl = '',
      String sourceUrl = 'https://example.gov.tr/a',
    }) =>
        UsefulContentItem.fromJson({
          'id': '1',
          'title': 'Burs',
          'source_url': sourceUrl,
          'image_url': imageUrl,
          'status': 'pending_review',
        });

    test('fromJson reads image_url', () {
      expect(item(imageUrl: 'https://cdn.example/a.jpg').imageUrl,
          'https://cdn.example/a.jpg');
      expect(item().imageUrl, '');
    });

    test('photo required unless already set or Instagram', () {
      expect(usefulContentNeedsStoryImage(item()), isTrue);
      expect(
        usefulContentNeedsStoryImage(item(imageUrl: 'https://cdn.example/a.jpg')),
        isFalse,
      );
      expect(
        usefulContentNeedsStoryImage(
          item(sourceUrl: 'https://www.instagram.com/p/abc'),
        ),
        isFalse,
      );
    });

    test('story url uses photo or Instagram marker', () {
      expect(
        usefulContentStoryImageUrl(item(imageUrl: 'https://cdn.example/a.jpg')),
        'https://cdn.example/a.jpg',
      );
      expect(usefulContentStoryImageUrl(item()), '');
      expect(
        usefulContentStoryImageUrl(
          item(sourceUrl: 'https://www.instagram.com/reel/xyz'),
        ),
        kInstagramEmbedMarker,
      );
    });

    test('approve draft maps title/body/link and notifies like birey share', () {
      expect(kUsefulContentApproveNotify, isTrue);
      final now = DateTime.utc(2026, 9, 14, 12);
      final draft = usefulContentToDuyuruDraft(
        UsefulContentItem.fromJson({
          'id': '1',
          'title': '  Burs  ',
          'summary': 'Başvuru açık',
          'body': 'uzun metin',
          'source_url': 'https://example.gov.tr/burs',
          'image_url': 'https://cdn.example/a.jpg',
          'expires_at': '2026-09-13T10:00:00Z',
          'status': 'pending_review',
        }),
        now: now,
      );
      expect(draft.title, 'Burs');
      expect(draft.body, 'Başvuru açık');
      expect(draft.imageUrl, 'https://cdn.example/a.jpg');
      expect(draft.sourceUrl, 'https://example.gov.tr/burs');
      expect(draft.expiresAt, isNull);
      expect(draft.requireImage, isTrue);
      expect(draft.notify, isTrue);
    });

    test('approve draft keeps future expiry and allows empty photo', () {
      final now = DateTime.utc(2026, 9, 14, 12);
      final draft = usefulContentToDuyuruDraft(
        UsefulContentItem.fromJson({
          'id': '2',
          'title': '',
          'summary': '',
          'body': '',
          'source_url': 'https://example.gov.tr/b',
          'expires_at': '2026-10-01T00:00:00Z',
          'status': 'pending_review',
        }),
        now: now,
      );
      expect(draft.title, 'Fırsat / destek');
      expect(draft.body, 'https://example.gov.tr/b');
      expect(draft.imageUrl, '');
      expect(draft.requireImage, isFalse);
      expect(draft.notify, isTrue);
      expect(draft.expiresAt, isNotNull);
    });
  });

  test('firsatlar is not in Daha Fazlası', () {
    expect(MoreMenuItem.builtinRoutes.contains('firsatlar'), isTrue);
    expect(normalizeMoreMenuRoute('firsatlar'), 'firsatlar');
    final items = defaultMoreMenuItems();
    expect(items.any(isFirsatlarMenuItem), isFalse);

    final prepared = prepareUserMoreMenu([
      defaultHaritaMenuItem,
      defaultFirsatlarMenuItem,
      MoreMenuItem(
        id: -2,
        title: 'Haklar',
        subtitle: '',
        linkType: 'route',
        link: 'haklar',
        icon: 'balance',
        sortOrder: 20,
        isActive: true,
        isBuiltin: true,
      ),
    ]);
    expect(prepared.any(isFirsatlarMenuItem), isFalse);
    expect(prepared.any(isMetoBotMenuItem), isTrue);
    expect(prepared.indexWhere(isHaritaMenuItem), 0);
    expect(
      visibleMoreMenuForViewer(prepared, isAdmin: true)
          .any(isFirsatlarMenuItem),
      isFalse,
    );
    expect(
      visibleMoreMenuForViewer(prepared, isAdmin: false)
          .any(isFirsatlarMenuItem),
      isFalse,
    );
  });
}

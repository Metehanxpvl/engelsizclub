import 'package:engelsizclub/gezi_kampanya_store.dart';
import 'package:flutter_test/flutter_test.dart';

KampanyaItem _item({
  required int id,
  required String image,
  String source = kEtkinlikSourceScrape,
  String avm = 'Forum',
  String title = '',
  String eventDate = '',
}) {
  return KampanyaItem(
    id: id,
    imageUrl: image,
    source: source,
    avmName: avm,
    city: 'İstanbul',
    title: title.isEmpty ? 'Etkinlik $id' : title,
    eventDate: eventDate,
    createdAt: DateTime.utc(2026, 6, 1),
  );
}

void main() {
  test('scraped events that share an image collapse to one', () {
    final items = [
      _item(id: 1, image: 'https://cdn.example/mall.jpg'),
      _item(id: 2, image: 'https://cdn.example/mall.jpg'),
      _item(id: 3, image: 'https://cdn.example/poster.jpg'),
      _item(id: 4, image: 'https://cdn.example/poster.jpg', source: 'user'),
    ];

    final out = dedupeActionEtkinlikSameImage(items);

    expect(out.map((e) => e.id).toList(), [1, 3, 4]);
  });

  test('imageless scraped events keep a single generic card', () {
    final items = [
      _item(id: 1, image: ''),
      _item(id: 2, image: ''),
      _item(id: 3, image: 'https://cdn.example/own.jpg'),
    ];

    final out = dedupeActionEtkinlikSameImage(
      items,
      displayedImage: (k) =>
          k.imageUrl.trim().isNotEmpty ? k.imageUrl : 'https://cdn.example/mall.jpg',
    );

    expect(out.map((e) => e.id).toList(), [1, 3]);
  });

  test('Devam ediyor and past June scraped events are hidden', () {
    final today = DateTime(2026, 10, 31);
    final ongoing = _item(
      id: 1,
      image: 'a',
      eventDate: 'Devam ediyor',
      title: 'M1 Adana Kitap Fuarı - Duru Mavi Söyleşisi',
    );
    final june = _item(
      id: 2,
      image: 'b',
      eventDate: '1 Haziran 2026',
      title: 'Yaz atölyesi',
    );
    final december = _item(
      id: 3,
      image: 'c',
      eventDate: '5 Aralık 2026',
      title: 'Yılbaşı',
    );
    final member = _item(
      id: 4,
      image: 'd',
      source: 'user',
      eventDate: 'Devam ediyor',
      title: 'Üye etkinliği',
    );

    expect(scrapedEtkinlikIsCurrent(ongoing, today), isFalse);
    expect(scrapedEtkinlikIsCurrent(june, today), isFalse);
    expect(scrapedEtkinlikIsCurrent(december, today), isTrue);
    expect(scrapedEtkinlikIsCurrent(member, today), isTrue);
  });

  test('same book fair title at one mall collapses to one card', () {
    final items = [
      _item(
        id: 1,
        image: 'poster-a',
        title: 'M1 Adana Kitap Fuarı - Duru Mavi Söyleşisi',
        avm: 'M1 Adana',
      ),
      _item(
        id: 2,
        image: 'poster-b',
        title: 'M1 Adana Kitap Fuarı',
        avm: 'M1 Adana',
      ),
    ];

    final out = dedupeActionEtkinlikSameTitle(items);
    expect(out.map((e) => e.id).toList(), [1]);
  });
}

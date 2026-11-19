import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'kesfet_store.dart';

/// Keşfet akış sırası: tüm onaylı videolar karışık gelir, kullanıcı bu turda
/// izlediklerini tekrar görmez. Hepsi izlenince yeni tur başlar.
/// Çocuk şarkıları akışta seyrek tutulur: her 4 videodan en fazla 1'i.

const kKesfetSongTag = 'çocuk şarkısı';
const kKesfetSongSpacing = 4;

class KesfetQueueEntry {
  const KesfetQueueEntry(this.id, {this.isSong = false});
  final String id;
  final bool isSong;
}

/// Saf sıralama: izlenmeyenleri karıştırır, şarkıları aralıklı dağıtır.
List<String> buildKesfetQueue(
  List<KesfetQueueEntry> all,
  Set<String> viewed, {
  Random? random,
}) {
  final rng = random ?? Random();
  final unseen = [for (final e in all) if (!viewed.contains(e.id)) e];
  final songs = shuffleKesfetVideos([for (final e in unseen) if (e.isSong) e.id], rng);
  final others = shuffleKesfetVideos([for (final e in unseen) if (!e.isSong) e.id], rng);
  final out = <String>[];
  var s = 0;
  var o = 0;
  var sinceSong = kKesfetSongSpacing; // ilk slotta şarkı gelebilir
  while (s < songs.length || o < others.length) {
    final songAllowed = sinceSong >= kKesfetSongSpacing - 1;
    // Şarkı sırası geldiyse ve şarkı varsa, rastgele (yaklaşık 1/4) şarkı koy.
    final pickSong = s < songs.length &&
        (o >= others.length || (songAllowed && rng.nextInt(kKesfetSongSpacing) == 0) ||
            // Diğerleri biterken şarkılar yığılmasın diye orantıyı koru.
            (songAllowed && (songs.length - s) * kKesfetSongSpacing >= (others.length - o)));
    if (pickSong) {
      out.add(songs[s++]);
      sinceSong = 0;
    } else {
      out.add(others[o++]);
      sinceSong += 1;
    }
  }
  return out;
}

String _cycleKey(String userId) => 'kesfet_cycle_start_$userId';

Future<DateTime?> kesfetCycleStart(String userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cycleKey(userId));
    return raw == null ? null : DateTime.tryParse(raw);
  } catch (_) {
    return null;
  }
}

Future<void> startNewKesfetCycle(String userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cycleKey(userId), DateTime.now().toUtc().toIso8601String());
  } catch (_) {}
}

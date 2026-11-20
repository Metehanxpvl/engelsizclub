import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../info_library/info_library.dart';
import '../info_library/info_library_repository.dart';
import '../kesfet/kesfet_models.dart';
import '../meto_theme.dart';

/// Tanı detay sayfası: Bilgi Kütüphanesi videoları + Keşfet'ten başlığa göre
/// eşleşen videolar (yatay şerit). Video yoksa hiçbir şey göstermez.
class TaniVideoSeridi extends StatefulWidget {
  const TaniVideoSeridi({
    super.key,
    required this.category,
    required this.anahtarKelimeler,
    this.viewerEmail = '',
  });

  /// Bilgi Kütüphanesi kategori anahtarı (tanı id).
  final String category;

  /// Keşfet video başlığında aranacak kelimeler (büyük-küçük harf duyarsız).
  final List<String> anahtarKelimeler;

  final String viewerEmail;

  @override
  State<TaniVideoSeridi> createState() => _TaniVideoSeridiState();
}

class _SeritVideo {
  const _SeritVideo({required this.content, required this.thumb});
  final InfoContent content;
  final String thumb;
}

class _TaniVideoSeridiState extends State<TaniVideoSeridi> {
  List<_SeritVideo> _videolar = const [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  String _thumbFor(String? id) =>
      (id == null || id.isEmpty) ? '' : 'https://i.ytimg.com/vi/$id/hqdefault.jpg';

  Future<void> _yukle() async {
    final out = <_SeritVideo>[];
    final gorulen = <String>{};

    try {
      final lib = await InfoLibraryRepository.instance.fetchByCategory(
        widget.category,
        viewerEmail: widget.viewerEmail,
      );
      for (final c in lib) {
        final id = c.youtubeVideoId;
        if (id == null || id.isEmpty || !gorulen.add(id)) continue;
        out.add(_SeritVideo(content: c, thumb: _thumbFor(id)));
      }
    } catch (_) {}

    try {
      final client = Supabase.instance.client;
      final kesfet = <KesfetVideo>[];
      for (final k in widget.anahtarKelimeler) {
        final kelime = k.trim();
        if (kelime.isEmpty) continue;
        final rows = await client
            .from('kesfet_videos')
            .select()
            .eq('status', 'approved')
            .ilike('title', '%$kelime%')
            .order('published_at', ascending: false)
            .limit(10);
        for (final e in (rows as List).whereType<Map>()) {
          kesfet.add(KesfetVideo.fromRow(Map<String, dynamic>.from(e)));
        }
      }
      var eklenen = 0;
      for (final v in kesfet) {
        if (eklenen >= 10) break;
        final id = v.youtubeVideoId.trim();
        if (id.isEmpty || !gorulen.add(id)) continue;
        out.add(
          _SeritVideo(
            content: InfoContent(
              id: 'kesfet_${v.id}',
              title: v.title,
              description: v.description,
              youtubeUrl: v.youtubeUrl.trim().isNotEmpty ? v.youtubeUrl : id,
              source: v.channelName,
              category: widget.category,
              createdAt: DateTime.now(),
            ),
            thumb: v.resolvedThumb,
          ),
        );
        eklenen++;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _videolar = out);
  }

  @override
  Widget build(BuildContext context) {
    if (_videolar.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Videolar',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 172,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _videolar.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _kart(_videolar[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kart(_SeritVideo v) {
    return SizedBox(
      width: 200,
      child: Material(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => InfoDetailScreen(content: v.content),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MetoColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 112,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (v.thumb.isNotEmpty)
                        Image.network(
                          v.thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const ColoredBox(color: Colors.black26),
                        )
                      else
                        const ColoredBox(color: Colors.black26),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Text(
                    v.content.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MetoColors.foreground,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

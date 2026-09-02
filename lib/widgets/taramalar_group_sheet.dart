import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/more_menu_data.dart';
import '../meto_theme.dart';

/// Daha Fazlası içindeki ikinci seviye: Taramalar & Egzersizler & Oyun.
class TaramalarGroupSheet extends StatelessWidget {
  const TaramalarGroupSheet({
    super.key,
    required this.onSelect,
  });

  final ValueChanged<MoreMenuItem> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = taramalarGroupChildren();
    final maxH = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(
                color: MetoColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Taramalar & Egzersizler & Oyun',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          MetoColors.primary.withValues(alpha: 0.12),
                      child: _leading(item),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: item.subtitle.isEmpty
                        ? null
                        : Text(
                            item.subtitle,
                            style: const TextStyle(fontSize: 12),
                          ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onSelect(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leading(MoreMenuItem item) {
    if (item.icon == 'eye' || item.link == 'cvi' || item.link == 'cvi2') {
      return SvgPicture.asset(
        'assets/cvi/eye_icon.svg',
        width: 22,
        height: 22,
      );
    }
    switch (item.icon) {
      case 'games':
        return Icon(Icons.extension_outlined, color: Colors.green.shade700);
      case 'search':
        return const Icon(Icons.search, color: MetoColors.primary);
      default:
        return const Icon(Icons.link, color: MetoColors.primary);
    }
  }
}

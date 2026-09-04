import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/more_menu_data.dart';
import '../meto_theme.dart';

/// Daha Fazlası içinde bir grubun çocukları (parent_id).
class MoreMenuGroupSheet extends StatelessWidget {
  const MoreMenuGroupSheet({
    super.key,
    required this.title,
    required this.items,
    required this.onSelect,
  });

  final String title;
  final List<MoreMenuItem> items;
  final ValueChanged<MoreMenuItem> onSelect;

  @override
  Widget build(BuildContext context) {
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Text(
                  'Bu grupta henüz öğe yok.',
                  style: TextStyle(
                    fontSize: 13,
                    color: MetoColors.mutedFg,
                  ),
                ),
              )
            else
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
                      trailing: Icon(
                        item.isFolder
                            ? Icons.keyboard_arrow_down
                            : Icons.chevron_right,
                      ),
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
    if (item.icon == '🎨' ||
        item.icon == 'palette' ||
        item.link == 'boyama') {
      return const Text('🎨', style: TextStyle(fontSize: 22));
    }
    switch (item.icon) {
      case 'games':
        return Icon(Icons.extension_outlined, color: Colors.green.shade700);
      case 'search':
        return const Icon(Icons.search, color: MetoColors.primary);
      case 'folder':
      case 'apps':
        return const Icon(Icons.folder_outlined, color: MetoColors.primary);
      default:
        return Icon(
          item.isFolder ? Icons.folder_outlined : Icons.link,
          color: MetoColors.primary,
        );
    }
  }
}

/// Eski ad — [MoreMenuGroupSheet] ile aynı.
typedef TaramalarGroupSheet = MoreMenuGroupSheet;

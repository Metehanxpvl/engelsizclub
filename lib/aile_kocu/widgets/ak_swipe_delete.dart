import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Sola kaydır → kırmızı Sil şeridi + onay diyaloğu.
///
/// Silme işi `confirmDismiss` içinde hızlı bitmeli (Hive vb.).
/// Uzun süren bildirim iptali burada `await` edilirse web/mobilde takılır.
class AkSwipeToDelete extends StatelessWidget {
  const AkSwipeToDelete({
    super.key,
    required this.itemKey,
    required this.onDelete,
    required this.child,
    this.confirmMessage = 'Silinsin mi?',
  });

  final String itemKey;
  final Future<void> Function() onDelete;
  final Widget child;
  final String confirmMessage;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(itemKey),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
              context: context,
              barrierDismissible: true,
              builder: (ctx) => AlertDialog(
                title: const Text('Sil'),
                content: Text(confirmMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Vazgeç'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                    ),
                    child: const Text('Sil'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!ok) return false;
        try {
          // Veri kaynağından hemen sil; liste rebuild olsun.
          await onDelete();
          return true;
        } catch (e, st) {
          debugPrint('AkSwipeToDelete onDelete: $e\n$st');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Silinemedi: $e')),
            );
          }
          return false;
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Sil',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ],
        ),
      ),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../meto_theme.dart';
import '../aile_kocu_entry.dart';
import '../aile_kocu_store.dart';
import '../child_photo.dart';
import '../models/aile_kocu_models.dart';
import '../notification_service.dart';

class AileKocuAyarlarScreen extends StatefulWidget {
  const AileKocuAyarlarScreen({super.key});

  @override
  State<AileKocuAyarlarScreen> createState() => _AileKocuAyarlarScreenState();
}

class _AileKocuAyarlarScreenState extends State<AileKocuAyarlarScreen> {
  late final TextEditingController _name;
  late AileKocuSettings _settings;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _settings = loadSettings();
    _name = TextEditingController(text: _settings.childName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      final dataUrl = await encodePickedChildPhoto(file);
      final next = AileKocuSettings(
        childName: _settings.childName,
        photoPath: dataUrl,
        disclaimerAccepted: _settings.disclaimerAccepted,
      );
      await saveSettings(next);
      if (!mounted) return;
      setState(() => _settings = next);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf kaydedildi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotoğraf seçilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _saveName() async {
    final next = AileKocuSettings(
      childName: _name.text.trim().isEmpty ? 'Çocuk' : _name.text.trim(),
      photoPath: _settings.photoPath,
      disclaimerAccepted: _settings.disclaimerAccepted,
    );
    await saveSettings(next);
    if (!mounted) return;
    setState(() => _settings = next);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kaydedildi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = childPhotoProvider(_settings.photoPath);
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        title: const Text('Aile Koçu Ayarları'),
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Çocuk Adı',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              filled: true,
              fillColor: MetoColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onEditingComplete: _saveName,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saveName,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: MetoColors.primary,
            ),
            child: const Text('Adı Kaydet'),
          ),
          const SizedBox(height: 28),
          const Text(
            'Çocuk Fotoğrafı',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: _picking ? null : _pickPhoto,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: MetoColors.primary.withValues(alpha: 0.15),
                    backgroundImage: provider,
                    child: provider == null
                        ? const Icon(Icons.add_a_photo, size: 36)
                        : null,
                  ),
                  if (_picking)
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dokunarak seçin. Ders / ilaç / çocuk notu ekranlarında görünür.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
          ),
          if (provider != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                final next = AileKocuSettings(
                  childName: _settings.childName,
                  photoPath: '',
                  disclaimerAccepted: _settings.disclaimerAccepted,
                );
                await saveSettings(next);
                if (mounted) setState(() => _settings = next);
              },
              child: const Text('Fotoğrafı kaldır'),
            ),
          ],
          const SizedBox(height: 28),
          const Text(
            'Bildirimler',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.alarm_on_outlined),
            title: const Text('Tam saatli ilaç hatırlatması'),
            subtitle: Text(
              AileKocuNotificationService.instance.exactAlarmsAllowed
                  ? 'Açık — ekran kapalıyken de planlanan saatte gelir.'
                  : 'Kapalı — Android ayarlarından “Alarmlar ve hatırlatıcılar” iznini açın.',
              style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
            ),
            trailing: TextButton(
              onPressed: () async {
                final ok = await AileKocuNotificationService.instance
                    .refreshExactAlarmMode(promptUser: true);
                await bootstrapAileKocuReminders();
                if (!context.mounted) return;
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Tam saatli alarm açık. Hatırlatmalar yenilendi.'
                          : 'İzin verilmedi. Telefon Ayarları → Uygulamalar → Engelsiz Club → Alarmlar ve hatırlatıcılar.',
                    ),
                  ),
                );
              },
              child: const Text('İzin ver'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              AileKocuNotificationService.instance.notificationsAllowed
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
            ),
            title: const Text('Bildirim izni'),
            subtitle: Text(
              AileKocuNotificationService.instance.notificationsAllowed
                  ? 'Açık — hatırlatmalar bildirim olarak gelebilir.'
                  : 'Kapalı — Android 13+ cihazlarda izin olmadan bildirim gelmez.',
              style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
            ),
            trailing: TextButton(
              onPressed: () async {
                await AileKocuNotificationService.instance.ensurePermissions();
                if (!context.mounted) return;
                setState(() {});
                final ok =
                    AileKocuNotificationService.instance.notificationsAllowed;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Bildirim izni açık.'
                          : 'İzin verilmedi. Telefon Ayarları → Uygulamalar → Engelsiz Club → Bildirimler.',
                    ),
                  ),
                );
              },
              child: const Text('İzin ver'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final n = AileKocuNotificationService.instance;
              final nowOk = await n.showTestNow();
              if (!context.mounted) return;
              if (!nowOk) {
                final reason = !n.notificationsAllowed
                    ? 'Anlık bildirim gönderilemedi. Bildirim iznini açın.'
                    : !n.isReady
                        ? 'Bildirim motoru başlatılamadı. Play’den güncel sürümü kurun.'
                        : 'Anlık bildirim gönderilemedi. Uygulamayı kapatıp tekrar deneyin.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(reason)),
                );
                return;
              }
              final laterOk = await n.scheduleTestInSeconds(15);
              final pending = await n.pendingCount();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    laterOk
                        ? 'Deneme bildirimi geldi. 15 sn sonra bir tane daha gelecek (kuyrukta $pending hatırlatma).'
                        : 'Anlık bildirim geldi; zamanlanmış deneme kurulamadı (kuyruk: $pending).',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.notification_add_outlined),
            label: const Text('Deneme bildirimi gönder'),
          ),
        ],
      ),
    );
  }
}

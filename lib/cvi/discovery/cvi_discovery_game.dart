import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'cvi_discovery_models.dart';

/// CVI Görsel Keşif — siyah zemin, tek nesne, dokununca büyüyüp kaybolur.
class CviDiscoveryGame extends FlameGame {
  CviDiscoveryGame({required this.category});

  final CviDiscoveryCategory category;
  final _rng = math.Random();

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _spawnNext();
  }

  Future<void> _spawnNext() async {
    children.whereType<_DiscoveryTarget>().forEach((c) => c.removeFromParent());
    if (category.items.isEmpty) return;

    final item = category.items[_rng.nextInt(category.items.length)];
    final targetSize = _sizeForItem(item, size);
    final position = _randomPosition(targetSize);

    try {
      add(await _DiscoveryTarget.load(
        item: item,
        position: position,
        targetSize: targetSize,
        sound: category.sound,
        onDone: _spawnNext,
      ));
    } catch (e) {
      debugPrint('CVI discovery görsel yüklenemedi: $e');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _spawnNext();
    }
  }

  Vector2 _randomPosition(Vector2 targetSize) {
    final pad = math.max(targetSize.x, targetSize.y) * 0.35;
    final maxX = math.max(pad, size.x - targetSize.x - pad);
    final maxY = math.max(pad, size.y - targetSize.y - pad);
    return Vector2(
      pad + _rng.nextDouble() * (maxX - pad),
      pad + _rng.nextDouble() * (maxY - pad),
    );
  }

  Vector2 _sizeForItem(CviDiscoveryItem item, Vector2 screen) {
    final label = item.label.toLowerCase();
    final path = item.asset.toLowerCase();
    final isCar = path.contains('car') || label.contains('araba');
    final base = math.min(screen.x, screen.y);
    if (isCar) return Vector2(base * 0.72, base * 0.36);
    return Vector2.all(base * 0.42);
  }
}

class _DiscoveryTarget extends SpriteComponent with TapCallbacks {
  _DiscoveryTarget._({
    required this.sound,
    required Future<void> Function() onDone,
  }) : _onDone = onDone;

  final String sound;
  final Future<void> Function() _onDone;
  bool _busy = false;

  static Future<_DiscoveryTarget> load({
    required CviDiscoveryItem item,
    required Vector2 position,
    required Vector2 targetSize,
    required String sound,
    required Future<void> Function() onDone,
  }) async {
    final Sprite sprite;
    if (item.hasRemote) {
      final res = await http.get(Uri.parse(item.url!.trim()));
      if (res.statusCode != 200) {
        throw StateError('HTTP ${res.statusCode}');
      }
      final codec = await ui.instantiateImageCodec(res.bodyBytes);
      final frame = await codec.getNextFrame();
      sprite = Sprite(frame.image);
    } else {
      sprite = await Sprite.load(item.asset);
    }

    return _DiscoveryTarget._(sound: sound, onDone: onDone)
      ..sprite = sprite
      ..position = position
      ..size = targetSize
      ..anchor = Anchor.topLeft
      ..priority = 1;
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    return size.toRect().inflate(56).contains(point.toOffset());
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_busy) return;
    _busy = true;
    HapticFeedback.lightImpact();
    if (sound == 'motor') HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    add(
      ScaleEffect.to(
        Vector2.all(1.75),
        EffectController(duration: 0.65, curve: Curves.easeOut),
      ),
    );
    add(
      OpacityEffect.fadeOut(
        EffectController(duration: 0.65, curve: Curves.easeOut),
        onComplete: () async {
          removeFromParent();
          await _onDone();
        },
      ),
    );
  }
}

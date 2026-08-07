import 'dart:ui' show Color;

enum CviShapeKind { circle, square, triangle }

CviShapeKind parseCviShape(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'square':
    case 'kare':
      return CviShapeKind.square;
    case 'triangle':
    case 'ucgen':
    case 'üçgen':
      return CviShapeKind.triangle;
    default:
      return CviShapeKind.circle;
  }
}

Color parseCviColor(String hex) {
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16) ?? 0xFFFF1744;
  return Color(v);
}

class CviOption {
  const CviOption({
    required this.shape,
    required this.color,
    required this.correct,
  });

  final CviShapeKind shape;
  final Color color;
  final bool correct;

  factory CviOption.fromJson(Map<String, dynamic> json) {
    return CviOption(
      shape: parseCviShape('${json['shape'] ?? 'circle'}'),
      color: parseCviColor('${json['color'] ?? '#FF1744'}'),
      correct: json['correct'] == true || json['isTarget'] == true,
    );
  }
}

class CviStep {
  const CviStep({
    required this.id,
    required this.clutter,
    required this.prompt,
    required this.targetShape,
    required this.targetColor,
    required this.options,
  });

  final int id;
  final int clutter;
  final String prompt;
  final CviShapeKind targetShape;
  final Color targetColor;
  final List<CviOption> options;

  factory CviStep.fromJson(Map<String, dynamic> json) {
    final optsRaw = json['options'];
    final opts = <CviOption>[];
    if (optsRaw is List) {
      for (final o in optsRaw) {
        if (o is Map) {
          opts.add(CviOption.fromJson(Map<String, dynamic>.from(o)));
        }
      }
    }
    return CviStep(
      id: (json['id'] as num?)?.toInt() ?? 0,
      clutter: (json['clutter'] as num?)?.toInt() ?? 0,
      prompt: '${json['prompt'] ?? ''}',
      targetShape: parseCviShape('${json['targetShape'] ?? 'circle'}'),
      targetColor: parseCviColor('${json['targetColor'] ?? '#FF1744'}'),
      options: opts,
    );
  }
}

class CviConfig {
  const CviConfig({
    required this.version,
    required this.title,
    required this.steps,
    this.fromOfflineFallback = false,
  });

  final String version;
  final String title;
  final List<CviStep> steps;
  final bool fromOfflineFallback;

  factory CviConfig.fromJson(
    Map<String, dynamic> json, {
    bool fromOfflineFallback = false,
  }) {
    final stepsRaw = json['steps'];
    final steps = <CviStep>[];
    if (stepsRaw is List) {
      for (final s in stepsRaw) {
        if (s is Map) {
          steps.add(CviStep.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }
    steps.sort((a, b) => a.id.compareTo(b.id));
    return CviConfig(
      version: '${json['version'] ?? '0'}',
      title: '${json['title'] ?? 'CVI Görsel Egzersizleri'}',
      steps: steps,
      fromOfflineFallback: fromOfflineFallback,
    );
  }
}

/// Tek adım sonucu — yalnızca RAM'de (oturum bitene kadar DB yok).
class CviStepResult {
  const CviStepResult({
    required this.stepId,
    required this.correct,
    required this.reactionMs,
    required this.clutter,
    required this.targetShape,
    required this.targetColorHex,
  });

  final int stepId;
  final bool correct;
  final int reactionMs;
  final int clutter;
  final String targetShape;
  final String targetColorHex;

  Map<String, dynamic> toJson() => {
        'step_id': stepId,
        'correct': correct,
        'reaction_ms': reactionMs,
        'clutter': clutter,
        'target_shape': targetShape,
        'target_color': targetColorHex,
      };
}

class CviSessionSummary {
  const CviSessionSummary({
    required this.configVersion,
    required this.totalSteps,
    required this.correctCount,
    required this.percentage,
    required this.avgReactionMs,
    required this.stepResults,
    required this.clutterTolerance,
    required this.colorPreference,
  });

  final String configVersion;
  final int totalSteps;
  final int correctCount;
  final double percentage;
  final int avgReactionMs;
  final List<CviStepResult> stepResults;
  /// clutter level → doğru oranı 0–100
  final Map<int, double> clutterTolerance;
  /// color hex → doğru oranı 0–100
  final Map<String, double> colorPreference;

  factory CviSessionSummary.fromResults({
    required String configVersion,
    required List<CviStepResult> results,
  }) {
    final total = results.length;
    final correct = results.where((r) => r.correct).length;
    final avg = total == 0
        ? 0
        : (results.fold<int>(0, (a, r) => a + r.reactionMs) / total).round();

    final byClutter = <int, List<CviStepResult>>{};
    final byColor = <String, List<CviStepResult>>{};
    for (final r in results) {
      byClutter.putIfAbsent(r.clutter, () => []).add(r);
      byColor.putIfAbsent(r.targetColorHex.toUpperCase(), () => []).add(r);
    }

    double rate(List<CviStepResult> list) {
      if (list.isEmpty) return 0;
      final c = list.where((e) => e.correct).length;
      return (c * 100.0) / list.length;
    }

    return CviSessionSummary(
      configVersion: configVersion,
      totalSteps: total,
      correctCount: correct,
      percentage: total == 0 ? 0 : (correct * 100.0) / total,
      avgReactionMs: avg,
      stepResults: List.unmodifiable(results),
      clutterTolerance: {
        for (final e in byClutter.entries) e.key: rate(e.value),
      },
      colorPreference: {
        for (final e in byColor.entries) e.key: rate(e.value),
      },
    );
  }
}

String cviShapeLabel(CviShapeKind k) {
  switch (k) {
    case CviShapeKind.circle:
      return 'circle';
    case CviShapeKind.square:
      return 'square';
    case CviShapeKind.triangle:
      return 'triangle';
  }
}

String colorToHex(Color c) {
  final v = c.toARGB32();
  final r = (v >> 16) & 0xff;
  final g = (v >> 8) & 0xff;
  final b = v & 0xff;
  return '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

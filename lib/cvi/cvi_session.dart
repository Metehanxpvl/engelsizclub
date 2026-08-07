import 'cvi_models.dart';

/// Aktif oturum durumu — yalnızca cihaz belleği (RAM). DB yok.
class CviSessionController {
  CviSessionController(this.config);

  final CviConfig config;
  final Stopwatch _watch = Stopwatch();
  final List<CviStepResult> results = [];

  int index = 0;
  bool locked = false;

  CviStep get current => config.steps[index];
  bool get isComplete => index >= config.steps.length;
  int get totalSteps => config.steps.length;

  void startStepTimer() {
    locked = false;
    _watch
      ..reset()
      ..start();
  }

  /// İlk dokunuşu kaydeder ve bir sonraki adıma geçer (oturum boyunca DB yok).
  CviStepResult recordTap({required bool correct}) {
    _watch.stop();
    locked = true;
    final ms = _watch.elapsedMilliseconds.clamp(0, 120000);
    final step = current;
    final result = CviStepResult(
      stepId: step.id,
      correct: correct,
      reactionMs: ms,
      clutter: step.clutter,
      targetShape: cviShapeLabel(step.targetShape),
      targetColorHex: colorToHex(step.targetColor),
    );
    results.add(result);
    index += 1;
    return result;
  }

  CviSessionSummary buildSummary() {
    return CviSessionSummary.fromResults(
      configVersion: config.version,
      results: List.unmodifiable(results),
    );
  }
}

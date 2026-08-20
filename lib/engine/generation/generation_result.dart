import '../../domain/design/design_candidate.dart';

class GenerationDiagnostics {
  const GenerationDiagnostics({
    required this.attempted,
    required this.valid,
    required this.rejectionReasons,
  });

  final int attempted;
  final int valid;
  final Map<String, int> rejectionReasons;

  String get primaryFailure {
    if (rejectionReasons.isEmpty) return 'No valid layout was found.';
    final sorted = rejectionReasons.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }
}

class GenerationResult {
  const GenerationResult({
    required this.candidates,
    required this.diagnostics,
    this.feasibilityErrors = const <String>[],
  });

  final List<DesignCandidate> candidates;
  final GenerationDiagnostics diagnostics;
  final List<String> feasibilityErrors;
  bool get isSuccess => candidates.isNotEmpty;
}

class GenerationProgress {
  const GenerationProgress({
    required this.attempt,
    required this.totalAttempts,
    required this.validCount,
  });
  final int attempt;
  final int totalAttempts;
  final int validCount;
  double get fraction => totalAttempts == 0 ? 0 : attempt / totalAttempts;
}

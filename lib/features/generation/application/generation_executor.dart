import '../../../domain/requirements/design_requirements.dart';
import '../../../engine/generation/floor_plan_generator.dart';
import '../../../engine/generation/generation_config.dart';
import '../../../engine/generation/generation_result.dart';

abstract interface class GenerationExecutor {
  Future<GenerationResult> execute({
    required DesignRequirements requirements,
    required GenerationConfig config,
    required int seed,
    GenerationProgressCallback? onProgress,
  });
}

/// Current bounded, browser-local execution strategy.
///
/// The initial event-loop yield lets Flutter paint the generating state. A
/// Worker, isolate, or remote implementation can replace this class without
/// changing the Cubit or the procedural engine.
class LocalGenerationExecutor implements GenerationExecutor {
  const LocalGenerationExecutor({this.generator = const FloorPlanGenerator()});

  final FloorPlanGenerator generator;

  @override
  Future<GenerationResult> execute({
    required DesignRequirements requirements,
    required GenerationConfig config,
    required int seed,
    GenerationProgressCallback? onProgress,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    return generator.generate(
      requirements: requirements,
      config: config,
      seed: seed,
      onProgress: onProgress,
    );
  }
}

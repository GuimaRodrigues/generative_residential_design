import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../engine/generation/generation_result.dart';
import '../../project/application/project_cubit.dart';
import 'generation_executor.dart';

sealed class GenerationState {
  const GenerationState();
}

class GenerationIdle extends GenerationState {
  const GenerationIdle();
}

class GenerationGenerating extends GenerationState {
  const GenerationGenerating(this.progress);
  final GenerationProgress progress;
}

class GenerationSuccess extends GenerationState {
  const GenerationSuccess(this.result);
  final GenerationResult result;
}

class GenerationFailure extends GenerationState {
  const GenerationFailure({required this.message, required this.result});
  final String message;
  final GenerationResult? result;
}

class GenerationCubit extends Cubit<GenerationState> {
  GenerationCubit({this.executor = const LocalGenerationExecutor()})
    : super(const GenerationIdle());

  final GenerationExecutor executor;

  Future<void> generate(ProjectState projectState) async {
    final config = projectState.generationConfig;
    emit(
      GenerationGenerating(
        GenerationProgress(
          attempt: 0,
          totalAttempts: config.attempts,
          validCount: 0,
        ),
      ),
    );
    try {
      final result = await executor.execute(
        requirements: projectState.project.requirements,
        config: config,
        seed: projectState.project.seed,
        onProgress: (progress) {
          if (!isClosed) emit(GenerationGenerating(progress));
        },
      );
      if (result.isSuccess) {
        emit(GenerationSuccess(result));
      } else {
        final message = result.feasibilityErrors.isNotEmpty
            ? result.feasibilityErrors.join('\n')
            : '${result.diagnostics.primaryFailure}\nTry reducing room sizes, changing floor assignments, or increasing the lot.';
        emit(GenerationFailure(message: message, result: result));
      }
    } on Object catch (error) {
      emit(
        GenerationFailure(message: 'Generation failed: $error', result: null),
      );
    }
  }

  void clear() => emit(const GenerationIdle());
}

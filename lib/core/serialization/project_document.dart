import '../../domain/project/design_project.dart';
import '../../engine/generation/generation_config.dart';

class ProjectDocument {
  const ProjectDocument({
    this.formatVersion = currentFormatVersion,
    required this.project,
    required this.generationConfig,
  });

  static const int currentFormatVersion = 1;

  final int formatVersion;
  final DesignProject project;
  final GenerationConfig generationConfig;

  Map<String, Object?> toJson() => <String, Object?>{
    'formatVersion': formatVersion,
    'project': project.toJson(),
    'generationSettings': generationConfig.toJson(),
  };
}

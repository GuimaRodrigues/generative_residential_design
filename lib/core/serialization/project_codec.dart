import 'dart:convert';

import '../../domain/project/design_project.dart';
import '../../engine/generation/generation_config.dart';
import 'project_document.dart';

class ProjectCodec {
  const ProjectCodec();

  String encode(ProjectDocument document) =>
      const JsonEncoder.withIndent('  ').convert(document.toJson());

  ProjectDocument decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException(
        'The selected file is not valid JSON: ${error.message}',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'Project JSON must contain an object at its root.',
      );
    }
    final version = decoded['formatVersion'];
    if (version != ProjectDocument.currentFormatVersion) {
      throw FormatException(
        'Unsupported project format version $version. '
        'This app supports version ${ProjectDocument.currentFormatVersion}.',
      );
    }
    try {
      return ProjectDocument(
        formatVersion: version! as int,
        project: DesignProject.fromJson(
          decoded['project'] as Map<String, Object?>,
        ),
        generationConfig: GenerationConfig.fromJson(
          decoded['generationSettings'] as Map<String, Object?>,
        ),
      );
    } on Object catch (error) {
      throw FormatException(
        'The project file is incomplete or invalid: $error',
      );
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:generative_residential_design/core/serialization/project_codec.dart';
import 'package:generative_residential_design/core/serialization/project_document.dart';
import 'package:generative_residential_design/domain/project/sample_project.dart';
import 'package:generative_residential_design/engine/generation/generation_config.dart';

void main() {
  const codec = ProjectCodec();

  test('project JSON roundtrips with format version and settings', () {
    final original = ProjectDocument(
      project: createSampleProject(),
      generationConfig: const GenerationConfig(attempts: 77),
    );
    final encoded = codec.encode(original);
    final decoded = codec.decode(encoded);
    expect(decoded.formatVersion, 1);
    expect(decoded.project.name, original.project.name);
    expect(
      decoded.project.requirements.site.toJson(),
      original.project.requirements.site.toJson(),
    );
    expect(
      decoded.project.requirements.rooms.length,
      original.project.requirements.rooms.length,
    );
    expect(decoded.generationConfig.attempts, 77);
    expect(codec.encode(decoded), encoded);
  });

  test('unsupported versions produce a useful error', () {
    expect(
      () => codec.decode('{"formatVersion": 99}'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Unsupported'),
        ),
      ),
    );
  });
}

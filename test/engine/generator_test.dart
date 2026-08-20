import 'package:flutter_test/flutter_test.dart';
import 'package:generative_residential_design/core/geometry/geometry_utils.dart';
import 'package:generative_residential_design/core/geometry/rect_2d.dart';
import 'package:generative_residential_design/domain/constraints/constraint.dart';
import 'package:generative_residential_design/domain/design/design_candidate.dart';
import 'package:generative_residential_design/domain/design/floor_plan.dart';
import 'package:generative_residential_design/domain/project/sample_project.dart';
import 'package:generative_residential_design/domain/requirements/room_requirement.dart';
import 'package:generative_residential_design/engine/generation/floor_plan_generator.dart';
import 'package:generative_residential_design/engine/generation/generation_config.dart';
import 'package:generative_residential_design/engine/validation/design_validator.dart';

void main() {
  const generator = FloorPlanGenerator();
  const config = GenerationConfig(
    attempts: 120,
    maxValidCandidates: 12,
    displayTopCandidates: 6,
  );

  test('sample requirements produce valid ranked candidates', () {
    final project = createSampleProject();
    final result = generator.generate(
      requirements: project.requirements,
      config: config,
      seed: project.seed,
    );
    expect(result.feasibilityErrors, isEmpty);
    expect(result.candidates, isNotEmpty);
    expect(
      result.candidates.length,
      lessThanOrEqualTo(config.displayTopCandidates),
    );
    for (final candidate in result.candidates) {
      expect(
        const DesignValidator().validate(candidate, project.requirements),
        isEmpty,
      );
      expect(
        candidate.rooms.length,
        project.requirements.normalizeRooms().length,
      );
      expect(candidate.score.overall, inInclusiveRange(0, 100));
      if (candidate.floors.length == 2 &&
          candidate.floors[1].footprint != null) {
        expect(
          candidate.floors[0].footprint!.containsRect(
            candidate.floors[1].footprint!,
          ),
          isTrue,
          reason: 'upper floor must be supported by the ground floor',
        );
      }
      for (final room in candidate.rooms) {
        expect(
          project.requirements.site.buildableEnvelope.containsRect(room.bounds),
          isTrue,
        );
        expect(isGridAligned(room.bounds.x), isTrue);
        expect(isGridAligned(room.bounds.y), isTrue);
        expect(isGridAligned(room.bounds.width), isTrue);
        expect(isGridAligned(room.bounds.height), isTrue);
        if (room.source.preferredFloor == PreferredFloor.ground) {
          expect(room.floorIndex, 0);
        }
        if (room.source.preferredFloor == PreferredFloor.upper) {
          expect(room.floorIndex, 1);
        }
      }
    }
    final scores = result.candidates
        .map((candidate) => candidate.score.overall)
        .toList();
    final sortedScores = List<double>.of(scores)
      ..sort((double a, double b) => b.compareTo(a));
    expect(scores, orderedEquals(sortedScores));
  });

  test('same inputs and seed reproduce geometry, ranking, and scores', () {
    final project = createSampleProject();
    final first = generator.generate(
      requirements: project.requirements,
      config: config,
      seed: project.seed,
    );
    final second = generator.generate(
      requirements: project.requirements,
      config: config,
      seed: project.seed,
    );
    expect(
      first.candidates.map((candidate) => candidate.geometrySignature),
      orderedEquals(
        second.candidates.map((candidate) => candidate.geometrySignature),
      ),
    );
    expect(
      first.candidates.map((candidate) => candidate.score.overall),
      orderedEquals(
        second.candidates.map((candidate) => candidate.score.overall),
      ),
    );
  });

  test('different seeds can produce different layouts', () {
    final project = createSampleProject();
    final first = generator.generate(
      requirements: project.requirements,
      config: config,
      seed: 1,
    );
    final second = generator.generate(
      requirements: project.requirements,
      config: config,
      seed: 2,
    );
    expect(first.candidates, isNotEmpty);
    expect(second.candidates, isNotEmpty);
    expect(
      first.candidates.first.geometrySignature,
      isNot(second.candidates.first.geometrySignature),
    );
  });

  test('impossible requirements fail before generation', () {
    final project = createSampleProject();
    final impossible = project.requirements.copyWith(maximumTotalArea: 20);
    final result = generator.generate(
      requirements: impossible,
      config: config,
      seed: 4,
    );
    expect(result.candidates, isEmpty);
    expect(result.diagnostics.attempted, 0);
    expect(result.feasibilityErrors.join(' '), contains('minimum room area'));
  });

  test('generated candidates preserve invariants across many seeds', () {
    final project = createSampleProject();
    const invariantConfig = GenerationConfig(
      attempts: 70,
      maxValidCandidates: 4,
      displayTopCandidates: 2,
    );
    for (var seed = 20; seed < 28; seed++) {
      final result = generator.generate(
        requirements: project.requirements,
        config: invariantConfig,
        seed: seed,
      );
      expect(result.candidates, isNotEmpty, reason: 'seed $seed');
      for (final candidate in result.candidates) {
        expect(
          const DesignValidator().validate(candidate, project.requirements),
          isEmpty,
        );
        expect(candidate.score.overall, inInclusiveRange(0, 100));
      }
    }
  });

  test('validator rejects duplicate room IDs and malformed floor sets', () {
    final project = createSampleProject();
    final candidate = generator
        .generate(
          requirements: project.requirements,
          config: config,
          seed: project.seed,
        )
        .candidates
        .first;
    final ground = candidate.floors.first;
    final duplicateRooms = List.of(ground.rooms);
    duplicateRooms[1] = duplicateRooms.first;
    final malformed = DesignCandidate(
      id: candidate.id,
      seed: candidate.seed,
      attempt: candidate.attempt,
      floors: <FloorPlan>[
        FloorPlan(
          floorIndex: ground.floorIndex,
          footprint: ground.footprint,
          rooms: duplicateRooms,
        ),
      ],
      score: candidate.score,
      warnings: candidate.warnings,
    );

    final violations = const DesignValidator().validate(
      malformed,
      project.requirements,
    );
    expect(
      violations.map((violation) => violation.constraint.type),
      containsAll(<HardConstraintType>[
        HardConstraintType.requiredRoomCount,
        HardConstraintType.supportedFloorCount,
      ]),
    );
  });

  test('validator rejects an upper floor without support below', () {
    final project = createSampleProject();
    final generated = generator
        .generate(
          requirements: project.requirements,
          config: config,
          seed: project.seed,
        )
        .candidates
        .first;
    final upper = generated.floors[1];
    final unsupported = DesignCandidate(
      id: generated.id,
      seed: generated.seed,
      attempt: generated.attempt,
      floors: <FloorPlan>[
        generated.floors[0],
        FloorPlan(
          floorIndex: upper.floorIndex,
          footprint: Rect2D(
            x: upper.footprint!.x + 100,
            y: upper.footprint!.y,
            width: upper.footprint!.width,
            height: upper.footprint!.height,
          ),
          rooms: upper.rooms,
        ),
      ],
      score: generated.score,
      warnings: generated.warnings,
    );

    final violations = const DesignValidator().validate(
      unsupported,
      project.requirements,
    );
    expect(
      violations.map((violation) => violation.constraint.type),
      contains(HardConstraintType.verticalSupport),
    );
  });
}

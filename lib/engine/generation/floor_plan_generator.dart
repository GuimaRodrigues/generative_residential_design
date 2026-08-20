import 'dart:math' as math;

import '../../core/geometry/geometry_utils.dart';
import '../../core/geometry/rect_2d.dart';
import '../../core/random/deterministic_random.dart';
import '../../domain/design/design_candidate.dart';
import '../../domain/design/floor_plan.dart';
import '../../domain/design/score_breakdown.dart';
import '../../domain/requirements/design_requirements.dart';
import '../../domain/requirements/room_requirement.dart';
import '../partitioning/partition_generator.dart';
import '../scoring/design_scorer.dart';
import '../validation/design_validator.dart';
import '../validation/preflight_validator.dart';
import 'generation_config.dart';
import 'generation_result.dart';

typedef GenerationProgressCallback = void Function(GenerationProgress progress);

class FloorPlanGenerator {
  const FloorPlanGenerator({
    this.preflightValidator = const PreflightValidator(),
  });

  final PreflightValidator preflightValidator;

  GenerationResult generate({
    required DesignRequirements requirements,
    required GenerationConfig config,
    required int seed,
    GenerationProgressCallback? onProgress,
  }) {
    final feasibilityErrors = preflightValidator.validate(requirements);
    if (feasibilityErrors.isNotEmpty) {
      return GenerationResult(
        candidates: const <DesignCandidate>[],
        diagnostics: const GenerationDiagnostics(
          attempted: 0,
          valid: 0,
          rejectionReasons: <String, int>{},
        ),
        feasibilityErrors: feasibilityErrors,
      );
    }

    final validator = DesignValidator(gridSize: config.gridSize);
    final scorer = DesignScorer(
      minimumSharedBoundary: config.minimumSharedBoundary,
    );
    final partitioner = PartitionGenerator(
      gridSize: config.gridSize,
      retriesPerNode: config.partitionRetries,
    );
    final valid = <DesignCandidate>[];
    final signatures = <String>{};
    final rejectionReasons = <String, int>{};
    var attempted = 0;

    for (var attempt = 0; attempt < config.attempts; attempt++) {
      attempted = attempt + 1;
      final attemptSeed = _deriveAttemptSeed(seed, attempt);
      final random = DeterministicRandom(attemptSeed);
      final assigned = _assignRooms(requirements, random);
      final floors = _generateFloors(
        requirements: requirements,
        assignments: assigned,
        config: config,
        random: random,
        partitioner: partitioner,
      );
      if (floors == null) {
        _increment(
          rejectionReasons,
          'Room dimensions could not be resolved by rectangular partitions.',
        );
        onProgress?.call(
          GenerationProgress(
            attempt: attempted,
            totalAttempts: config.attempts,
            validCount: valid.length,
          ),
        );
        continue;
      }

      final draft = DesignCandidate(
        id: 'candidate-${attempt + 1}',
        seed: seed,
        attempt: attempt,
        floors: floors,
        score: _emptyScore,
        warnings: const <String>[],
      );
      final violations = validator.validate(draft, requirements);
      if (violations.isNotEmpty) {
        _increment(rejectionReasons, violations.first.message);
      } else if (signatures.add(draft.geometrySignature)) {
        final breakdown = scorer.score(draft, requirements);
        final warnings = breakdown.relationshipDetails
            .where((detail) => !detail.satisfied)
            .map(
              (detail) =>
                  '${detail.label} is weakly satisfied (${detail.score.toStringAsFixed(0)}).',
            )
            .toList(growable: false);
        valid.add(
          DesignCandidate(
            id: draft.id,
            seed: draft.seed,
            attempt: draft.attempt,
            floors: draft.floors,
            score: breakdown,
            warnings: warnings,
          ),
        );
      }
      onProgress?.call(
        GenerationProgress(
          attempt: attempted,
          totalAttempts: config.attempts,
          validCount: valid.length,
        ),
      );
      if (valid.length >= config.maxValidCandidates) {
        break;
      }
    }

    valid.sort((first, second) {
      final scoreComparison = second.score.overall.compareTo(
        first.score.overall,
      );
      return scoreComparison != 0
          ? scoreComparison
          : first.geometrySignature.compareTo(second.geometrySignature);
    });
    final top = valid.take(config.displayTopCandidates).toList(growable: false);
    return GenerationResult(
      candidates: List<DesignCandidate>.unmodifiable(top),
      diagnostics: GenerationDiagnostics(
        attempted: attempted,
        valid: valid.length,
        rejectionReasons: Map<String, int>.unmodifiable(rejectionReasons),
      ),
    );
  }

  List<List<RoomInstance>> _assignRooms(
    DesignRequirements requirements,
    DeterministicRandom random,
  ) {
    final assignments = List<List<RoomInstance>>.generate(
      requirements.floorCount,
      (_) => <RoomInstance>[],
    );
    final flexible = <RoomInstance>[];
    for (final room in requirements.normalizeRooms()) {
      switch (room.preferredFloor) {
        case PreferredFloor.ground:
          assignments[0].add(room);
        case PreferredFloor.upper:
          assignments[1].add(room);
        case PreferredFloor.any:
          flexible.add(room);
      }
    }
    random.shuffle(flexible);
    for (final room in flexible) {
      if (requirements.floorCount == 1) {
        assignments[0].add(room);
        continue;
      }
      final groundArea = assignments[0].fold<double>(
        0,
        (sum, item) => sum + item.targetArea,
      );
      final upperArea = assignments[1].fold<double>(
        0,
        (sum, item) => sum + item.targetArea,
      );
      final groundProbability =
          ((upperArea + room.targetArea) /
                  (groundArea + upperArea + room.targetArea * 2))
              .clamp(0.22, 0.78);
      assignments[random.nextBool(groundProbability) ? 0 : 1].add(room);
    }
    return assignments;
  }

  List<FloorPlan>? _generateFloors({
    required DesignRequirements requirements,
    required List<List<RoomInstance>> assignments,
    required GenerationConfig config,
    required DeterministicRandom random,
    required PartitionGenerator partitioner,
  }) {
    final plans = <FloorPlan>[];
    final totalTarget = assignments
        .expand((rooms) => rooms)
        .fold<double>(0, (sum, room) => sum + room.targetArea);
    final floorTargets = assignments
        .map(
          (rooms) =>
              rooms.fold<double>(0, (sum, room) => sum + room.targetArea),
        )
        .toList(growable: false);
    final floorMinimums = assignments
        .map(
          (rooms) => rooms.fold<double>(0, (sum, room) => sum + room.minArea),
        )
        .toList(growable: false);
    Rect2D? supportingFootprint;
    for (var floor = 0; floor < requirements.floorCount; floor++) {
      final rooms = assignments[floor];
      if (rooms.isEmpty) {
        plans.add(
          FloorPlan(floorIndex: floor, footprint: null, rooms: const []),
        );
        continue;
      }
      if (floor > 0 && supportingFootprint == null) return null;
      final floorTarget = floorTargets[floor];
      final budget = requirements.maximumTotalArea == null
          ? null
          : requirements.maximumTotalArea! * floorTarget / totalTarget;
      final upperFloorMinimum = floor + 1 < floorMinimums.length
          ? floorMinimums.skip(floor + 1).fold<double>(0, math.max)
          : 0.0;
      final upperFloorTarget = floor + 1 < floorTargets.length
          ? floorTargets.skip(floor + 1).fold<double>(0, math.max)
          : 0.0;
      PartitionOutcome? outcome;
      Rect2D? footprint;
      for (var retry = 0; retry < 18 && outcome == null; retry++) {
        footprint = _createFootprint(
          rooms: rooms,
          envelope: supportingFootprint ?? requirements.site.buildableEnvelope,
          budget: budget,
          grid: config.gridSize,
          random: random,
          minimumFootprintArea: upperFloorMinimum,
          targetFootprintArea: upperFloorTarget,
          centerInEnvelope: floor > 0,
        );
        if (footprint == null) continue;
        outcome = partitioner.generate(
          rooms: rooms,
          footprint: footprint,
          floorIndex: floor,
          random: random,
        );
      }
      if (outcome == null || footprint == null) return null;
      plans.add(
        FloorPlan(
          floorIndex: floor,
          footprint: footprint,
          rooms: List.unmodifiable(outcome.rooms),
        ),
      );
      supportingFootprint = footprint;
    }
    return List<FloorPlan>.unmodifiable(plans);
  }

  Rect2D? _createFootprint({
    required List<RoomInstance> rooms,
    required Rect2D envelope,
    required double? budget,
    required double grid,
    required DeterministicRandom random,
    double minimumFootprintArea = 0,
    double targetFootprintArea = 0,
    bool centerInEnvelope = false,
  }) {
    final roomMinimumArea = rooms.fold<double>(
      0,
      (sum, room) => sum + room.minArea,
    );
    final minimumArea = math.max(roomMinimumArea, minimumFootprintArea);
    final roomTargetArea = rooms.fold<double>(
      0,
      (sum, room) => sum + room.targetArea,
    );
    final targetArea = math.max(roomTargetArea, targetFootprintArea);
    final upperArea = math.min(envelope.area, budget ?? envelope.area);
    if (minimumArea > upperArea + 1e-6) return null;
    final desiredArea = (targetArea * random.between(0.96, 1.12)).clamp(
      minimumArea,
      upperArea,
    );
    final minimumShortSide = rooms
        .map((room) => math.min(room.minWidth, room.minDepth))
        .fold<double>(0, math.max);
    final minimumWidth = math.max(
      minimumShortSide,
      desiredArea / envelope.height,
    );
    final maximumWidth = math.min(
      envelope.width,
      desiredArea / minimumShortSide,
    );
    if (minimumWidth > maximumWidth + 1e-6) return null;

    var width = snapToGrid(
      random.between(minimumWidth, maximumWidth),
      grid: grid,
    );
    width = width.clamp(
      ceilToGrid(minimumWidth, grid: grid),
      floorToGrid(envelope.width, grid: grid),
    );
    var height = ceilToGrid(desiredArea / width, grid: grid);
    height = math.max(height, ceilToGrid(minimumShortSide, grid: grid));
    if (height > floorToGrid(envelope.height, grid: grid) + 1e-6) return null;
    if (width * height > upperArea + grid * math.max(width, height)) {
      return null;
    }

    final minX = ceilToGrid(envelope.left, grid: grid);
    final maxX = floorToGrid(envelope.right - width, grid: grid);
    final minY = ceilToGrid(envelope.top, grid: grid);
    final maxY = floorToGrid(envelope.bottom - height, grid: grid);
    if (maxX < minX - 1e-6 || maxY < minY - 1e-6) return null;
    final x = centerInEnvelope
        ? snapToGrid((minX + maxX) / 2, grid: grid).clamp(minX, maxX)
        : _gridChoice(minX, maxX, grid, random);
    final y = centerInEnvelope
        ? snapToGrid((minY + maxY) / 2, grid: grid).clamp(minY, maxY)
        : _gridChoice(minY, maxY, grid, random);
    return Rect2D(x: x, y: y, width: width, height: height);
  }

  double _gridChoice(
    double min,
    double max,
    double grid,
    DeterministicRandom random,
  ) {
    final steps = ((max - min) / grid).floor();
    return min + (steps == 0 ? 0 : random.nextInt(steps + 1) * grid);
  }

  int _deriveAttemptSeed(int seed, int attempt) {
    var value =
        (seed & 0xffffffff) ^
        DeterministicRandom.multiplyUint32(attempt + 1, 0x9e3779b9);
    value ^= value >>> 16;
    value = DeterministicRandom.multiplyUint32(value, 0x7feb352d);
    value ^= value >>> 15;
    return value & 0xffffffff;
  }

  void _increment(Map<String, int> reasons, String reason) {
    reasons[reason] = (reasons[reason] ?? 0) + 1;
  }
}

const ScoreBreakdown _emptyScore = ScoreBreakdown(
  overall: 0,
  relationships: 0,
  roomProportions: 0,
  streetOrientation: 0,
  compactness: 0,
  floorPreference: 0,
  relationshipDetails: <RelationshipScoreDetail>[],
);

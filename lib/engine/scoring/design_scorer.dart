import 'dart:math' as math;

import '../../core/geometry/geometry_utils.dart';
import '../../core/geometry/rect_2d.dart';
import '../../domain/design/design_candidate.dart';
import '../../domain/design/generated_room.dart';
import '../../domain/design/score_breakdown.dart';
import '../../domain/requirements/design_requirements.dart';
import '../../domain/requirements/room_requirement.dart';
import '../../domain/requirements/spatial_relationship.dart';
import '../../domain/site/site.dart';

class DesignScorer {
  const DesignScorer({this.minimumSharedBoundary = 0.5});
  final double minimumSharedBoundary;

  ScoreBreakdown score(
    DesignCandidate candidate,
    DesignRequirements requirements,
  ) {
    final details = <RelationshipScoreDetail>[];
    final roomScores = <_WeightedScore>[];
    final streetScores = <_WeightedScore>[];
    for (final relationship in requirements.relationships.where(
      (item) => item.enabled,
    )) {
      final value = relationship.target.siteZone == SiteZone.street
          ? _scoreStreetRelationship(candidate, requirements, relationship)
          : _scoreRoomRelationship(candidate, requirements, relationship);
      details.add(
        RelationshipScoreDetail(label: relationship.label, score: value),
      );
      final weighted = _WeightedScore(value, relationship.weight);
      if (relationship.target.siteZone == SiteZone.street) {
        streetScores.add(weighted);
      } else {
        roomScores.add(weighted);
      }
    }

    final relationshipScore = _average(roomScores);
    final streetScore = _average(streetScores);
    final proportionScore = _roomProportions(candidate);
    final compactnessScore = _compactness(candidate);
    final floorScore = _floorPreferences(candidate);
    final overall =
        relationshipScore * 0.30 +
        proportionScore * 0.28 +
        streetScore * 0.15 +
        compactnessScore * 0.17 +
        floorScore * 0.10;
    return ScoreBreakdown(
      overall: _round(overall),
      relationships: _round(relationshipScore),
      roomProportions: _round(proportionScore),
      streetOrientation: _round(streetScore),
      compactness: _round(compactnessScore),
      floorPreference: _round(floorScore),
      relationshipDetails: List<RelationshipScoreDetail>.unmodifiable(details),
    );
  }

  double _scoreRoomRelationship(
    DesignCandidate candidate,
    DesignRequirements requirements,
    SpatialRelationship relationship,
  ) {
    final sources = candidate.rooms
        .where((room) => room.roomType == relationship.source)
        .toList();
    final targetType = relationship.target.roomType!;
    final targets = candidate.rooms
        .where((room) => room.roomType == targetType)
        .toList();
    final scores = <double>[];
    for (final source in sources) {
      for (final target in targets) {
        if (source.id == target.id) continue;
        if (relationship.source == targetType &&
            source.id.compareTo(target.id) > 0) {
          continue;
        }
        scores.add(_scorePair(source, target, requirements, relationship.type));
      }
    }
    if (scores.isEmpty) return 50;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  double _scorePair(
    GeneratedRoom source,
    GeneratedRoom target,
    DesignRequirements requirements,
    SpatialRelationshipType type,
  ) {
    final sameFloor = source.floorIndex == target.floorIndex;
    return switch (type) {
      SpatialRelationshipType.adjacentTo =>
        sameFloor &&
                source.bounds.isAdjacentTo(
                  target.bounds,
                  minimumSharedBoundary: minimumSharedBoundary,
                )
            ? 100
            : 0,
      SpatialRelationshipType.near =>
        !sameFloor
            ? 15
            : (100 *
                      (1 -
                          normalizedDistance(
                                source.bounds.center,
                                target.bounds.center,
                                requirements.site.buildableEnvelope,
                              ) /
                              0.72))
                  .clamp(0, 100),
      SpatialRelationshipType.awayFrom =>
        !sameFloor
            ? 100
            : (100 *
                      normalizedDistance(
                        source.bounds.center,
                        target.bounds.center,
                        requirements.site.buildableEnvelope,
                      ) /
                      0.55)
                  .clamp(0, 100),
      SpatialRelationshipType.sameFloor => sameFloor ? 100 : 0,
      SpatialRelationshipType.differentFloor => sameFloor ? 0 : 100,
    };
  }

  double _scoreStreetRelationship(
    DesignCandidate candidate,
    DesignRequirements requirements,
    SpatialRelationship relationship,
  ) {
    final rooms = candidate.rooms
        .where((room) => room.roomType == relationship.source)
        .toList();
    if (rooms.isEmpty) return 50;
    final scores = rooms
        .map((room) {
          final site = requirements.site;
          final center = room.bounds.center;
          final normalized = switch (site.streetSide) {
            StreetSide.north => center.y / site.depth,
            StreetSide.south => (site.depth - center.y) / site.depth,
            StreetSide.east => (site.width - center.x) / site.width,
            StreetSide.west => center.x / site.width,
          };
          return relationship.type == SpatialRelationshipType.awayFrom
              ? (normalized * 170).clamp(0, 100).toDouble()
              : ((1 - normalized) * 135).clamp(0, 100).toDouble();
        })
        .toList(growable: false);
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  double _roomProportions(DesignCandidate candidate) {
    if (candidate.rooms.isEmpty) return 0;
    var total = 0.0;
    for (final room in candidate.rooms) {
      final areaRatio =
          math.min(room.area, room.source.targetArea) /
          math.max(room.area, room.source.targetArea);
      final aspect = room.bounds.aspectRatio;
      final aspectScore = aspect <= 1.8
          ? 1.0
          : (1 - (aspect - 1.8) / 2.7).clamp(0, 1);
      total += 100 * (areaRatio * 0.62 + aspectScore * 0.38);
    }
    return total / candidate.rooms.length;
  }

  double _compactness(DesignCandidate candidate) {
    final footprints = candidate.floors
        .map((floor) => floor.footprint)
        .whereType<Rect2D>()
        .toList(growable: false);
    if (footprints.isEmpty) return 0;
    var aspectTotal = 0.0;
    for (final footprint in footprints) {
      final aspect = footprint.aspectRatio;
      aspectTotal += aspect <= 1.7
          ? 100
          : (100 - (aspect - 1.7) * 24).clamp(20, 100);
    }
    var score = aspectTotal / footprints.length;
    if (footprints.length == 2) {
      final overlap = footprints[0].intersection(footprints[1]);
      final overlapRatio = overlap == null
          ? 0.0
          : overlap.area / math.min(footprints[0].area, footprints[1].area);
      score = score * 0.72 + overlapRatio * 100 * 0.28;
    }
    return score;
  }

  double _floorPreferences(DesignCandidate candidate) {
    final rooms = candidate.rooms.toList(growable: false);
    if (rooms.isEmpty) return 0;
    final values = rooms.map((room) {
      return switch (room.source.preferredFloor) {
        PreferredFloor.any => 100.0,
        PreferredFloor.ground => room.floorIndex == 0 ? 100.0 : 0.0,
        PreferredFloor.upper => room.floorIndex == 1 ? 100.0 : 0.0,
      };
    });
    return values.reduce((a, b) => a + b) / rooms.length;
  }

  double _average(List<_WeightedScore> scores) {
    if (scores.isEmpty) return 100;
    final weight = scores.fold<double>(0, (sum, score) => sum + score.weight);
    return scores.fold<double>(
          0,
          (sum, score) => sum + score.value * score.weight,
        ) /
        weight;
  }

  double _round(double value) => (value * 10).round() / 10;
}

class _WeightedScore {
  const _WeightedScore(this.value, this.weight);
  final double value;
  final double weight;
}

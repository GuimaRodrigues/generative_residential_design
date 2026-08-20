import 'package:flutter_test/flutter_test.dart';
import 'package:generative_residential_design/core/geometry/rect_2d.dart';
import 'package:generative_residential_design/domain/design/design_candidate.dart';
import 'package:generative_residential_design/domain/design/floor_plan.dart';
import 'package:generative_residential_design/domain/design/generated_room.dart';
import 'package:generative_residential_design/domain/design/score_breakdown.dart';
import 'package:generative_residential_design/domain/requirements/design_requirements.dart';
import 'package:generative_residential_design/domain/requirements/room_requirement.dart';
import 'package:generative_residential_design/domain/requirements/room_type.dart';
import 'package:generative_residential_design/domain/requirements/spatial_relationship.dart';
import 'package:generative_residential_design/domain/site/site.dart';
import 'package:generative_residential_design/engine/scoring/design_scorer.dart';

void main() {
  const site = Site(
    width: 10,
    depth: 12,
    streetSide: StreetSide.north,
    frontSetback: 1,
    rearSetback: 1,
    leftSetback: 1,
    rightSetback: 1,
  );

  (DesignCandidate, DesignRequirements) fixture({
    required Rect2D secondBounds,
  }) {
    const livingRequirement = RoomRequirement(
      id: 'living',
      roomType: RoomType.livingRoom,
    );
    const kitchenRequirement = RoomRequirement(
      id: 'kitchen',
      roomType: RoomType.kitchen,
    );
    final requirements = DesignRequirements(
      site: site,
      floorCount: 1,
      rooms: const <RoomRequirement>[livingRequirement, kitchenRequirement],
      relationships: const <SpatialRelationship>[
        SpatialRelationship(
          id: 'adjacency',
          source: RoomType.livingRoom,
          target: RelationshipTarget.room(RoomType.kitchen),
          type: SpatialRelationshipType.adjacentTo,
          label: 'Living adjacent to kitchen',
        ),
      ],
    );
    final instances = requirements.normalizeRooms();
    return (
      _candidate(<GeneratedRoom>[
        GeneratedRoom(
          source: instances[0],
          floorIndex: 0,
          bounds: const Rect2D(x: 1, y: 1, width: 4, height: 4),
        ),
        GeneratedRoom(
          source: instances[1],
          floorIndex: 0,
          bounds: secondBounds,
        ),
      ]),
      requirements,
    );
  }

  (DesignCandidate, DesignRequirements) streetFixture(Rect2D bounds) {
    final requirements = DesignRequirements(
      site: site,
      floorCount: 1,
      rooms: const <RoomRequirement>[
        RoomRequirement(id: 'garage', roomType: RoomType.garage),
      ],
      relationships: const <SpatialRelationship>[
        SpatialRelationship(
          id: 'street',
          source: RoomType.garage,
          target: RelationshipTarget.site(SiteZone.street),
          type: SpatialRelationshipType.near,
          label: 'Garage near street',
        ),
      ],
    );
    return (
      _candidate(<GeneratedRoom>[
        GeneratedRoom(
          source: requirements.normalizeRooms().single,
          floorIndex: 0,
          bounds: bounds,
        ),
      ]),
      requirements,
    );
  }

  test('adjacency score uses shared wall rather than corner contact', () {
    final adjacent = fixture(
      secondBounds: const Rect2D(x: 5, y: 1, width: 4, height: 4),
    );
    final corner = fixture(
      secondBounds: const Rect2D(x: 5, y: 5, width: 4, height: 4),
    );
    const scorer = DesignScorer();
    expect(scorer.score(adjacent.$1, adjacent.$2).relationships, 100);
    expect(scorer.score(corner.$1, corner.$2).relationships, 0);
  });

  test('near-street preference rewards the closer garage', () {
    final near = streetFixture(const Rect2D(x: 1, y: 1, width: 4, height: 4));
    final far = streetFixture(const Rect2D(x: 1, y: 7, width: 4, height: 4));
    const scorer = DesignScorer();
    expect(
      scorer.score(near.$1, near.$2).streetOrientation,
      greaterThan(scorer.score(far.$1, far.$2).streetOrientation),
    );
  });
}

DesignCandidate _candidate(List<GeneratedRoom> rooms) => DesignCandidate(
  id: 'test',
  seed: 1,
  attempt: 0,
  floors: <FloorPlan>[
    FloorPlan(
      floorIndex: 0,
      footprint: const Rect2D(x: 1, y: 1, width: 8, height: 8),
      rooms: rooms,
    ),
  ],
  score: const ScoreBreakdown(
    overall: 0,
    relationships: 0,
    roomProportions: 0,
    streetOrientation: 0,
    compactness: 0,
    floorPreference: 0,
    relationshipDetails: <RelationshipScoreDetail>[],
  ),
  warnings: const <String>[],
);

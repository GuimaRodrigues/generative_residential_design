import 'package:flutter_test/flutter_test.dart';
import 'package:generative_residential_design/core/geometry/rect_2d.dart';
import 'package:generative_residential_design/domain/building/architectural_scene_3d.dart';
import 'package:generative_residential_design/domain/design/design_candidate.dart';
import 'package:generative_residential_design/domain/design/floor_plan.dart';
import 'package:generative_residential_design/domain/design/generated_room.dart';
import 'package:generative_residential_design/domain/design/score_breakdown.dart';
import 'package:generative_residential_design/domain/requirements/room_requirement.dart';
import 'package:generative_residential_design/domain/requirements/room_type.dart';
import 'package:generative_residential_design/domain/site/site.dart';
import 'package:generative_residential_design/engine/scene/architectural_scene_builder.dart';
import 'package:generative_residential_design/features/floor_plan/application/floor_plan_cubit.dart';

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

  test('deduplicates shared room edges into one interior wall', () {
    final scene = const ArchitecturalSceneBuilder().build(
      candidate: _candidate(<FloorPlan>[
        FloorPlan(
          floorIndex: 0,
          footprint: const Rect2D(x: 0, y: 0, width: 8, height: 4),
          rooms: <GeneratedRoom>[
            _room(
              id: 'living',
              type: RoomType.livingRoom,
              floor: 0,
              bounds: const Rect2D(x: 0, y: 0, width: 4, height: 4),
            ),
            _room(
              id: 'kitchen',
              type: RoomType.kitchen,
              floor: 0,
              bounds: const Rect2D(x: 4, y: 0, width: 4, height: 4),
            ),
          ],
        ),
      ]),
      site: site,
    );

    final walls = scene.levels.single.walls;
    expect(walls, hasLength(5));
    expect(walls.map((wall) => wall.id).toSet(), hasLength(5));
    expect(walls.where((wall) => wall.kind == WallKind.exterior), hasLength(4));
    final shared = walls.singleWhere((wall) => wall.kind == WallKind.interior);
    expect(shared.start.x, 4);
    expect(shared.end.x, 4);
    expect(shared.length, 4);
    expect(shared.thickness, 0.12);

    final openings = scene.levels.single.openings;
    expect(
      openings.where(
        (opening) => opening.kind == ArchitecturalOpeningKind.door,
      ),
      hasLength(1),
    );
    expect(
      openings.where(
        (opening) => opening.kind == ArchitecturalOpeningKind.window,
      ),
      isNotEmpty,
    );
    expect(scene.roof, isNotNull);
    expect(scene.roof!.footprint, scene.levels.single.footprint);
  });

  test('preserves floor elevations, spaces, and selection in scene JSON', () {
    final scene = const ArchitecturalSceneBuilder().build(
      candidate: _candidate(<FloorPlan>[
        FloorPlan(
          floorIndex: 0,
          footprint: const Rect2D(x: 1, y: 1, width: 4, height: 4),
          rooms: <GeneratedRoom>[
            _room(
              id: 'ground-room',
              type: RoomType.livingRoom,
              floor: 0,
              bounds: const Rect2D(x: 1, y: 1, width: 4, height: 4),
            ),
          ],
        ),
        FloorPlan(
          floorIndex: 1,
          footprint: const Rect2D(x: 1, y: 1, width: 4, height: 4),
          rooms: <GeneratedRoom>[
            _room(
              id: 'upper-room',
              type: RoomType.bedroom,
              floor: 1,
              bounds: const Rect2D(x: 1, y: 1, width: 4, height: 4),
            ),
          ],
        ),
      ]),
      site: site,
    );

    expect(scene.levels, hasLength(2));
    expect(scene.levels[0].elevation, 0);
    expect(scene.levels[1].elevation, 3.1);
    expect(
      scene.dimensions.wallHeight + scene.dimensions.slabThickness,
      closeTo(scene.dimensions.floorToFloorHeight, 1e-9),
      reason: 'walls must meet the underside of the next slab without a gap',
    );
    expect(scene.roof!.baseElevation, closeTo(6.02, 1e-9));
    expect(scene.roof!.ridgeHeight, greaterThan(1));
    expect(scene.levels.expand((level) => level.spaces), hasLength(2));
    expect(
      scene.levels
          .expand((level) => level.walls)
          .every((wall) => wall.length > 0 && wall.height == 2.92),
      isTrue,
    );
    final json = scene.toJson(
      selectedFloorIndex: 1,
      selectedRoomId: 'upper-room',
      displayMode: Scene3DDisplayMode.cutaway,
    );
    final selection = json['selection']! as Map<String, Object?>;
    expect(selection, <String, Object?>{
      'floorIndex': 1,
      'roomId': 'upper-room',
    });
    expect(json['display'], <String, Object>{'mode': 'cutaway'});
  });

  test('places a vehicle opening on a street-facing garage wall', () {
    final scene = const ArchitecturalSceneBuilder().build(
      candidate: _candidate(<FloorPlan>[
        FloorPlan(
          floorIndex: 0,
          footprint: const Rect2D(x: 1, y: 1, width: 8, height: 6),
          rooms: <GeneratedRoom>[
            _room(
              id: 'garage',
              type: RoomType.garage,
              floor: 0,
              bounds: const Rect2D(x: 1, y: 1, width: 3, height: 6),
            ),
            _room(
              id: 'living',
              type: RoomType.livingRoom,
              floor: 0,
              bounds: const Rect2D(x: 4, y: 1, width: 5, height: 6),
            ),
          ],
        ),
      ]),
      site: site,
    );

    final garageDoor = scene.levels.single.openings.singleWhere(
      (opening) => opening.kind == ArchitecturalOpeningKind.garageDoor,
    );
    final wall = scene.levels.single.walls.singleWhere(
      (wall) => wall.id == garageDoor.wallId,
    );
    expect(wall.start.y, 1);
    expect(garageDoor.width, greaterThanOrEqualTo(2.4));
  });

  test('2D and 3D modes share floor and room selection state', () async {
    final cubit = FloorPlanCubit();
    addTearDown(cubit.close);

    cubit.selectViewMode(FloorPlanViewMode.model3D);
    cubit.selectRoom('upper-room', floorIndex: 1);

    expect(cubit.state.viewMode, FloorPlanViewMode.model3D);
    expect(cubit.state.floorIndex, 1);
    expect(cubit.state.selectedRoomId, 'upper-room');

    cubit.selectViewMode(FloorPlanViewMode.plan2D);
    expect(cubit.state.floorIndex, 1);
    expect(cubit.state.selectedRoomId, 'upper-room');
  });
}

GeneratedRoom _room({
  required String id,
  required RoomType type,
  required int floor,
  required Rect2D bounds,
}) => GeneratedRoom(
  source: RoomInstance(
    id: id,
    requirementId: id,
    roomType: type,
    preferredFloor: PreferredFloor.any,
    targetArea: bounds.area,
    minArea: 1,
    minWidth: 1,
    minDepth: 1,
  ),
  floorIndex: floor,
  bounds: bounds,
);

DesignCandidate _candidate(List<FloorPlan> floors) => DesignCandidate(
  id: 'scene-test',
  seed: 1,
  attempt: 0,
  floors: floors,
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

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
    final windows = openings
        .where((opening) => opening.kind == ArchitecturalOpeningKind.window)
        .toList(growable: false);
    expect(windows, isNotEmpty);
    expect(
      windows.every(
        (opening) =>
            opening.roomType == RoomType.livingRoom ||
            opening.roomType == RoomType.kitchen,
      ),
      isTrue,
    );
    expect(windows.every((opening) => opening.height >= 1.7), isTrue);
    expect(windows.every((opening) => opening.sillHeight <= 0.38), isTrue);
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
    if (scene.roof!.kind == ArchitecturalRoofKind.flat) {
      expect(scene.roof!.ridgeHeight, 0.24);
    } else {
      expect(scene.roof!.ridgeHeight, greaterThan(0.9));
    }
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
    expect(json['appearance'], <String, Object>{
      'exteriorStyle': scene.appearance.exteriorStyle.name,
      'facadeVariant': scene.appearance.facadeVariant,
    });
    expect(
      (json['roof']! as Map<String, Object>)['kind'],
      scene.roof!.kind.name,
    );
    final serializedLevels = json['levels']! as List<Map<String, Object?>>;
    final serializedOpenings = serializedLevels
        .expand((level) => level['openings']! as List<Map<String, Object>>)
        .toList(growable: false);
    expect(
      serializedOpenings.every((opening) => opening['roomType'] is String),
      isTrue,
    );
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

  test('seed and attempt deterministically vary exterior appearance', () {
    final floors = <FloorPlan>[
      FloorPlan(
        floorIndex: 0,
        footprint: const Rect2D(x: 1, y: 1, width: 8, height: 6),
        rooms: <GeneratedRoom>[
          _room(
            id: 'living',
            type: RoomType.livingRoom,
            floor: 0,
            bounds: const Rect2D(x: 1, y: 1, width: 8, height: 6),
          ),
        ],
      ),
    ];
    final scenes = <ArchitecturalScene3D>[
      for (var seed = 1; seed <= 96; seed++)
        const ArchitecturalSceneBuilder().build(
          candidate: _candidate(floors, seed: seed, attempt: seed % 5),
          site: site,
        ),
    ];

    expect(
      scenes.map((scene) => scene.appearance.exteriorStyle).toSet().length,
      ArchitecturalExteriorStyle.values.length,
    );
    expect(
      scenes.map((scene) => scene.appearance.facadeVariant).toSet(),
      containsAll(<int>[0, 1, 2, 3, 4]),
    );
    expect(
      scenes.map((scene) => scene.roof!.kind).toSet(),
      containsAll(ArchitecturalRoofKind.values),
    );
    expect(
      scenes
          .where((scene) => scene.roof!.kind == ArchitecturalRoofKind.flat)
          .length,
      greaterThan(scenes.length ~/ 2),
    );
    final first = const ArchitecturalSceneBuilder().build(
      candidate: _candidate(floors, seed: 98231, attempt: 7),
      site: site,
    );
    final replay = const ArchitecturalSceneBuilder().build(
      candidate: _candidate(floors, seed: 98231, attempt: 7),
      site: site,
    );
    expect(replay.appearance.exteriorStyle, first.appearance.exteriorStyle);
    expect(replay.appearance.facadeVariant, first.appearance.facadeVariant);
    expect(replay.roof!.kind, first.roof!.kind);
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

DesignCandidate _candidate(
  List<FloorPlan> floors, {
  int seed = 1,
  int attempt = 0,
}) => DesignCandidate(
  id: 'scene-test',
  seed: seed,
  attempt: attempt,
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

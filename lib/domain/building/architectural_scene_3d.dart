import '../../core/geometry/point_2d.dart';
import '../../core/geometry/rect_2d.dart';
import '../requirements/room_type.dart';
import '../site/site.dart';

enum WallKind { exterior, interior }

class ArchitecturalDimensions {
  const ArchitecturalDimensions({
    this.floorToFloorHeight = 3.1,
    this.wallHeight = 2.8,
    this.exteriorWallThickness = 0.18,
    this.interiorWallThickness = 0.12,
    this.slabThickness = 0.18,
  });

  final double floorToFloorHeight;
  final double wallHeight;
  final double exteriorWallThickness;
  final double interiorWallThickness;
  final double slabThickness;
}

class ArchitecturalSpace3D {
  const ArchitecturalSpace3D({
    required this.id,
    required this.roomType,
    required this.floorIndex,
    required this.bounds,
  });

  final String id;
  final RoomType roomType;
  final int floorIndex;
  final Rect2D bounds;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'label': roomType.displayName,
    'roomType': roomType.name,
    'floorIndex': floorIndex,
    'bounds': bounds.toJson(),
  };
}

class ArchitecturalWall3D {
  const ArchitecturalWall3D({
    required this.id,
    required this.floorIndex,
    required this.start,
    required this.end,
    required this.kind,
    required this.thickness,
    required this.height,
  });

  final String id;
  final int floorIndex;
  final Point2D start;
  final Point2D end;
  final WallKind kind;
  final double thickness;
  final double height;

  double get length => start.distanceTo(end);
  bool get isHorizontal => start.y == end.y;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'floorIndex': floorIndex,
    'start': start.toJson(),
    'end': end.toJson(),
    'kind': kind.name,
    'thickness': thickness,
    'height': height,
  };
}

class ArchitecturalLevel3D {
  const ArchitecturalLevel3D({
    required this.floorIndex,
    required this.elevation,
    required this.slabThickness,
    required this.footprint,
    required this.spaces,
    required this.walls,
  });

  final int floorIndex;
  final double elevation;
  final double slabThickness;
  final Rect2D? footprint;
  final List<ArchitecturalSpace3D> spaces;
  final List<ArchitecturalWall3D> walls;

  Map<String, Object?> toJson() => <String, Object?>{
    'floorIndex': floorIndex,
    'elevation': elevation,
    'slabThickness': slabThickness,
    'footprint': footprint?.toJson(),
    'spaces': spaces.map((space) => space.toJson()).toList(growable: false),
    'walls': walls.map((wall) => wall.toJson()).toList(growable: false),
  };
}

class ArchitecturalScene3D {
  const ArchitecturalScene3D({
    required this.site,
    required this.dimensions,
    required this.levels,
  });

  final Site site;
  final ArchitecturalDimensions dimensions;
  final List<ArchitecturalLevel3D> levels;

  Map<String, Object?> toJson({
    required int selectedFloorIndex,
    String? selectedRoomId,
  }) => <String, Object?>{
    'site': <String, Object?>{
      ...site.toJson(),
      'bounds': site.lotBounds.toJson(),
      'buildableEnvelope': site.buildableEnvelope.toJson(),
    },
    'dimensions': <String, Object>{
      'floorToFloorHeight': dimensions.floorToFloorHeight,
      'wallHeight': dimensions.wallHeight,
      'exteriorWallThickness': dimensions.exteriorWallThickness,
      'interiorWallThickness': dimensions.interiorWallThickness,
      'slabThickness': dimensions.slabThickness,
    },
    'levels': levels.map((level) => level.toJson()).toList(growable: false),
    'selection': <String, Object?>{
      'floorIndex': selectedFloorIndex,
      'roomId': selectedRoomId,
    },
  };
}

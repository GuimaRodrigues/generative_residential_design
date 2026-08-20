import '../../core/geometry/point_2d.dart';
import '../../core/geometry/rect_2d.dart';
import '../requirements/room_type.dart';
import '../site/site.dart';

enum WallKind { exterior, interior }

enum ArchitecturalOpeningKind { door, window, garageDoor }

enum RoofRidgeAxis { x, y }

enum ArchitecturalRoofKind { gable, hip, flat }

enum ArchitecturalExteriorStyle {
  lightMinimal,
  warmModern,
  graphiteModern,
  coastalModern,
}

enum Scene3DDisplayMode { exterior, cutaway }

class ArchitecturalDimensions {
  const ArchitecturalDimensions({
    this.floorToFloorHeight = 3.1,
    this.wallHeight = 2.92,
    this.exteriorWallThickness = 0.18,
    this.interiorWallThickness = 0.12,
    this.slabThickness = 0.18,
    this.roofOverhang = 0.45,
  });

  final double floorToFloorHeight;
  final double wallHeight;
  final double exteriorWallThickness;
  final double interiorWallThickness;
  final double slabThickness;
  final double roofOverhang;
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

class ArchitecturalOpening3D {
  const ArchitecturalOpening3D({
    required this.id,
    required this.wallId,
    required this.floorIndex,
    required this.kind,
    required this.centerOffset,
    required this.width,
    required this.height,
    required this.sillHeight,
  });

  final String id;
  final String wallId;
  final int floorIndex;
  final ArchitecturalOpeningKind kind;
  final double centerOffset;
  final double width;
  final double height;
  final double sillHeight;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'wallId': wallId,
    'floorIndex': floorIndex,
    'kind': kind.name,
    'centerOffset': centerOffset,
    'width': width,
    'height': height,
    'sillHeight': sillHeight,
  };
}

class ArchitecturalRoof3D {
  const ArchitecturalRoof3D({
    required this.kind,
    required this.footprint,
    required this.baseElevation,
    required this.ridgeHeight,
    required this.overhang,
    required this.ridgeAxis,
  });

  final ArchitecturalRoofKind kind;
  final Rect2D footprint;
  final double baseElevation;
  final double ridgeHeight;
  final double overhang;
  final RoofRidgeAxis ridgeAxis;

  Map<String, Object> toJson() => <String, Object>{
    'kind': kind.name,
    'footprint': footprint.toJson(),
    'baseElevation': baseElevation,
    'ridgeHeight': ridgeHeight,
    'overhang': overhang,
    'ridgeAxis': ridgeAxis.name,
  };
}

class ArchitecturalAppearance3D {
  const ArchitecturalAppearance3D({
    required this.exteriorStyle,
    required this.facadeVariant,
  });

  final ArchitecturalExteriorStyle exteriorStyle;
  final int facadeVariant;

  Map<String, Object> toJson() => <String, Object>{
    'exteriorStyle': exteriorStyle.name,
    'facadeVariant': facadeVariant,
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
    required this.openings,
  });

  final int floorIndex;
  final double elevation;
  final double slabThickness;
  final Rect2D? footprint;
  final List<ArchitecturalSpace3D> spaces;
  final List<ArchitecturalWall3D> walls;
  final List<ArchitecturalOpening3D> openings;

  Map<String, Object?> toJson() => <String, Object?>{
    'floorIndex': floorIndex,
    'elevation': elevation,
    'slabThickness': slabThickness,
    'footprint': footprint?.toJson(),
    'spaces': spaces.map((space) => space.toJson()).toList(growable: false),
    'walls': walls.map((wall) => wall.toJson()).toList(growable: false),
    'openings': openings
        .map((opening) => opening.toJson())
        .toList(growable: false),
  };
}

class ArchitecturalScene3D {
  const ArchitecturalScene3D({
    required this.site,
    required this.dimensions,
    required this.levels,
    required this.roof,
    required this.appearance,
  });

  final Site site;
  final ArchitecturalDimensions dimensions;
  final List<ArchitecturalLevel3D> levels;
  final ArchitecturalRoof3D? roof;
  final ArchitecturalAppearance3D appearance;

  Map<String, Object?> toJson({
    required int selectedFloorIndex,
    String? selectedRoomId,
    Scene3DDisplayMode displayMode = Scene3DDisplayMode.exterior,
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
      'roofOverhang': dimensions.roofOverhang,
    },
    'levels': levels.map((level) => level.toJson()).toList(growable: false),
    'roof': roof?.toJson(),
    'appearance': appearance.toJson(),
    'selection': <String, Object?>{
      'floorIndex': selectedFloorIndex,
      'roomId': selectedRoomId,
    },
    'display': <String, Object>{'mode': displayMode.name},
  };
}

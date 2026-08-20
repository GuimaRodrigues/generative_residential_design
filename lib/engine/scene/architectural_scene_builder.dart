import 'dart:math' as math;

import '../../core/geometry/geometry_utils.dart';
import '../../core/geometry/point_2d.dart';
import '../../core/geometry/rect_2d.dart';
import '../../core/random/deterministic_random.dart';
import '../../domain/building/architectural_scene_3d.dart';
import '../../domain/design/design_candidate.dart';
import '../../domain/requirements/room_type.dart';
import '../../domain/site/site.dart';

class ArchitecturalSceneBuilder {
  const ArchitecturalSceneBuilder({
    this.dimensions = const ArchitecturalDimensions(),
  });

  final ArchitecturalDimensions dimensions;

  ArchitecturalScene3D build({
    required DesignCandidate candidate,
    required Site site,
  }) {
    final appearanceCode = _appearanceCode(candidate);
    final appearance = ArchitecturalAppearance3D(
      exteriorStyle: ArchitecturalExteriorStyle
          .values[appearanceCode % ArchitecturalExteriorStyle.values.length],
      facadeVariant: (appearanceCode >>> 7) % 5,
    );
    final roofRoll = (appearanceCode >>> 3) % 10;
    final roofKind = switch (roofRoll) {
      < 7 => ArchitecturalRoofKind.flat,
      < 9 => ArchitecturalRoofKind.hip,
      _ => ArchitecturalRoofKind.gable,
    };
    final levels = <ArchitecturalLevel3D>[];
    for (final floor in candidate.floors) {
      final spaces = floor.rooms
          .map(
            (room) => ArchitecturalSpace3D(
              id: room.id,
              roomType: room.roomType,
              floorIndex: floor.floorIndex,
              bounds: room.bounds,
            ),
          )
          .toList(growable: false);
      final walls = _buildWalls(floor.floorIndex, spaces);
      levels.add(
        ArchitecturalLevel3D(
          floorIndex: floor.floorIndex,
          elevation: floor.floorIndex * dimensions.floorToFloorHeight,
          slabThickness: dimensions.slabThickness,
          footprint: floor.footprint,
          spaces: List<ArchitecturalSpace3D>.unmodifiable(spaces),
          walls: List<ArchitecturalWall3D>.unmodifiable(walls),
          openings: List<ArchitecturalOpening3D>.unmodifiable(
            _buildOpenings(
              floorIndex: floor.floorIndex,
              footprint: floor.footprint,
              spaces: spaces,
              walls: walls,
              site: site,
              exteriorStyle: appearance.exteriorStyle,
            ),
          ),
        ),
      );
    }
    final immutableLevels = List<ArchitecturalLevel3D>.unmodifiable(levels);
    return ArchitecturalScene3D(
      site: site,
      dimensions: dimensions,
      levels: immutableLevels,
      roof: _buildRoof(immutableLevels, roofKind),
      appearance: appearance,
    );
  }

  int _appearanceCode(DesignCandidate candidate) {
    var value =
        (candidate.seed & 0xffffffff) ^
        DeterministicRandom.multiplyUint32(candidate.attempt + 1, 0x9e3779b9);
    value ^= value >>> 16;
    value = DeterministicRandom.multiplyUint32(value, 0x7feb352d);
    value ^= value >>> 15;
    return value & 0x7fffffff;
  }

  ArchitecturalRoof3D? _buildRoof(
    List<ArchitecturalLevel3D> levels,
    ArchitecturalRoofKind kind,
  ) {
    final occupied = levels.where((level) => level.footprint != null).toList()
      ..sort((first, second) => first.floorIndex.compareTo(second.floorIndex));
    if (occupied.isEmpty) return null;
    final topLevel = occupied.last;
    final footprint = topLevel.footprint!;
    final shorterSpan = math.min(footprint.width, footprint.height);
    return ArchitecturalRoof3D(
      kind: kind,
      footprint: footprint,
      baseElevation: topLevel.elevation + dimensions.wallHeight,
      ridgeHeight: switch (kind) {
        ArchitecturalRoofKind.gable => (shorterSpan * 0.28).clamp(1.1, 2.6),
        ArchitecturalRoofKind.hip => (shorterSpan * 0.24).clamp(0.95, 2.2),
        ArchitecturalRoofKind.flat => 0.24,
      },
      overhang: kind == ArchitecturalRoofKind.flat
          ? 0.3
          : dimensions.roofOverhang,
      ridgeAxis: footprint.width >= footprint.height
          ? RoofRidgeAxis.x
          : RoofRidgeAxis.y,
    );
  }

  List<ArchitecturalWall3D> _buildWalls(
    int floorIndex,
    List<ArchitecturalSpace3D> spaces,
  ) {
    final edges = <_RawEdge>[];
    for (final space in spaces) {
      final bounds = space.bounds;
      edges.addAll(<_RawEdge>[
        _RawEdge.horizontal(bounds.top, bounds.left, bounds.right),
        _RawEdge.horizontal(bounds.bottom, bounds.left, bounds.right),
        _RawEdge.vertical(bounds.left, bounds.top, bounds.bottom),
        _RawEdge.vertical(bounds.right, bounds.top, bounds.bottom),
      ]);
    }

    final groups = <String, List<_RawEdge>>{};
    for (final edge in edges) {
      groups.putIfAbsent(edge.groupKey, () => <_RawEdge>[]).add(edge);
    }
    final walls = <ArchitecturalWall3D>[];
    final sortedKeys = groups.keys.toList(growable: false)..sort();
    for (final key in sortedKeys) {
      final group = groups[key]!;
      final endpoints =
          group
              .expand((edge) => <double>[edge.start, edge.end])
              .toSet()
              .toList(growable: false)
            ..sort();
      final fragments = <_WallFragment>[];
      for (var index = 0; index < endpoints.length - 1; index++) {
        final start = endpoints[index];
        final end = endpoints[index + 1];
        if (approximatelyEqual(start, end)) continue;
        final midpoint = (start + end) / 2;
        final coverage = group.where((edge) {
          return midpoint > edge.start - 1e-6 && midpoint < edge.end + 1e-6;
        }).length;
        if (coverage == 0) continue;
        final kind = coverage == 1 ? WallKind.exterior : WallKind.interior;
        if (fragments.isNotEmpty &&
            fragments.last.kind == kind &&
            approximatelyEqual(fragments.last.end, start)) {
          fragments[fragments.length - 1] = _WallFragment(
            fragments.last.start,
            end,
            kind,
          );
        } else {
          fragments.add(_WallFragment(start, end, kind));
        }
      }
      final sample = group.first;
      for (final fragment in fragments) {
        final start = sample.isHorizontal
            ? Point2D(fragment.start, sample.line)
            : Point2D(sample.line, fragment.start);
        final end = sample.isHorizontal
            ? Point2D(fragment.end, sample.line)
            : Point2D(sample.line, fragment.end);
        final thickness = fragment.kind == WallKind.exterior
            ? dimensions.exteriorWallThickness
            : dimensions.interiorWallThickness;
        walls.add(
          ArchitecturalWall3D(
            id: _wallId(floorIndex, start, end),
            floorIndex: floorIndex,
            start: start,
            end: end,
            kind: fragment.kind,
            thickness: thickness,
            height: dimensions.wallHeight,
          ),
        );
      }
    }
    walls.sort((first, second) => first.id.compareTo(second.id));
    return walls;
  }

  List<ArchitecturalOpening3D> _buildOpenings({
    required int floorIndex,
    required Rect2D? footprint,
    required List<ArchitecturalSpace3D> spaces,
    required List<ArchitecturalWall3D> walls,
    required Site site,
    required ArchitecturalExteriorStyle exteriorStyle,
  }) {
    if (footprint == null) return const <ArchitecturalOpening3D>[];
    final exteriorWalls = walls
        .where((wall) => wall.kind == WallKind.exterior)
        .toList(growable: false);
    final segments = <_FacadeSegment>[];
    for (final space in spaces) {
      for (final wall in exteriorWalls) {
        final segment = _facadeSegment(space, wall, site, footprint);
        if (segment != null) segments.add(segment);
      }
    }
    segments.sort((first, second) {
      final wallOrder = first.wall.id.compareTo(second.wall.id);
      if (wallOrder != 0) return wallOrder;
      final offsetOrder = first.startOffset.compareTo(second.startOffset);
      return offsetOrder != 0
          ? offsetOrder
          : first.space.id.compareTo(second.space.id);
    });

    _FacadeSegment? garageEntry;
    _FacadeSegment? mainEntry;
    if (floorIndex == 0) {
      garageEntry = segments
          .where(
            (segment) =>
                segment.streetFacing &&
                segment.space.roomType == RoomType.garage &&
                segment.length >= 2.4,
          )
          .firstOrNull;
      final entryCandidates =
          segments
              .where(
                (segment) =>
                    segment.streetFacing &&
                    segment.space.roomType != RoomType.garage &&
                    segment.length >= 1.2,
              )
              .toList(growable: false)
            ..sort((first, second) {
              final priority = _entryPriority(first.space.roomType)
                  .compareTo(_entryPriority(second.space.roomType));
              return priority != 0
                  ? priority
                  : first.space.id.compareTo(second.space.id);
            });
      mainEntry = entryCandidates.firstOrNull;
    }

    final openings = <ArchitecturalOpening3D>[];
    void addOpening({
      required _FacadeSegment segment,
      required ArchitecturalOpeningKind kind,
      required double width,
      required double height,
      required double sillHeight,
    }) {
      openings.add(
        ArchitecturalOpening3D(
          id: 'opening-$floorIndex-${kind.name}-${openings.length + 1}',
          wallId: segment.wall.id,
          floorIndex: floorIndex,
          roomType: segment.space.roomType,
          kind: kind,
          centerOffset: (segment.startOffset + segment.endOffset) / 2,
          width: width,
          height: height,
          sillHeight: sillHeight,
        ),
      );
    }

    if (garageEntry case final segment?) {
      addOpening(
        segment: segment,
        kind: ArchitecturalOpeningKind.garageDoor,
        width: math.min(2.8, segment.length - 0.35),
        height: 2.25,
        sillHeight: 0,
      );
    }
    if (mainEntry case final segment?) {
      addOpening(
        segment: segment,
        kind: ArchitecturalOpeningKind.door,
        width: math.min(1.05, segment.length - 0.3),
        height: 2.18,
        sillHeight: 0,
      );
    }

    for (final segment in segments) {
      if (identical(segment, garageEntry) || identical(segment, mainEntry)) {
        continue;
      }
      final availableWidth = segment.length - 0.45;
      if (availableWidth < 0.6) continue;
      final wetRoom = switch (segment.space.roomType) {
        RoomType.bathroom || RoomType.toilet || RoomType.laundry => true,
        _ => false,
      };
      final socialRoom = switch (segment.space.roomType) {
        RoomType.livingRoom || RoomType.diningRoom || RoomType.kitchen => true,
        _ => false,
      };
      final baseWidthFactor = switch (exteriorStyle) {
        ArchitecturalExteriorStyle.lightMinimal => 0.52,
        ArchitecturalExteriorStyle.warmModern => 0.44,
        ArchitecturalExteriorStyle.graphiteModern => 0.36,
        ArchitecturalExteriorStyle.coastalModern => 0.48,
      };
      final widthFactor = baseWidthFactor + (socialRoom ? 0.16 : 0);
      final regularHeight = switch (exteriorStyle) {
        ArchitecturalExteriorStyle.lightMinimal => socialRoom ? 1.82 : 1.42,
        ArchitecturalExteriorStyle.warmModern => socialRoom ? 1.7 : 1.34,
        ArchitecturalExteriorStyle.graphiteModern => socialRoom ? 1.92 : 1.56,
        ArchitecturalExteriorStyle.coastalModern => socialRoom ? 1.76 : 1.38,
      };
      final regularSill = switch (exteriorStyle) {
        ArchitecturalExteriorStyle.lightMinimal => socialRoom ? 0.32 : 0.72,
        ArchitecturalExteriorStyle.warmModern => socialRoom ? 0.38 : 0.78,
        ArchitecturalExteriorStyle.graphiteModern => socialRoom ? 0.24 : 0.58,
        ArchitecturalExteriorStyle.coastalModern => socialRoom ? 0.34 : 0.76,
      };
      final windowWidth = wetRoom
          ? math.min(0.75, availableWidth)
          : math.min(
              (segment.length * widthFactor).clamp(
                0.82,
                socialRoom ? 3.4 : 2.4,
              ),
              availableWidth,
            );
      addOpening(
        segment: segment,
        kind: ArchitecturalOpeningKind.window,
        width: windowWidth,
        height: wetRoom ? 0.65 : regularHeight,
        sillHeight: wetRoom ? 1.5 : regularSill,
      );
    }
    return openings;
  }

  _FacadeSegment? _facadeSegment(
    ArchitecturalSpace3D space,
    ArchitecturalWall3D wall,
    Site site,
    Rect2D footprint,
  ) {
    final bounds = space.bounds;
    double? start;
    double? end;
    if (wall.isHorizontal &&
        (approximatelyEqual(bounds.top, wall.start.y) ||
            approximatelyEqual(bounds.bottom, wall.start.y))) {
      start = math.max(bounds.left, wall.start.x);
      end = math.min(bounds.right, wall.end.x);
    } else if (!wall.isHorizontal &&
        (approximatelyEqual(bounds.left, wall.start.x) ||
            approximatelyEqual(bounds.right, wall.start.x))) {
      start = math.max(bounds.top, wall.start.y);
      end = math.min(bounds.bottom, wall.end.y);
    }
    if (start == null || end == null || end - start < 0.5) return null;
    final wallStart = wall.isHorizontal ? wall.start.x : wall.start.y;
    return _FacadeSegment(
      space: space,
      wall: wall,
      startOffset: start - wallStart,
      endOffset: end - wallStart,
      streetFacing: _isStreetFacing(wall, site, footprint),
    );
  }

  bool _isStreetFacing(
    ArchitecturalWall3D wall,
    Site site,
    Rect2D footprint,
  ) => switch (site.streetSide) {
    StreetSide.north =>
      wall.isHorizontal && approximatelyEqual(wall.start.y, footprint.top),
    StreetSide.south =>
      wall.isHorizontal && approximatelyEqual(wall.start.y, footprint.bottom),
    StreetSide.east =>
      !wall.isHorizontal && approximatelyEqual(wall.start.x, footprint.right),
    StreetSide.west =>
      !wall.isHorizontal && approximatelyEqual(wall.start.x, footprint.left),
  };

  int _entryPriority(RoomType type) => switch (type) {
    RoomType.livingRoom => 0,
    RoomType.hallway => 1,
    RoomType.stairs => 2,
    RoomType.diningRoom => 3,
    RoomType.office => 4,
    RoomType.kitchen => 5,
    RoomType.bedroom || RoomType.masterBedroom => 6,
    RoomType.closet => 7,
    RoomType.bathroom || RoomType.toilet || RoomType.laundry => 8,
    RoomType.garage => 9,
  };

  String _wallId(int floorIndex, Point2D start, Point2D end) =>
      'wall-$floorIndex-${start.x.toStringAsFixed(2)}-'
      '${start.y.toStringAsFixed(2)}-${end.x.toStringAsFixed(2)}-'
      '${end.y.toStringAsFixed(2)}';
}

class _RawEdge {
  const _RawEdge._({
    required this.isHorizontal,
    required this.line,
    required this.start,
    required this.end,
  });

  factory _RawEdge.horizontal(double line, double start, double end) =>
      _RawEdge._(isHorizontal: true, line: line, start: start, end: end);

  factory _RawEdge.vertical(double line, double start, double end) =>
      _RawEdge._(isHorizontal: false, line: line, start: start, end: end);

  final bool isHorizontal;
  final double line;
  final double start;
  final double end;

  String get groupKey =>
      '${isHorizontal ? 'h' : 'v'}-${line.toStringAsFixed(6)}';
}

class _WallFragment {
  const _WallFragment(this.start, this.end, this.kind);
  final double start;
  final double end;
  final WallKind kind;
}

class _FacadeSegment {
  const _FacadeSegment({
    required this.space,
    required this.wall,
    required this.startOffset,
    required this.endOffset,
    required this.streetFacing,
  });

  final ArchitecturalSpace3D space;
  final ArchitecturalWall3D wall;
  final double startOffset;
  final double endOffset;
  final bool streetFacing;

  double get length => endOffset - startOffset;
}

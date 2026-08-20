import '../../core/geometry/geometry_utils.dart';
import '../../core/geometry/point_2d.dart';
import '../../domain/building/architectural_scene_3d.dart';
import '../../domain/design/design_candidate.dart';
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
    final levels = candidate.floors
        .map((floor) {
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
          return ArchitecturalLevel3D(
            floorIndex: floor.floorIndex,
            elevation: floor.floorIndex * dimensions.floorToFloorHeight,
            slabThickness: dimensions.slabThickness,
            footprint: floor.footprint,
            spaces: List<ArchitecturalSpace3D>.unmodifiable(spaces),
            walls: List<ArchitecturalWall3D>.unmodifiable(
              _buildWalls(floor.floorIndex, spaces),
            ),
          );
        })
        .toList(growable: false);
    return ArchitecturalScene3D(
      site: site,
      dimensions: dimensions,
      levels: List<ArchitecturalLevel3D>.unmodifiable(levels),
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

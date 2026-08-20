import 'dart:math' as math;

import '../../core/geometry/geometry_utils.dart';
import '../../core/geometry/rect_2d.dart';
import '../../core/random/deterministic_random.dart';
import '../../domain/design/generated_room.dart';
import '../../domain/requirements/room_requirement.dart';
import 'slicing_tree.dart';

class PartitionOutcome {
  const PartitionOutcome({required this.tree, required this.rooms});
  final SlicingTree tree;
  final List<GeneratedRoom> rooms;
}

class PartitionGenerator {
  const PartitionGenerator({
    this.gridSize = defaultGridSize,
    this.retriesPerNode = 14,
  });

  final double gridSize;
  final int retriesPerNode;

  PartitionOutcome? generate({
    required List<RoomInstance> rooms,
    required Rect2D footprint,
    required int floorIndex,
    required DeterministicRandom random,
  }) {
    if (rooms.isEmpty) return null;
    final shuffled = List<RoomInstance>.of(rooms);
    random.shuffle(shuffled);
    final result = _partition(shuffled, footprint, floorIndex, random);
    if (result == null) return null;
    return PartitionOutcome(
      tree: SlicingTree(result.node),
      rooms: result.rooms,
    );
  }

  _PartitionResult? _partition(
    List<RoomInstance> rooms,
    Rect2D bounds,
    int floorIndex,
    DeterministicRandom random,
  ) {
    if (rooms.length == 1) {
      final room = rooms.single;
      if (!_roomFits(room, bounds)) return null;
      return _PartitionResult(RoomLeaf(room), <GeneratedRoom>[
        GeneratedRoom(source: room, floorIndex: floorIndex, bounds: bounds),
      ]);
    }

    final attempts = math.min(retriesPerNode, 6 + rooms.length * 2);
    for (var attempt = 0; attempt < attempts; attempt++) {
      final ordered = List<RoomInstance>.of(rooms);
      if (attempt > 0) random.shuffle(ordered);
      final splitIndex = rooms.length == 2
          ? 1
          : 1 + random.nextInt(rooms.length - 1);
      final firstRooms = ordered.sublist(0, splitIndex);
      final secondRooms = ordered.sublist(splitIndex);
      final firstArea = firstRooms.fold<double>(
        0,
        (sum, room) => sum + room.targetArea,
      );
      final secondArea = secondRooms.fold<double>(
        0,
        (sum, room) => sum + room.targetArea,
      );
      final idealRatio = firstArea / (firstArea + secondArea);
      final ratio = (idealRatio + random.between(-0.07, 0.07)).clamp(
        0.12,
        0.88,
      );

      final preferVertical =
          bounds.width / bounds.height > random.between(0.82, 1.22);
      final orientation = (attempt.isOdd ? !preferVertical : preferVertical)
          ? SplitOrientation.vertical
          : SplitOrientation.horizontal;
      final split = _split(bounds, orientation, ratio);
      if (split == null) continue;

      final first = _partition(firstRooms, split.$1, floorIndex, random);
      if (first == null) continue;
      final second = _partition(secondRooms, split.$2, floorIndex, random);
      if (second == null) continue;

      return _PartitionResult(
        SplitNode(
          orientation: orientation,
          ratio: split.$3,
          first: first.node,
          second: second.node,
        ),
        <GeneratedRoom>[...first.rooms, ...second.rooms],
      );
    }
    return null;
  }

  (Rect2D, Rect2D, double)? _split(
    Rect2D bounds,
    SplitOrientation orientation,
    double ratio,
  ) {
    if (orientation == SplitOrientation.vertical) {
      final firstWidth = snapToGrid(bounds.width * ratio, grid: gridSize);
      if (firstWidth < gridSize || bounds.width - firstWidth < gridSize) {
        return null;
      }
      return (
        Rect2D(
          x: bounds.x,
          y: bounds.y,
          width: firstWidth,
          height: bounds.height,
        ),
        Rect2D(
          x: bounds.x + firstWidth,
          y: bounds.y,
          width: bounds.width - firstWidth,
          height: bounds.height,
        ),
        firstWidth / bounds.width,
      );
    }
    final firstHeight = snapToGrid(bounds.height * ratio, grid: gridSize);
    if (firstHeight < gridSize || bounds.height - firstHeight < gridSize) {
      return null;
    }
    return (
      Rect2D(
        x: bounds.x,
        y: bounds.y,
        width: bounds.width,
        height: firstHeight,
      ),
      Rect2D(
        x: bounds.x,
        y: bounds.y + firstHeight,
        width: bounds.width,
        height: bounds.height - firstHeight,
      ),
      firstHeight / bounds.height,
    );
  }

  bool _roomFits(RoomInstance room, Rect2D bounds) {
    if (bounds.area + 1e-6 < room.minArea) return false;
    final roomShort = math.min(room.minWidth, room.minDepth);
    final roomLong = math.max(room.minWidth, room.minDepth);
    final actualShort = math.min(bounds.width, bounds.height);
    final actualLong = math.max(bounds.width, bounds.height);
    return actualShort + 1e-6 >= roomShort && actualLong + 1e-6 >= roomLong;
  }
}

class _PartitionResult {
  const _PartitionResult(this.node, this.rooms);
  final SlicingNode node;
  final List<GeneratedRoom> rooms;
}

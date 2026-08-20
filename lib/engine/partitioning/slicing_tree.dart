import '../../domain/requirements/room_requirement.dart';

enum SplitOrientation { horizontal, vertical }

sealed class SlicingNode {
  const SlicingNode();

  double get targetArea;
}

class RoomLeaf extends SlicingNode {
  const RoomLeaf(this.room);
  final RoomInstance room;

  @override
  double get targetArea => room.targetArea;
}

class SplitNode extends SlicingNode {
  const SplitNode({
    required this.orientation,
    required this.ratio,
    required this.first,
    required this.second,
  });

  final SplitOrientation orientation;
  final double ratio;
  final SlicingNode first;
  final SlicingNode second;

  @override
  double get targetArea => first.targetArea + second.targetArea;
}

class SlicingTree {
  const SlicingTree(this.root);
  final SlicingNode root;
}

import '../../core/geometry/rect_2d.dart';
import 'generated_room.dart';

class FloorPlan {
  const FloorPlan({
    required this.floorIndex,
    required this.footprint,
    required this.rooms,
  });

  final int floorIndex;
  final Rect2D? footprint;
  final List<GeneratedRoom> rooms;
}

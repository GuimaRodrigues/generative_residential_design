import '../../core/geometry/rect_2d.dart';
import '../requirements/room_requirement.dart';
import '../requirements/room_type.dart';

class GeneratedRoom {
  const GeneratedRoom({
    required this.source,
    required this.floorIndex,
    required this.bounds,
  });

  final RoomInstance source;
  final int floorIndex;
  final Rect2D bounds;

  String get id => source.id;
  RoomType get roomType => source.roomType;
  double get area => bounds.area;
}

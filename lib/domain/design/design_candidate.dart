import 'floor_plan.dart';
import 'generated_room.dart';
import 'score_breakdown.dart';

class DesignCandidate {
  const DesignCandidate({
    required this.id,
    required this.seed,
    required this.attempt,
    required this.floors,
    required this.score,
    required this.warnings,
  });

  final String id;
  final int seed;
  final int attempt;
  final List<FloorPlan> floors;
  final ScoreBreakdown score;
  final List<String> warnings;

  Iterable<GeneratedRoom> get rooms => floors.expand((floor) => floor.rooms);
  double get totalArea => rooms.fold(0, (total, room) => total + room.area);

  String get geometrySignature {
    final parts = rooms.toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    return parts
        .map((room) {
          final rect = room.bounds;
          return '${room.id}:${room.floorIndex}:${rect.x.toStringAsFixed(2)},'
              '${rect.y.toStringAsFixed(2)},${rect.width.toStringAsFixed(2)},'
              '${rect.height.toStringAsFixed(2)}';
        })
        .join('|');
  }
}

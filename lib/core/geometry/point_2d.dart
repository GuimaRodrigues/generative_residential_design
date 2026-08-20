import 'dart:math' as math;

class Point2D {
  const Point2D(this.x, this.y);

  final double x;
  final double y;

  double distanceTo(Point2D other) =>
      math.sqrt(math.pow(x - other.x, 2) + math.pow(y - other.y, 2));

  Map<String, Object> toJson() => <String, Object>{'x': x, 'y': y};

  @override
  bool operator ==(Object other) =>
      other is Point2D && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

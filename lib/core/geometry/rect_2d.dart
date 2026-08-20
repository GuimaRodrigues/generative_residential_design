import 'dart:math' as math;

import 'point_2d.dart';

class Rect2D {
  const Rect2D({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory Rect2D.fromJson(Map<String, Object?> json) => Rect2D(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
  );

  final double x;
  final double y;
  final double width;
  final double height;

  double get left => x;
  double get top => y;
  double get right => x + width;
  double get bottom => y + height;
  double get area => width * height;
  double get aspectRatio {
    final shorter = math.min(width, height);
    return shorter <= 0 ? double.infinity : math.max(width, height) / shorter;
  }

  Point2D get center => Point2D(x + width / 2, y + height / 2);
  bool get isValid =>
      x.isFinite &&
      y.isFinite &&
      width.isFinite &&
      height.isFinite &&
      width > 0 &&
      height > 0;

  bool containsPoint(Point2D point, {double tolerance = 1e-9}) =>
      point.x >= left - tolerance &&
      point.x <= right + tolerance &&
      point.y >= top - tolerance &&
      point.y <= bottom + tolerance;

  bool containsRect(Rect2D other, {double tolerance = 1e-9}) =>
      other.left >= left - tolerance &&
      other.right <= right + tolerance &&
      other.top >= top - tolerance &&
      other.bottom <= bottom + tolerance;

  bool intersects(Rect2D other, {double tolerance = 1e-9}) =>
      math.min(right, other.right) - math.max(left, other.left) > tolerance &&
      math.min(bottom, other.bottom) - math.max(top, other.top) > tolerance;

  Rect2D? intersection(Rect2D other, {double tolerance = 1e-9}) {
    final intersectionLeft = math.max(left, other.left);
    final intersectionTop = math.max(top, other.top);
    final intersectionRight = math.min(right, other.right);
    final intersectionBottom = math.min(bottom, other.bottom);
    if (intersectionRight - intersectionLeft <= tolerance ||
        intersectionBottom - intersectionTop <= tolerance) {
      return null;
    }
    return Rect2D(
      x: intersectionLeft,
      y: intersectionTop,
      width: intersectionRight - intersectionLeft,
      height: intersectionBottom - intersectionTop,
    );
  }

  double sharedBoundaryLength(Rect2D other, {double tolerance = 1e-6}) {
    final touchesVertically =
        (right - other.left).abs() <= tolerance ||
        (other.right - left).abs() <= tolerance;
    if (touchesVertically) {
      return math.max(
        0,
        math.min(bottom, other.bottom) - math.max(top, other.top),
      );
    }
    final touchesHorizontally =
        (bottom - other.top).abs() <= tolerance ||
        (other.bottom - top).abs() <= tolerance;
    if (touchesHorizontally) {
      return math.max(
        0,
        math.min(right, other.right) - math.max(left, other.left),
      );
    }
    return 0;
  }

  bool isAdjacentTo(Rect2D other, {double minimumSharedBoundary = 0.5}) =>
      sharedBoundaryLength(other) >= minimumSharedBoundary;

  Map<String, Object> toJson() => <String, Object>{
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  @override
  bool operator ==(Object other) =>
      other is Rect2D &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'Rect2D($x, $y, $width, $height)';
}

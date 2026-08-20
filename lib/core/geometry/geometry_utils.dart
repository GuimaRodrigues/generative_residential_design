import 'dart:math' as math;

import 'point_2d.dart';
import 'rect_2d.dart';

const double defaultGridSize = 0.25;

double snapToGrid(double value, {double grid = defaultGridSize}) =>
    (value / grid).round() * grid;

double floorToGrid(double value, {double grid = defaultGridSize}) =>
    (value / grid).floor() * grid;

double ceilToGrid(double value, {double grid = defaultGridSize}) =>
    (value / grid).ceil() * grid;

bool isGridAligned(double value, {double grid = defaultGridSize}) =>
    approximatelyEqual(value / grid, (value / grid).roundToDouble());

bool approximatelyEqual(double a, double b, {double tolerance = 1e-6}) =>
    (a - b).abs() <= tolerance;

double normalizedDistance(Point2D a, Point2D b, Rect2D bounds) {
  final diagonal = math.sqrt(
    bounds.width * bounds.width + bounds.height * bounds.height,
  );
  return diagonal <= 0 ? 0 : (a.distanceTo(b) / diagonal).clamp(0, 1);
}

Rect2D boundsOf(Iterable<Rect2D> rectangles) {
  final items = rectangles.toList(growable: false);
  if (items.isEmpty) {
    throw ArgumentError.value(
      rectangles,
      'rectangles',
      'Cannot calculate empty bounds.',
    );
  }
  final left = items.map((rect) => rect.left).reduce(math.min);
  final top = items.map((rect) => rect.top).reduce(math.min);
  final right = items.map((rect) => rect.right).reduce(math.max);
  final bottom = items.map((rect) => rect.bottom).reduce(math.max);
  return Rect2D(x: left, y: top, width: right - left, height: bottom - top);
}

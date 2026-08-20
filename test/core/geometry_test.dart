import 'package:flutter_test/flutter_test.dart';
import 'package:generative_residential_design/core/geometry/geometry_utils.dart';
import 'package:generative_residential_design/core/geometry/point_2d.dart';
import 'package:generative_residential_design/core/geometry/rect_2d.dart';

void main() {
  group('Rect2D', () {
    const first = Rect2D(x: 0, y: 0, width: 4, height: 3);

    test('calculates area and containment', () {
      expect(first.area, 12);
      expect(first.containsPoint(const Point2D(2, 2)), isTrue);
      expect(
        first.containsRect(const Rect2D(x: 1, y: 1, width: 2, height: 1)),
        isTrue,
      );
    });

    test(
      'calculates intersection without treating edge contact as overlap',
      () {
        const overlapping = Rect2D(x: 3, y: 2, width: 2, height: 2);
        const touching = Rect2D(x: 4, y: 0, width: 2, height: 3);
        expect(first.intersection(overlapping)?.area, 1);
        expect(first.intersects(touching), isFalse);
      },
    );

    test('detects meaningful adjacency and rejects corner contact', () {
      const adjacent = Rect2D(x: 4, y: 1, width: 3, height: 2);
      const corner = Rect2D(x: 4, y: 3, width: 2, height: 2);
      expect(first.sharedBoundaryLength(adjacent), 2);
      expect(first.isAdjacentTo(adjacent), isTrue);
      expect(first.sharedBoundaryLength(corner), 0);
      expect(first.isAdjacentTo(corner), isFalse);
    });
  });

  test('grid and distance utilities are stable', () {
    expect(snapToGrid(1.13), 1.25);
    expect(floorToGrid(1.24), 1);
    expect(ceilToGrid(1.01), 1.25);
    expect(isGridAligned(2.75), isTrue);
    expect(const Point2D(0, 0).distanceTo(const Point2D(3, 4)), 5);
  });
}

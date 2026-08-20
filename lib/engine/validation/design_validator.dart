import 'dart:math' as math;

import '../../core/geometry/geometry_utils.dart';
import '../../domain/constraints/constraint.dart';
import '../../domain/design/design_candidate.dart';
import '../../domain/requirements/design_requirements.dart';
import '../../domain/requirements/room_requirement.dart';

class DesignValidator {
  const DesignValidator({this.gridSize = defaultGridSize});
  final double gridSize;

  List<ConstraintViolation> validate(
    DesignCandidate candidate,
    DesignRequirements requirements,
  ) {
    final violations = <ConstraintViolation>[];
    void add(HardConstraintType type, String message) => violations.add(
      ConstraintViolation(
        constraint: HardConstraint(
          id: type.name,
          description: message,
          type: type,
        ),
        message: message,
      ),
    );

    final expected = requirements.normalizeRooms();
    final actual = candidate.rooms.toList(growable: false);
    final expectedIds = expected.map((room) => room.id).toSet();
    final actualIds = actual.map((room) => room.id).toSet();
    if (actualIds.length != actual.length ||
        expectedIds.length != actualIds.length ||
        !actualIds.containsAll(expectedIds)) {
      add(
        HardConstraintType.requiredRoomCount,
        'The generated room count does not match the requirements.',
      );
    }

    if (candidate.floors.length != requirements.floorCount ||
        candidate.floors.any(
          (floor) =>
              floor.floorIndex < 0 ||
              floor.floorIndex >= requirements.floorCount,
        )) {
      add(
        HardConstraintType.supportedFloorCount,
        'The generated floors do not match the requested floor count.',
      );
    }

    final envelope = requirements.site.buildableEnvelope;
    for (final room in actual) {
      if (!room.bounds.isValid) {
        add(
          HardConstraintType.validGeometry,
          '${room.id} has invalid geometry.',
        );
      }
      if (!envelope.containsRect(room.bounds)) {
        add(
          HardConstraintType.insideEnvelope,
          '${room.id} leaves the buildable envelope.',
        );
      }
      if (room.area + 1e-6 < room.source.minArea) {
        add(
          HardConstraintType.minimumArea,
          '${room.id} is below its minimum area.',
        );
      }
      final requiredShort = math.min(
        room.source.minWidth,
        room.source.minDepth,
      );
      final requiredLong = math.max(room.source.minWidth, room.source.minDepth);
      final actualShort = math.min(room.bounds.width, room.bounds.height);
      final actualLong = math.max(room.bounds.width, room.bounds.height);
      if (actualShort + 1e-6 < requiredShort ||
          actualLong + 1e-6 < requiredLong) {
        add(
          HardConstraintType.minimumDimensions,
          '${room.id} is below its minimum dimensions.',
        );
      }
      if (<double>[
        room.bounds.x,
        room.bounds.y,
        room.bounds.width,
        room.bounds.height,
      ].any((value) => !isGridAligned(value, grid: gridSize))) {
        add(
          HardConstraintType.gridAlignment,
          '${room.id} is not aligned to the ${gridSize}m grid.',
        );
      }
      final preferred = room.source.preferredFloor;
      if ((preferred == PreferredFloor.ground && room.floorIndex != 0) ||
          (preferred == PreferredFloor.upper && room.floorIndex != 1)) {
        add(
          HardConstraintType.floorAssignment,
          '${room.id} violates its locked floor assignment.',
        );
      }
    }

    for (final floor in candidate.floors) {
      for (var first = 0; first < floor.rooms.length; first++) {
        for (var second = first + 1; second < floor.rooms.length; second++) {
          if (floor.rooms[first].bounds.intersects(
            floor.rooms[second].bounds,
          )) {
            add(
              HardConstraintType.noOverlap,
              '${floor.rooms[first].id} overlaps ${floor.rooms[second].id}.',
            );
          }
        }
      }
    }
    if (requirements.maximumTotalArea case final maximum?) {
      if (candidate.totalArea > maximum + 1e-6) {
        add(
          HardConstraintType.maximumTotalArea,
          'The design exceeds the maximum total area.',
        );
      }
    }
    return violations;
  }
}

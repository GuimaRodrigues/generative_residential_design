import 'dart:math' as math;

import '../../domain/requirements/design_requirements.dart';
import '../../domain/requirements/room_requirement.dart';
import '../../domain/requirements/room_type.dart';

class PreflightValidator {
  const PreflightValidator();

  List<String> validate(DesignRequirements requirements) {
    final errors = <String>[...requirements.site.validate()];
    if (requirements.floorCount != 1 && requirements.floorCount != 2) {
      errors.add('Only one or two floors are supported.');
    }
    if (requirements.rooms.isEmpty ||
        requirements.rooms.every((room) => room.count <= 0)) {
      errors.add('Add at least one required room.');
    }
    for (final room in requirements.rooms) {
      if (room.count < 1) {
        errors.add(
          '${room.roomType.displayName} must have a count of at least one.',
        );
      }
      if (room.effectiveMinArea <= 0 ||
          room.effectiveMinWidth <= 0 ||
          room.effectiveMinDepth <= 0) {
        errors.add(
          '${room.roomType.displayName} has invalid minimum dimensions.',
        );
      }
      if (requirements.floorCount == 1 &&
          room.preferredFloor == PreferredFloor.upper) {
        errors.add(
          '${room.roomType.displayName} is locked to an unavailable upper floor.',
        );
      }
      if (room.roomType == RoomType.garage &&
          room.preferredFloor == PreferredFloor.upper) {
        errors.add('Garage must be assigned to the ground floor.');
      }
    }
    if (errors.isNotEmpty) return errors;

    final envelope = requirements.site.buildableEnvelope;
    final instances = requirements.normalizeRooms();
    final minimumArea = instances.fold<double>(
      0,
      (sum, room) => sum + room.minArea,
    );
    final capacity = envelope.area * requirements.floorCount;
    final effectiveCapacity = requirements.maximumTotalArea == null
        ? capacity
        : math.min(capacity, requirements.maximumTotalArea!);
    if (minimumArea > effectiveCapacity + 1e-6) {
      errors.add(
        'The requested minimum room area is ${minimumArea.toStringAsFixed(1)} m², '
        'but the available floor area is approximately ${effectiveCapacity.toStringAsFixed(1)} m².',
      );
    }

    for (var floor = 0; floor < requirements.floorCount; floor++) {
      final locked = instances.where((room) {
        return floor == 0
            ? room.preferredFloor == PreferredFloor.ground
            : room.preferredFloor == PreferredFloor.upper;
      });
      final lockedArea = locked.fold<double>(
        0,
        (sum, room) => sum + room.minArea,
      );
      if (lockedArea > envelope.area + 1e-6) {
        errors.add(
          'Rooms locked to floor ${floor + 1} exceed its buildable area.',
        );
      }
    }
    for (final room in instances) {
      final shortSide = math.min(room.minWidth, room.minDepth);
      final longSide = math.max(room.minWidth, room.minDepth);
      final envelopeShort = math.min(envelope.width, envelope.height);
      final envelopeLong = math.max(envelope.width, envelope.height);
      if (shortSide > envelopeShort + 1e-6 || longSide > envelopeLong + 1e-6) {
        errors.add(
          '${room.roomType.displayName} cannot fit inside the buildable envelope.',
        );
      }
    }
    if (requirements.maximumTotalArea != null &&
        requirements.maximumTotalArea! <= 0) {
      errors.add('Maximum total area must be positive when provided.');
    }
    return errors;
  }
}

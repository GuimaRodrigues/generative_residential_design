import '../requirements/spatial_relationship.dart';

sealed class DesignConstraint {
  const DesignConstraint({required this.id, required this.description});

  final String id;
  final String description;
}

enum HardConstraintType {
  requiredRoomCount,
  insideEnvelope,
  noOverlap,
  minimumArea,
  minimumDimensions,
  floorAssignment,
  validGeometry,
  supportedFloorCount,
  gridAlignment,
  maximumTotalArea,
}

class HardConstraint extends DesignConstraint {
  const HardConstraint({
    required super.id,
    required super.description,
    required this.type,
  });
  final HardConstraintType type;
}

class SoftConstraint extends DesignConstraint {
  const SoftConstraint({
    required super.id,
    required super.description,
    required this.relationship,
  });
  final SpatialRelationship relationship;
}

class ConstraintViolation {
  const ConstraintViolation({required this.constraint, required this.message});
  final HardConstraint constraint;
  final String message;
}

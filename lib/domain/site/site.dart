import '../../core/geometry/rect_2d.dart';

enum StreetSide { north, south, east, west }

class Site {
  const Site({
    required this.width,
    required this.depth,
    required this.streetSide,
    required this.frontSetback,
    required this.rearSetback,
    required this.leftSetback,
    required this.rightSetback,
  });

  factory Site.fromJson(Map<String, Object?> json) => Site(
    width: (json['width'] as num).toDouble(),
    depth: (json['depth'] as num).toDouble(),
    streetSide: StreetSide.values.byName(json['streetSide'] as String),
    frontSetback: (json['frontSetback'] as num).toDouble(),
    rearSetback: (json['rearSetback'] as num).toDouble(),
    leftSetback: (json['leftSetback'] as num).toDouble(),
    rightSetback: (json['rightSetback'] as num).toDouble(),
  );

  final double width;
  final double depth;
  final StreetSide streetSide;
  final double frontSetback;
  final double rearSetback;
  final double leftSetback;
  final double rightSetback;

  Rect2D get lotBounds => Rect2D(x: 0, y: 0, width: width, height: depth);

  /// Left/right setbacks are interpreted from the street while facing into
  /// the site. Coordinates increase eastward (x) and southward (y).
  Rect2D get buildableEnvelope {
    final (west, east, north, south) = switch (streetSide) {
      StreetSide.south => (
        leftSetback,
        rightSetback,
        rearSetback,
        frontSetback,
      ),
      StreetSide.north => (
        rightSetback,
        leftSetback,
        frontSetback,
        rearSetback,
      ),
      StreetSide.east => (rearSetback, frontSetback, leftSetback, rightSetback),
      StreetSide.west => (frontSetback, rearSetback, rightSetback, leftSetback),
    };
    return Rect2D(
      x: west,
      y: north,
      width: width - west - east,
      height: depth - north - south,
    );
  }

  List<String> validate() {
    final errors = <String>[];
    if (!width.isFinite || width <= 0) {
      errors.add('Lot width must be positive.');
    }
    if (!depth.isFinite || depth <= 0) {
      errors.add('Lot depth must be positive.');
    }
    if (<double>[
      frontSetback,
      rearSetback,
      leftSetback,
      rightSetback,
    ].any((setback) => !setback.isFinite || setback < 0)) {
      errors.add('Setbacks must be finite, non-negative values.');
    }
    if (errors.isEmpty && !buildableEnvelope.isValid) {
      errors.add(
        'The setbacks consume the entire lot; no buildable envelope remains.',
      );
    }
    return errors;
  }

  Site copyWith({
    double? width,
    double? depth,
    StreetSide? streetSide,
    double? frontSetback,
    double? rearSetback,
    double? leftSetback,
    double? rightSetback,
  }) => Site(
    width: width ?? this.width,
    depth: depth ?? this.depth,
    streetSide: streetSide ?? this.streetSide,
    frontSetback: frontSetback ?? this.frontSetback,
    rearSetback: rearSetback ?? this.rearSetback,
    leftSetback: leftSetback ?? this.leftSetback,
    rightSetback: rightSetback ?? this.rightSetback,
  );

  Map<String, Object> toJson() => <String, Object>{
    'width': width,
    'depth': depth,
    'streetSide': streetSide.name,
    'frontSetback': frontSetback,
    'rearSetback': rearSetback,
    'leftSetback': leftSetback,
    'rightSetback': rightSetback,
  };
}

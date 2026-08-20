import 'room_type.dart';

enum PreferredFloor { any, ground, upper }

class RoomRequirement {
  const RoomRequirement({
    required this.id,
    required this.roomType,
    this.count = 1,
    this.preferredFloor = PreferredFloor.any,
    this.targetArea,
    this.minArea,
    this.minWidth,
    this.minDepth,
  });

  factory RoomRequirement.fromJson(Map<String, Object?> json) =>
      RoomRequirement(
        id: json['id'] as String,
        roomType: RoomType.values.byName(json['roomType'] as String),
        count: json['count'] as int,
        preferredFloor: PreferredFloor.values.byName(
          json['preferredFloor'] as String,
        ),
        targetArea: (json['targetArea'] as num?)?.toDouble(),
        minArea: (json['minArea'] as num?)?.toDouble(),
        minWidth: (json['minWidth'] as num?)?.toDouble(),
        minDepth: (json['minDepth'] as num?)?.toDouble(),
      );

  final String id;
  final RoomType roomType;
  final int count;
  final PreferredFloor preferredFloor;
  final double? targetArea;
  final double? minArea;
  final double? minWidth;
  final double? minDepth;

  double get effectiveTargetArea => targetArea ?? roomType.metadata.targetArea;
  double get effectiveMinArea => minArea ?? roomType.metadata.minimumArea;
  double get effectiveMinWidth => minWidth ?? roomType.metadata.minimumWidth;
  double get effectiveMinDepth => minDepth ?? roomType.metadata.minimumDepth;

  RoomRequirement copyWith({
    String? id,
    RoomType? roomType,
    int? count,
    PreferredFloor? preferredFloor,
    double? targetArea,
    double? minArea,
    double? minWidth,
    double? minDepth,
  }) => RoomRequirement(
    id: id ?? this.id,
    roomType: roomType ?? this.roomType,
    count: count ?? this.count,
    preferredFloor: preferredFloor ?? this.preferredFloor,
    targetArea: targetArea ?? this.targetArea,
    minArea: minArea ?? this.minArea,
    minWidth: minWidth ?? this.minWidth,
    minDepth: minDepth ?? this.minDepth,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'roomType': roomType.name,
    'count': count,
    'preferredFloor': preferredFloor.name,
    'targetArea': targetArea,
    'minArea': minArea,
    'minWidth': minWidth,
    'minDepth': minDepth,
  };
}

class RoomInstance {
  const RoomInstance({
    required this.id,
    required this.requirementId,
    required this.roomType,
    required this.preferredFloor,
    required this.targetArea,
    required this.minArea,
    required this.minWidth,
    required this.minDepth,
  });

  final String id;
  final String requirementId;
  final RoomType roomType;
  final PreferredFloor preferredFloor;
  final double targetArea;
  final double minArea;
  final double minWidth;
  final double minDepth;
}

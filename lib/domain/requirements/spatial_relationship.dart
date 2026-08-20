import 'room_type.dart';

enum SpatialRelationshipType {
  adjacentTo,
  near,
  awayFrom,
  sameFloor,
  differentFloor,
}

enum SiteZone { street }

class RelationshipTarget {
  const RelationshipTarget.room(this.roomType) : siteZone = null;
  const RelationshipTarget.site(this.siteZone) : roomType = null;

  factory RelationshipTarget.fromJson(Map<String, Object?> json) {
    final roomName = json['roomType'] as String?;
    if (roomName != null) {
      return RelationshipTarget.room(RoomType.values.byName(roomName));
    }
    return RelationshipTarget.site(
      SiteZone.values.byName(json['siteZone'] as String),
    );
  }

  final RoomType? roomType;
  final SiteZone? siteZone;

  Map<String, Object?> toJson() => <String, Object?>{
    'roomType': roomType?.name,
    'siteZone': siteZone?.name,
  };
}

class SpatialRelationship {
  const SpatialRelationship({
    required this.id,
    required this.source,
    required this.target,
    required this.type,
    this.weight = 1,
    this.enabled = true,
    required this.label,
  });

  factory SpatialRelationship.fromJson(Map<String, Object?> json) =>
      SpatialRelationship(
        id: json['id'] as String,
        source: RoomType.values.byName(json['source'] as String),
        target: RelationshipTarget.fromJson(
          json['target'] as Map<String, Object?>,
        ),
        type: SpatialRelationshipType.values.byName(json['type'] as String),
        weight: (json['weight'] as num).toDouble(),
        enabled: json['enabled'] as bool,
        label: json['label'] as String,
      );

  final String id;
  final RoomType source;
  final RelationshipTarget target;
  final SpatialRelationshipType type;
  final double weight;
  final bool enabled;
  final String label;

  SpatialRelationship copyWith({bool? enabled, double? weight}) =>
      SpatialRelationship(
        id: id,
        source: source,
        target: target,
        type: type,
        weight: weight ?? this.weight,
        enabled: enabled ?? this.enabled,
        label: label,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'source': source.name,
    'target': target.toJson(),
    'type': type.name,
    'weight': weight,
    'enabled': enabled,
    'label': label,
  };
}

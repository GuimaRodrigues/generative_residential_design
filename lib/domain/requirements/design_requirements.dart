import '../site/site.dart';
import 'room_requirement.dart';
import 'spatial_relationship.dart';

class DesignRequirements {
  const DesignRequirements({
    required this.site,
    required this.floorCount,
    required this.rooms,
    required this.relationships,
    this.maximumTotalArea,
  });

  factory DesignRequirements.fromJson(Map<String, Object?> json) =>
      DesignRequirements(
        site: Site.fromJson(json['site'] as Map<String, Object?>),
        floorCount: json['floorCount'] as int,
        maximumTotalArea: (json['maximumTotalArea'] as num?)?.toDouble(),
        rooms: (json['rooms'] as List<Object?>)
            .map(
              (item) => RoomRequirement.fromJson(item as Map<String, Object?>),
            )
            .toList(growable: false),
        relationships: (json['relationships'] as List<Object?>)
            .map(
              (item) =>
                  SpatialRelationship.fromJson(item as Map<String, Object?>),
            )
            .toList(growable: false),
      );

  final Site site;
  final int floorCount;
  final double? maximumTotalArea;
  final List<RoomRequirement> rooms;
  final List<SpatialRelationship> relationships;

  List<RoomInstance> normalizeRooms() {
    final instances = <RoomInstance>[];
    final typeCounters = <String, int>{};
    for (final requirement in rooms) {
      for (var index = 0; index < requirement.count; index++) {
        final typeName = requirement.roomType.name;
        final serial = (typeCounters[typeName] ?? 0) + 1;
        typeCounters[typeName] = serial;
        instances.add(
          RoomInstance(
            id: '${typeName}_$serial',
            requirementId: requirement.id,
            roomType: requirement.roomType,
            preferredFloor: requirement.preferredFloor,
            targetArea: requirement.effectiveTargetArea,
            minArea: requirement.effectiveMinArea,
            minWidth: requirement.effectiveMinWidth,
            minDepth: requirement.effectiveMinDepth,
          ),
        );
      }
    }
    return List<RoomInstance>.unmodifiable(instances);
  }

  DesignRequirements copyWith({
    Site? site,
    int? floorCount,
    double? maximumTotalArea,
    List<RoomRequirement>? rooms,
    List<SpatialRelationship>? relationships,
  }) => DesignRequirements(
    site: site ?? this.site,
    floorCount: floorCount ?? this.floorCount,
    maximumTotalArea: maximumTotalArea ?? this.maximumTotalArea,
    rooms: List<RoomRequirement>.unmodifiable(rooms ?? this.rooms),
    relationships: List<SpatialRelationship>.unmodifiable(
      relationships ?? this.relationships,
    ),
  );

  DesignRequirements withMaximumTotalArea(double? value) => DesignRequirements(
    site: site,
    floorCount: floorCount,
    maximumTotalArea: value,
    rooms: rooms,
    relationships: relationships,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'site': site.toJson(),
    'floorCount': floorCount,
    'maximumTotalArea': maximumTotalArea,
    'rooms': rooms.map((room) => room.toJson()).toList(growable: false),
    'relationships': relationships
        .map((relationship) => relationship.toJson())
        .toList(growable: false),
  };
}

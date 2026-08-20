import '../requirements/design_requirements.dart';
import '../requirements/room_requirement.dart';
import '../requirements/room_type.dart';
import '../requirements/spatial_relationship.dart';
import '../site/site.dart';
import 'design_project.dart';

DesignProject createSampleProject() => DesignProject(
  id: 'sample-project',
  name: 'Courtyard House Study',
  seed: 839172,
  requirements: DesignRequirements(
    site: const Site(
      width: 12,
      depth: 30,
      streetSide: StreetSide.south,
      frontSetback: 5,
      rearSetback: 3,
      leftSetback: 1.5,
      rightSetback: 1.5,
    ),
    floorCount: 2,
    rooms: const <RoomRequirement>[
      RoomRequirement(
        id: 'living',
        roomType: RoomType.livingRoom,
        preferredFloor: PreferredFloor.ground,
      ),
      RoomRequirement(
        id: 'kitchen',
        roomType: RoomType.kitchen,
        preferredFloor: PreferredFloor.ground,
      ),
      RoomRequirement(
        id: 'bath-ground',
        roomType: RoomType.bathroom,
        preferredFloor: PreferredFloor.ground,
      ),
      RoomRequirement(
        id: 'office',
        roomType: RoomType.office,
        preferredFloor: PreferredFloor.ground,
      ),
      RoomRequirement(
        id: 'garage',
        roomType: RoomType.garage,
        preferredFloor: PreferredFloor.ground,
      ),
      RoomRequirement(
        id: 'stairs-ground',
        roomType: RoomType.stairs,
        preferredFloor: PreferredFloor.ground,
      ),
      RoomRequirement(
        id: 'master',
        roomType: RoomType.masterBedroom,
        preferredFloor: PreferredFloor.upper,
      ),
      RoomRequirement(
        id: 'bedrooms',
        roomType: RoomType.bedroom,
        count: 2,
        preferredFloor: PreferredFloor.upper,
      ),
      RoomRequirement(
        id: 'bath-upper',
        roomType: RoomType.bathroom,
        preferredFloor: PreferredFloor.upper,
      ),
      RoomRequirement(
        id: 'stairs-upper',
        roomType: RoomType.stairs,
        preferredFloor: PreferredFloor.upper,
      ),
    ],
    relationships: const <SpatialRelationship>[
      SpatialRelationship(
        id: 'kitchen-living',
        source: RoomType.kitchen,
        target: RelationshipTarget.room(RoomType.livingRoom),
        type: SpatialRelationshipType.adjacentTo,
        label: 'Kitchen adjacent to living room',
      ),
      SpatialRelationship(
        id: 'kitchen-dining',
        source: RoomType.kitchen,
        target: RelationshipTarget.room(RoomType.diningRoom),
        type: SpatialRelationshipType.near,
        enabled: false,
        label: 'Kitchen near dining room',
      ),
      SpatialRelationship(
        id: 'garage-street',
        source: RoomType.garage,
        target: RelationshipTarget.site(SiteZone.street),
        type: SpatialRelationshipType.near,
        label: 'Garage near street',
      ),
      SpatialRelationship(
        id: 'master-street',
        source: RoomType.masterBedroom,
        target: RelationshipTarget.site(SiteZone.street),
        type: SpatialRelationshipType.awayFrom,
        label: 'Master bedroom away from street',
      ),
      SpatialRelationship(
        id: 'bedroom-group',
        source: RoomType.bedroom,
        target: RelationshipTarget.room(RoomType.bedroom),
        type: SpatialRelationshipType.near,
        label: 'Bedrooms near each other',
      ),
      SpatialRelationship(
        id: 'office-living',
        source: RoomType.office,
        target: RelationshipTarget.room(RoomType.livingRoom),
        type: SpatialRelationshipType.awayFrom,
        label: 'Office away from living room',
      ),
    ],
  ),
);

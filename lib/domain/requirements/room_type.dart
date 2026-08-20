enum RoomType {
  livingRoom,
  kitchen,
  diningRoom,
  bedroom,
  masterBedroom,
  bathroom,
  toilet,
  office,
  laundry,
  garage,
  hallway,
  stairs,
  closet,
}

class RoomMetadata {
  const RoomMetadata({
    required this.displayName,
    required this.targetArea,
    required this.minimumArea,
    required this.minimumWidth,
    required this.minimumDepth,
  });

  final String displayName;
  final double targetArea;
  final double minimumArea;
  final double minimumWidth;
  final double minimumDepth;
}

const Map<RoomType, RoomMetadata> roomMetadata = <RoomType, RoomMetadata>{
  RoomType.livingRoom: RoomMetadata(
    displayName: 'Living room',
    targetArea: 28,
    minimumArea: 16,
    minimumWidth: 3,
    minimumDepth: 3,
  ),
  RoomType.kitchen: RoomMetadata(
    displayName: 'Kitchen',
    targetArea: 14,
    minimumArea: 8,
    minimumWidth: 2.4,
    minimumDepth: 2.4,
  ),
  RoomType.diningRoom: RoomMetadata(
    displayName: 'Dining room',
    targetArea: 14,
    minimumArea: 9,
    minimumWidth: 2.5,
    minimumDepth: 2.5,
  ),
  RoomType.bedroom: RoomMetadata(
    displayName: 'Bedroom',
    targetArea: 12,
    minimumArea: 9,
    minimumWidth: 2.5,
    minimumDepth: 2.5,
  ),
  RoomType.masterBedroom: RoomMetadata(
    displayName: 'Master bedroom',
    targetArea: 18,
    minimumArea: 12,
    minimumWidth: 3,
    minimumDepth: 3,
  ),
  RoomType.bathroom: RoomMetadata(
    displayName: 'Bathroom',
    targetArea: 5,
    minimumArea: 3,
    minimumWidth: 1.5,
    minimumDepth: 1.5,
  ),
  RoomType.toilet: RoomMetadata(
    displayName: 'Toilet',
    targetArea: 2.5,
    minimumArea: 1.5,
    minimumWidth: 1,
    minimumDepth: 1.2,
  ),
  RoomType.office: RoomMetadata(
    displayName: 'Office',
    targetArea: 10,
    minimumArea: 7,
    minimumWidth: 2.2,
    minimumDepth: 2.2,
  ),
  RoomType.laundry: RoomMetadata(
    displayName: 'Laundry',
    targetArea: 5,
    minimumArea: 3,
    minimumWidth: 1.5,
    minimumDepth: 1.5,
  ),
  RoomType.garage: RoomMetadata(
    displayName: 'Garage',
    targetArea: 22,
    minimumArea: 15,
    minimumWidth: 2.8,
    minimumDepth: 5,
  ),
  RoomType.hallway: RoomMetadata(
    displayName: 'Hallway',
    targetArea: 5,
    minimumArea: 2,
    minimumWidth: 1,
    minimumDepth: 1,
  ),
  RoomType.stairs: RoomMetadata(
    displayName: 'Stairs',
    targetArea: 6,
    minimumArea: 4,
    minimumWidth: 1.8,
    minimumDepth: 2,
  ),
  RoomType.closet: RoomMetadata(
    displayName: 'Closet',
    targetArea: 3,
    minimumArea: 1.5,
    minimumWidth: 1,
    minimumDepth: 1,
  ),
};

extension RoomTypeDetails on RoomType {
  RoomMetadata get metadata => roomMetadata[this]!;
  String get displayName => metadata.displayName;
}

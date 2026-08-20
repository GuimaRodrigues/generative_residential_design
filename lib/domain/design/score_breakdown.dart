class RelationshipScoreDetail {
  const RelationshipScoreDetail({required this.label, required this.score});
  final String label;
  final double score;
  bool get satisfied => score >= 60;
}

class ScoreBreakdown {
  const ScoreBreakdown({
    required this.overall,
    required this.relationships,
    required this.roomProportions,
    required this.streetOrientation,
    required this.compactness,
    required this.floorPreference,
    required this.relationshipDetails,
  });

  final double overall;
  final double relationships;
  final double roomProportions;
  final double streetOrientation;
  final double compactness;
  final double floorPreference;
  final List<RelationshipScoreDetail> relationshipDetails;

  Map<String, double> get categories => <String, double>{
    'Relationships': relationships,
    'Room proportions': roomProportions,
    'Street orientation': streetOrientation,
    'Compactness': compactness,
    'Floor preferences': floorPreference,
  };
}

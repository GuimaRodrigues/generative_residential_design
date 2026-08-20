class GenerationConfig {
  const GenerationConfig({
    this.attempts = 150,
    this.maxValidCandidates = 30,
    this.displayTopCandidates = 10,
    this.gridSize = 0.25,
    this.minimumSharedBoundary = 0.5,
    this.partitionRetries = 24,
  });

  factory GenerationConfig.fromJson(Map<String, Object?> json) =>
      GenerationConfig(
        attempts: json['attempts'] as int,
        maxValidCandidates: json['maxValidCandidates'] as int,
        displayTopCandidates: json['displayTopCandidates'] as int,
        gridSize: (json['gridSize'] as num).toDouble(),
        minimumSharedBoundary: (json['minimumSharedBoundary'] as num)
            .toDouble(),
        partitionRetries: (json['partitionRetries'] as int?) ?? 24,
      );

  final int attempts;
  final int maxValidCandidates;
  final int displayTopCandidates;
  final double gridSize;
  final double minimumSharedBoundary;
  final int partitionRetries;

  Map<String, Object> toJson() => <String, Object>{
    'attempts': attempts,
    'maxValidCandidates': maxValidCandidates,
    'displayTopCandidates': displayTopCandidates,
    'gridSize': gridSize,
    'minimumSharedBoundary': minimumSharedBoundary,
    'partitionRetries': partitionRetries,
  };
}

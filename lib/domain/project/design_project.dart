import '../requirements/design_requirements.dart';

class DesignProject {
  const DesignProject({
    required this.id,
    required this.name,
    required this.seed,
    required this.requirements,
  });

  factory DesignProject.fromJson(Map<String, Object?> json) => DesignProject(
    id: json['id'] as String,
    name: json['name'] as String,
    seed: json['seed'] as int,
    requirements: DesignRequirements.fromJson(
      json['requirements'] as Map<String, Object?>,
    ),
  );

  final String id;
  final String name;
  final int seed;
  final DesignRequirements requirements;

  DesignProject copyWith({
    String? id,
    String? name,
    int? seed,
    DesignRequirements? requirements,
  }) => DesignProject(
    id: id ?? this.id,
    name: name ?? this.name,
    seed: seed ?? this.seed,
    requirements: requirements ?? this.requirements,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'seed': seed,
    'requirements': requirements.toJson(),
  };
}

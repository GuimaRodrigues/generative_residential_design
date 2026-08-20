import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/serialization/project_document.dart';
import '../../../domain/project/design_project.dart';
import '../../../domain/project/sample_project.dart';
import '../../../domain/requirements/design_requirements.dart';
import '../../../domain/requirements/room_requirement.dart';
import '../../../domain/requirements/room_type.dart';
import '../../../domain/site/site.dart';
import '../../../engine/generation/generation_config.dart';

class ProjectState {
  const ProjectState({required this.project, required this.generationConfig});
  final DesignProject project;
  final GenerationConfig generationConfig;

  ProjectDocument get document =>
      ProjectDocument(project: project, generationConfig: generationConfig);
}

class ProjectCubit extends Cubit<ProjectState> {
  ProjectCubit()
    : super(
        ProjectState(
          project: createSampleProject(),
          generationConfig: const GenerationConfig(),
        ),
      );

  void replace(ProjectDocument document) {
    emit(
      ProjectState(
        project: document.project,
        generationConfig: document.generationConfig,
      ),
    );
  }

  void updateName(String name) =>
      _emitProject(state.project.copyWith(name: name));
  void updateSeed(int seed) => _emitProject(state.project.copyWith(seed: seed));

  void updateSite(Site site) {
    _emitRequirements(state.project.requirements.copyWith(site: site));
  }

  void updateFloorCount(int floorCount) {
    final adjustedRooms = state.project.requirements.rooms
        .map((room) {
          if (floorCount == 1 && room.preferredFloor == PreferredFloor.upper) {
            return room.copyWith(preferredFloor: PreferredFloor.any);
          }
          return room;
        })
        .toList(growable: false);
    _emitRequirements(
      state.project.requirements.copyWith(
        floorCount: floorCount,
        rooms: adjustedRooms,
      ),
    );
  }

  void updateMaximumArea(double? area) {
    final requirements = state.project.requirements;
    _emitRequirements(requirements.withMaximumTotalArea(area));
  }

  void addRoom() {
    final existingIds = state.project.requirements.rooms
        .map((room) => room.id)
        .toSet();
    var serial = state.project.requirements.rooms.length + 1;
    while (existingIds.contains('room-$serial')) {
      serial++;
    }
    final rooms = <RoomRequirement>[
      ...state.project.requirements.rooms,
      RoomRequirement(id: 'room-$serial', roomType: RoomType.bedroom),
    ];
    _emitRequirements(state.project.requirements.copyWith(rooms: rooms));
  }

  void updateRoom(RoomRequirement room) {
    final rooms = state.project.requirements.rooms
        .map((item) => item.id == room.id ? room : item)
        .toList(growable: false);
    _emitRequirements(state.project.requirements.copyWith(rooms: rooms));
  }

  void removeRoom(String id) {
    if (state.project.requirements.rooms.length <= 1) return;
    final rooms = state.project.requirements.rooms
        .where((room) => room.id != id)
        .toList(growable: false);
    _emitRequirements(state.project.requirements.copyWith(rooms: rooms));
  }

  void toggleRelationship(String id, bool enabled) {
    final relationships = state.project.requirements.relationships
        .map((relationship) {
          return relationship.id == id
              ? relationship.copyWith(enabled: enabled)
              : relationship;
        })
        .toList(growable: false);
    _emitRequirements(
      state.project.requirements.copyWith(relationships: relationships),
    );
  }

  void _emitRequirements(DesignRequirements requirements) {
    _emitProject(state.project.copyWith(requirements: requirements));
  }

  void _emitProject(DesignProject project) {
    emit(
      ProjectState(project: project, generationConfig: state.generationConfig),
    );
  }
}

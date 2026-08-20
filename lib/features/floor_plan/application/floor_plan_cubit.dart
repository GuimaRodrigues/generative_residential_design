import 'package:flutter_bloc/flutter_bloc.dart';

enum FloorPlanViewMode { plan2D, model3D }

class FloorPlanViewState {
  const FloorPlanViewState({
    this.floorIndex = 0,
    this.selectedRoomId,
    this.viewMode = FloorPlanViewMode.plan2D,
  });

  final int floorIndex;
  final String? selectedRoomId;
  final FloorPlanViewMode viewMode;
}

class FloorPlanCubit extends Cubit<FloorPlanViewState> {
  FloorPlanCubit() : super(const FloorPlanViewState());

  void selectFloor(int floorIndex) => emit(
    FloorPlanViewState(floorIndex: floorIndex, viewMode: state.viewMode),
  );

  void selectRoom(String? roomId, {int? floorIndex}) => emit(
    FloorPlanViewState(
      floorIndex: floorIndex ?? state.floorIndex,
      selectedRoomId: roomId,
      viewMode: state.viewMode,
    ),
  );

  void selectViewMode(FloorPlanViewMode viewMode) => emit(
    FloorPlanViewState(
      floorIndex: state.floorIndex,
      selectedRoomId: state.selectedRoomId,
      viewMode: viewMode,
    ),
  );

  void reset() => emit(const FloorPlanViewState());
}

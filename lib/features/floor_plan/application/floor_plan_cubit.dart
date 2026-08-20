import 'package:flutter_bloc/flutter_bloc.dart';

class FloorPlanViewState {
  const FloorPlanViewState({this.floorIndex = 0, this.selectedRoomId});
  final int floorIndex;
  final String? selectedRoomId;
}

class FloorPlanCubit extends Cubit<FloorPlanViewState> {
  FloorPlanCubit() : super(const FloorPlanViewState());

  void selectFloor(int floorIndex) =>
      emit(FloorPlanViewState(floorIndex: floorIndex));

  void selectRoom(String? roomId) => emit(
    FloorPlanViewState(floorIndex: state.floorIndex, selectedRoomId: roomId),
  );

  void reset() => emit(const FloorPlanViewState());
}

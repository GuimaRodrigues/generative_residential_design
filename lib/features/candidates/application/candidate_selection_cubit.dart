import 'package:flutter_bloc/flutter_bloc.dart';

class CandidateSelectionCubit extends Cubit<int?> {
  CandidateSelectionCubit() : super(null);

  void select(int index) => emit(index);
  void clear() => emit(null);
}

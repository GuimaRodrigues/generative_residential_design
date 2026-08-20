import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/candidates/application/candidate_selection_cubit.dart';
import '../features/floor_plan/application/floor_plan_cubit.dart';
import '../features/generation/application/generation_cubit.dart';
import '../features/project/application/project_cubit.dart';
import '../features/workspace/presentation/workspace_page.dart';
import 'theme/app_theme.dart';

class GenerativeResidentialDesignApp extends StatelessWidget {
  const GenerativeResidentialDesignApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProjectCubit>(create: (_) => ProjectCubit()),
        BlocProvider<GenerationCubit>(create: (_) => GenerationCubit()),
        BlocProvider<CandidateSelectionCubit>(
          create: (_) => CandidateSelectionCubit(),
        ),
        BlocProvider<FloorPlanCubit>(create: (_) => FloorPlanCubit()),
      ],
      child: MaterialApp(
        title: 'Forma — Conceptual Residential Design',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const WorkspacePage(),
      ),
    );
  }
}

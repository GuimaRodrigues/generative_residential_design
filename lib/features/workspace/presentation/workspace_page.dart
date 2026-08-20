import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_theme.dart';
import '../../candidates/application/candidate_selection_cubit.dart';
import '../../candidates/presentation/candidates_panel.dart';
import '../../floor_plan/application/floor_plan_cubit.dart';
import '../../floor_plan/presentation/floor_plan_canvas.dart';
import '../../generation/application/generation_cubit.dart';
import '../../generation/presentation/workspace_toolbar.dart';
import '../../requirements/presentation/requirements_panel.dart';

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<GenerationCubit, GenerationState>(
      listener: (context, state) {
        if (state is GenerationSuccess) {
          context.read<CandidateSelectionCubit>().select(0);
          context.read<FloorPlanCubit>().reset();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: <Widget>[
              const WorkspaceToolbar(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final content = Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: const <Widget>[
                        SizedBox(width: 338, child: RequirementsPanel()),
                        VerticalDivider(width: 1),
                        Expanded(child: FloorPlanCanvas()),
                        VerticalDivider(width: 1),
                        SizedBox(width: 310, child: CandidatesPanel()),
                      ],
                    );
                    if (constraints.maxWidth >= 1080) return content;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 1080,
                        height: constraints.maxHeight,
                        child: content,
                      ),
                    );
                  },
                ),
              ),
              Container(
                height: 25,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  border: Border(top: BorderSide(color: Color(0xFF344147))),
                ),
                child: const Text(
                  'CONCEPTUAL STUDY ONLY  ·  Not code-checked or construction-ready',
                  style: TextStyle(
                    color: Color(0xFFAEBABD),
                    fontSize: 9.5,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

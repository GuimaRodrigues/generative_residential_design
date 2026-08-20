import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/design/design_candidate.dart';
import '../../floor_plan/application/floor_plan_cubit.dart';
import '../../generation/application/generation_cubit.dart';
import '../application/candidate_selection_cubit.dart';

class CandidatesPanel extends StatelessWidget {
  const CandidatesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: BlocBuilder<GenerationCubit, GenerationState>(
        builder: (context, state) => switch (state) {
          GenerationIdle() => const _IdlePanel(),
          GenerationGenerating() => _GeneratingPanel(state: state),
          GenerationFailure() => _FailurePanel(state: state),
          GenerationSuccess() => _SuccessPanel(state: state),
        },
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 17, 16, 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: 1.05,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: AppColors.mutedInk),
        ),
      ],
    ),
  );
}

class _IdlePanel extends StatelessWidget {
  const _IdlePanel();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _PanelTitle(
        title: 'GENERATED OPTIONS',
        subtitle: 'Ranked conceptual alternatives',
      ),
      Divider(height: 1),
      Expanded(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'Candidates and score diagnostics will appear here after generation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.mutedInk,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _GeneratingPanel extends StatelessWidget {
  const _GeneratingPanel({required this.state});
  final GenerationGenerating state;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const _PanelTitle(
        title: 'GENERATING LAYOUTS',
        subtitle: 'Constraint-guided slicing search',
      ),
      LinearProgressIndicator(value: state.progress.fraction, minHeight: 3),
      Padding(
        padding: const EdgeInsets.all(18),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Attempts  ${state.progress.attempt} / ${state.progress.totalAttempts}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                Text(
                  'Valid layouts  ${state.progress.validCount}',
                  style: const TextStyle(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _FailurePanel extends StatelessWidget {
  const _FailurePanel({required this.state});
  final GenerationFailure state;

  @override
  Widget build(BuildContext context) => ListView(
    children: <Widget>[
      const _PanelTitle(
        title: 'NO VALID LAYOUT',
        subtitle: 'The brief needs adjustment',
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5E7E4),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFFE5C5BF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.report_gmailerrorred_outlined,
                color: AppColors.danger,
              ),
              const SizedBox(height: 10),
              Text(
                state.message,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
      if (state.result case final result?)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Attempts: ${result.diagnostics.attempted} · Valid: ${result.diagnostics.valid}',
            style: const TextStyle(fontSize: 10.5, color: AppColors.mutedInk),
          ),
        ),
    ],
  );
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({required this.state});
  final GenerationSuccess state;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CandidateSelectionCubit, int?>(
      builder: (context, selectedIndex) {
        final selected = selectedIndex == null
            ? null
            : state.result.candidates[selectedIndex];
        return CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _PanelTitle(
                title: 'GENERATED OPTIONS',
                subtitle:
                    '${state.result.diagnostics.valid} valid designs · ${state.result.diagnostics.attempted} attempts',
              ),
            ),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverList.separated(
                itemCount: state.result.candidates.length,
                separatorBuilder: (_, _) => const SizedBox(height: 7),
                itemBuilder: (context, index) => _CandidateCard(
                  candidate: state.result.candidates[index],
                  rank: index + 1,
                  selected: index == selectedIndex,
                  onTap: () {
                    context.read<CandidateSelectionCubit>().select(index);
                    context.read<FloorPlanCubit>().selectRoom(null);
                  },
                ),
              ),
            ),
            if (selected != null)
              SliverToBoxAdapter(
                child: _CandidateInspector(candidate: selected),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        );
      },
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.rank,
    required this.selected,
    required this.onTap,
  });
  final DesignCandidate candidate;
  final int rank;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.accentSoft : Colors.white,
    shape: RoundedRectangleBorder(
      side: BorderSide(
        color: selected ? AppColors.accent : AppColors.line,
        width: selected ? 1.4 : 1,
      ),
      borderRadius: BorderRadius.circular(7),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              child: Text(
                '#$rank',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mutedInk,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${candidate.rooms.length} spaces · ${candidate.totalArea.toStringAsFixed(0)} m²',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.mutedInk,
                ),
              ),
            ),
            Text(
              candidate.score.overall.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CandidateInspector extends StatelessWidget {
  const _CandidateInspector({required this.candidate});
  final DesignCandidate candidate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'SCORE BREAKDOWN',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 12),
        ...candidate.score.categories.entries.map(
          (entry) => _ScoreRow(label: entry.key, value: entry.value),
        ),
        const SizedBox(height: 15),
        const Text(
          'PREFERENCES',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        if (candidate.score.relationshipDetails.isEmpty)
          const Text(
            'No enabled spatial preferences.',
            style: TextStyle(fontSize: 11, color: AppColors.mutedInk),
          )
        else
          ...candidate.score.relationshipDetails.map(
            (detail) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    detail.satisfied
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    size: 15,
                    color: detail.satisfied
                        ? AppColors.accent
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      detail.label,
                      style: const TextStyle(fontSize: 11.2, height: 1.3),
                    ),
                  ),
                  Text(
                    detail.score.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (candidate.warnings.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4EDE3),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              candidate.warnings.join('\n'),
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.4,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10.8, color: AppColors.mutedInk),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E6E3),
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 7),
        SizedBox(
          width: 26,
          child: Text(
            value.toStringAsFixed(0),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/platform/file_transfer.dart';
import '../../../core/serialization/project_codec.dart';
import '../../../core/serialization/svg_exporter.dart';
import '../../candidates/application/candidate_selection_cubit.dart';
import '../../floor_plan/application/floor_plan_cubit.dart';
import '../../project/application/project_cubit.dart';
import '../application/generation_cubit.dart';

class WorkspaceToolbar extends StatelessWidget {
  const WorkspaceToolbar({super.key});

  static const _files = BrowserFileTransfer();
  static const _codec = ProjectCodec();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        border: Border(bottom: BorderSide(color: Color(0xFF334147))),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF8FC1B8), width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Icon(
              Icons.architecture,
              color: Color(0xFFB5DDD5),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'FORMA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.1,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'RESIDENTIAL CONCEPT STUDIES',
                style: TextStyle(
                  color: Color(0xFF91A1A5),
                  fontSize: 8.5,
                  letterSpacing: 1.25,
                ),
              ),
            ],
          ),
          const Spacer(),
          BlocBuilder<ProjectCubit, ProjectState>(
            builder: (context, state) => SizedBox(
              width: 140,
              child: _SeedField(
                seed: state.project.seed,
                onChanged: context.read<ProjectCubit>().updateSeed,
                onRandomize: () {
                  final next =
                      (state.project.seed * 1664525 + 1013904223) & 0x7fffffff;
                  context.read<ProjectCubit>().updateSeed(next);
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          _ToolbarButton(
            icon: Icons.file_upload_outlined,
            label: 'IMPORT',
            onPressed: () => _import(context),
          ),
          _ToolbarButton(
            icon: Icons.file_download_outlined,
            label: 'PROJECT',
            onPressed: () => _exportProject(context),
          ),
          _ToolbarButton(
            icon: Icons.draw_outlined,
            label: 'SVG',
            onPressed: () => _exportSvg(context),
          ),
          const SizedBox(width: 8),
          BlocBuilder<GenerationCubit, GenerationState>(
            builder: (context, state) {
              final generating = state is GenerationGenerating;
              return FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF67A69C),
                  foregroundColor: const Color(0xFF0F2927),
                  minimumSize: const Size(128, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                onPressed: generating
                    ? null
                    : () => context.read<GenerationCubit>().generate(
                        context.read<ProjectCubit>().state,
                      ),
                icon: generating
                    ? const SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 17),
                label: Text(generating ? 'GENERATING' : 'GENERATE'),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    try {
      final imported = await _files.pickText();
      if (imported == null || !context.mounted) return;
      final document = _codec.decode(imported.contents);
      context.read<ProjectCubit>().replace(document);
      context.read<GenerationCubit>().clear();
      context.read<CandidateSelectionCubit>().clear();
      context.read<FloorPlanCubit>().reset();
      _notice(context, 'Imported ${imported.name}');
    } on Object catch (error) {
      if (context.mounted) _notice(context, '$error', error: true);
    }
  }

  void _exportProject(BuildContext context) {
    final state = context.read<ProjectCubit>().state;
    _files.downloadText(
      filename: '${_safeName(state.project.name)}.grd.json',
      contents: _codec.encode(state.document),
      mimeType: 'application/json;charset=utf-8',
    );
    _notice(context, 'Project JSON exported');
  }

  void _exportSvg(BuildContext context) {
    final generation = context.read<GenerationCubit>().state;
    final index = context.read<CandidateSelectionCubit>().state;
    if (generation is! GenerationSuccess || index == null) {
      _notice(
        context,
        'Generate and select a candidate before exporting SVG.',
        error: true,
      );
      return;
    }
    final candidate = generation.result.candidates[index];
    final floor = context.read<FloorPlanCubit>().state.floorIndex;
    final project = context.read<ProjectCubit>().state.project;
    final svg = const SvgExporter().export(
      candidate: candidate,
      site: project.requirements.site,
      floorIndex: floor,
    );
    _files.downloadText(
      filename:
          '${_safeName(project.name)}-candidate-${index + 1}-floor-${floor + 1}.svg',
      contents: svg,
      mimeType: 'image/svg+xml;charset=utf-8',
    );
    _notice(context, 'Vector floor plan exported');
  }

  String _safeName(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  void _notice(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.accent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SeedField extends StatefulWidget {
  const _SeedField({
    required this.seed,
    required this.onChanged,
    required this.onRandomize,
  });

  final int seed;
  final ValueChanged<int> onChanged;
  final VoidCallback onRandomize;

  @override
  State<_SeedField> createState() => _SeedFieldState();
}

class _SeedFieldState extends State<_SeedField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.seed.toString());
  }

  @override
  void didUpdateWidget(covariant _SeedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (int.tryParse(_controller.text) != widget.seed) {
      final text = widget.seed.toString();
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const ValueKey<String>('generation-seed-field'),
      controller: _controller,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'GENERATION SEED',
        labelStyle: const TextStyle(
          color: Color(0xFF94A5A8),
          fontSize: 9.5,
          letterSpacing: 0.6,
        ),
        fillColor: const Color(0xFF263238),
        suffixIcon: IconButton(
          tooltip: 'Randomize seed',
          onPressed: widget.onRandomize,
          icon: const Icon(
            Icons.casino_outlined,
            size: 17,
            color: Color(0xFFB5C2C4),
          ),
        ),
      ),
      onChanged: (value) {
        final seed = int.tryParse(value);
        if (seed != null) {
          widget.onChanged(seed);
        }
      },
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 16),
    label: Text(label),
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFFC6D0D2),
      textStyle: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    ),
  );
}

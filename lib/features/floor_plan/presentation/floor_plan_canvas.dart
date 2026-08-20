import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/geometry/point_2d.dart';
import '../../../core/geometry/rect_2d.dart';
import '../../../domain/design/design_candidate.dart';
import '../../../domain/design/floor_plan.dart';
import '../../../domain/design/generated_room.dart';
import '../../../domain/requirements/room_type.dart';
import '../../../domain/site/site.dart';
import '../../../engine/scene/architectural_scene_builder.dart';
import '../../candidates/application/candidate_selection_cubit.dart';
import '../../generation/application/generation_cubit.dart';
import '../../project/application/project_cubit.dart';
import '../application/floor_plan_cubit.dart';
import 'scene_3d_view.dart';

class FloorPlanCanvas extends StatelessWidget {
  const FloorPlanCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectCubit, ProjectState>(
      builder: (context, projectState) {
        return BlocBuilder<GenerationCubit, GenerationState>(
          builder: (context, generationState) {
            return BlocBuilder<CandidateSelectionCubit, int?>(
              builder: (context, selectedIndex) {
                final candidate =
                    generationState is GenerationSuccess &&
                        selectedIndex != null
                    ? generationState.result.candidates[selectedIndex]
                    : null;
                return BlocBuilder<FloorPlanCubit, FloorPlanViewState>(
                  builder: (context, viewState) => Column(
                    children: <Widget>[
                      _CanvasHeader(
                        candidate: candidate,
                        selectedIndex: selectedIndex,
                        floorCount:
                            projectState.project.requirements.floorCount,
                        viewState: viewState,
                      ),
                      Expanded(
                        child: candidate == null
                            ? const _EmptyCanvas()
                            : switch (viewState.viewMode) {
                                FloorPlanViewMode.plan2D => _PlanStage(
                                  key: ValueKey(
                                    '${candidate.id}-${viewState.floorIndex}',
                                  ),
                                  candidate: candidate,
                                  site: projectState.project.requirements.site,
                                  viewState: viewState,
                                ),
                                FloorPlanViewMode.model3D => Scene3DView(
                                  key: ValueKey('scene-3d-${candidate.id}'),
                                  scene: const ArchitecturalSceneBuilder()
                                      .build(
                                        candidate: candidate,
                                        site: projectState
                                            .project
                                            .requirements
                                            .site,
                                      ),
                                  selectedFloorIndex: viewState.floorIndex,
                                  selectedRoomId: viewState.selectedRoomId,
                                  onRoomSelected: (roomId, floorIndex) =>
                                      context.read<FloorPlanCubit>().selectRoom(
                                        roomId,
                                        floorIndex: floorIndex,
                                      ),
                                ),
                              },
                      ),
                      _CanvasFooter(
                        candidate: candidate,
                        floorCount:
                            projectState.project.requirements.floorCount,
                        viewState: viewState,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CanvasHeader extends StatelessWidget {
  const _CanvasHeader({
    required this.candidate,
    required this.selectedIndex,
    required this.floorCount,
    required this.viewState,
  });
  final DesignCandidate? candidate;
  final int? selectedIndex;
  final int floorCount;
  final FloorPlanViewState viewState;

  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    color: AppColors.surface,
    child: Row(
      children: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              candidate == null
                  ? 'CONCEPT PLAN'
                  : 'CANDIDATE ${(selectedIndex ?? 0) + 1}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              candidate == null
                  ? 'Awaiting generation'
                  : '${candidate!.rooms.length} spaces · ${candidate!.totalArea.toStringAsFixed(1)} m²',
              style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
            ),
          ],
        ),
        const Spacer(),
        if (candidate != null) ...<Widget>[
          SegmentedButton<FloorPlanViewMode>(
            key: const ValueKey('floor-plan-view-mode'),
            segments: const <ButtonSegment<FloorPlanViewMode>>[
              ButtonSegment<FloorPlanViewMode>(
                value: FloorPlanViewMode.plan2D,
                label: Text('2D'),
                icon: Icon(Icons.grid_4x4, size: 15),
              ),
              ButtonSegment<FloorPlanViewMode>(
                value: FloorPlanViewMode.model3D,
                label: Text('3D'),
                icon: Icon(Icons.view_in_ar, size: 15),
              ),
            ],
            selected: <FloorPlanViewMode>{viewState.viewMode},
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 9),
              ),
            ),
            onSelectionChanged: (selection) =>
                context.read<FloorPlanCubit>().selectViewMode(selection.single),
          ),
          const SizedBox(width: 18),
          const Text(
            'OVERALL',
            style: TextStyle(
              fontSize: 9,
              color: AppColors.mutedInk,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            candidate!.score.overall.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 18),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$floorCount FLOOR${floorCount == 1 ? '' : 'S'}',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
              letterSpacing: 0.7,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmptyCanvas extends StatelessWidget {
  const _EmptyCanvas();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFECEEEA),
    child: Center(
      child: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF97A5A5)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Icon(
                Icons.grid_4x4,
                size: 28,
                color: Color(0xFF718184),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Ready to generate',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Review the sample brief, choose a deterministic seed, then generate ranked conceptual floor plans.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.mutedInk,
              ),
            ),
            const SizedBox(height: 17),
            FilledButton.icon(
              onPressed: () => context.read<GenerationCubit>().generate(
                context.read<ProjectCubit>().state,
              ),
              icon: const Icon(Icons.auto_awesome, size: 17),
              label: const Text('GENERATE SAMPLE PROJECT'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PlanStage extends StatefulWidget {
  const _PlanStage({
    super.key,
    required this.candidate,
    required this.site,
    required this.viewState,
  });
  final DesignCandidate candidate;
  final Site site;
  final FloorPlanViewState viewState;

  @override
  State<_PlanStage> createState() => _PlanStageState();
}

class _PlanStageState extends State<_PlanStage> {
  final TransformationController _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.candidate.floors[widget.viewState.floorIndex];
    return ColoredBox(
      color: const Color(0xFFECEEEA),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return InteractiveViewer(
                  transformationController: _controller,
                  minScale: 0.65,
                  maxScale: 5,
                  boundaryMargin: const EdgeInsets.all(280),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) =>
                        _selectAt(details.localPosition, size, plan),
                    child: CustomPaint(
                      size: size,
                      painter: FloorPlanPainter(
                        site: widget.site,
                        floorPlan: plan,
                        selectedRoomId: widget.viewState.selectedRoomId,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: IconButton(
                tooltip: 'Reset pan and zoom',
                icon: const Icon(Icons.center_focus_strong, size: 18),
                onPressed: () => _controller.value = Matrix4.identity(),
              ),
            ),
          ),
          const Positioned(
            left: 12,
            bottom: 10,
            child: Text(
              'Scroll to zoom · Drag to pan · Select a room to inspect',
              style: TextStyle(fontSize: 9.5, color: Color(0xFF748184)),
            ),
          ),
        ],
      ),
    );
  }

  void _selectAt(Offset localPosition, Size size, FloorPlan plan) {
    final transform = _PlanTransform.forSize(size, widget.site);
    final world = transform.toWorld(localPosition);
    GeneratedRoom? selected;
    for (final room in plan.rooms) {
      if (room.bounds.containsPoint(world)) selected = room;
    }
    context.read<FloorPlanCubit>().selectRoom(selected?.id);
  }
}

class _CanvasFooter extends StatelessWidget {
  const _CanvasFooter({
    required this.candidate,
    required this.floorCount,
    required this.viewState,
  });
  final DesignCandidate? candidate;
  final int floorCount;
  final FloorPlanViewState viewState;

  @override
  Widget build(BuildContext context) {
    GeneratedRoom? selected;
    if (candidate != null && viewState.selectedRoomId != null) {
      selected = candidate!.rooms
          .where((room) => room.id == viewState.selectedRoomId)
          .firstOrNull;
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      color: AppColors.surface,
      child: Row(
        children: <Widget>[
          for (var floor = 0; floor < floorCount; floor++) ...<Widget>[
            ChoiceChip(
              label: Text(floor == 0 ? 'GROUND FLOOR' : 'UPPER FLOOR'),
              selected: viewState.floorIndex == floor,
              showCheckmark: false,
              onSelected: candidate == null
                  ? null
                  : (_) => context.read<FloorPlanCubit>().selectFloor(floor),
              labelStyle: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 6),
          ],
          const Spacer(),
          if (selected != null) ...<Widget>[
            Text(
              selected.roomType.displayName.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${selected.bounds.width.toStringAsFixed(2)} × ${selected.bounds.height.toStringAsFixed(2)} m',
              style: const TextStyle(fontSize: 11, color: AppColors.mutedInk),
            ),
            const SizedBox(width: 12),
            Text(
              '${selected.area.toStringAsFixed(1)} m²',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ] else if (candidate != null)
            Text(
              'SEED ${candidate!.seed}',
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.mutedInk,
                letterSpacing: 0.7,
              ),
            ),
        ],
      ),
    );
  }
}

class FloorPlanPainter extends CustomPainter {
  const FloorPlanPainter({
    required this.site,
    required this.floorPlan,
    this.selectedRoomId,
  });
  final Site site;
  final FloorPlan floorPlan;
  final String? selectedRoomId;

  @override
  void paint(Canvas canvas, Size size) {
    final transform = _PlanTransform.forSize(size, site);
    final lot = transform.rect(site.lotBounds);
    final envelope = transform.rect(site.buildableEnvelope);
    final lotPath = Path()..addRect(lot);
    canvas.drawShadow(lotPath, const Color(0x44000000), 7, false);
    canvas.drawRect(lot, Paint()..color = const Color(0xFFFAFBF8));

    final gridPaint = Paint()
      ..color = const Color(0xFFE7EAE6)
      ..strokeWidth = 0.6;
    for (var x = 1.0; x < site.width; x++) {
      canvas.drawLine(
        transform.point(Point2D(x, 0)),
        transform.point(Point2D(x, site.depth)),
        gridPaint,
      );
    }
    for (var y = 1.0; y < site.depth; y++) {
      canvas.drawLine(
        transform.point(Point2D(0, y)),
        transform.point(Point2D(site.width, y)),
        gridPaint,
      );
    }
    canvas.drawRect(
      lot,
      Paint()
        ..color = const Color(0xFF526267)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    _drawDashedRect(
      canvas,
      envelope,
      Paint()
        ..color = const Color(0xFF8D9C9E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    _drawStreet(canvas, transform, lot);

    for (final room in floorPlan.rooms) {
      final bounds = transform.rect(room.bounds);
      final selected = room.id == selectedRoomId;
      canvas.drawRect(bounds, Paint()..color = _roomColor(room.roomType));
      canvas.drawRect(
        bounds,
        Paint()
          ..color = selected ? AppColors.accent : const Color(0xFF27373C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3.2 : 1.65,
      );
      _drawRoomLabel(canvas, bounds, room);
    }
  }

  void _drawRoomLabel(Canvas canvas, Rect bounds, GeneratedRoom room) {
    if (bounds.width < 42 || bounds.height < 28) return;
    final detailed = bounds.width > 78 && bounds.height > 55;
    final title = TextPainter(
      text: TextSpan(
        text: room.roomType.displayName.toUpperCase(),
        style: TextStyle(
          color: AppColors.ink,
          fontSize: detailed ? 10 : 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.25,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: bounds.width - 8);
    final details = TextPainter(
      text: TextSpan(
        text:
            '${room.bounds.width.toStringAsFixed(2)} × ${room.bounds.height.toStringAsFixed(2)} m\n${room.area.toStringAsFixed(1)} m²',
        style: const TextStyle(
          color: AppColors.mutedInk,
          fontSize: 8.5,
          height: 1.25,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: bounds.width - 8);
    final totalHeight = title.height + (detailed ? details.height + 4 : 0);
    title.paint(
      canvas,
      Offset(
        bounds.center.dx - title.width / 2,
        bounds.center.dy - totalHeight / 2,
      ),
    );
    if (detailed) {
      details.paint(
        canvas,
        Offset(
          bounds.center.dx - details.width / 2,
          bounds.center.dy - totalHeight / 2 + title.height + 4,
        ),
      );
    }
  }

  void _drawStreet(Canvas canvas, _PlanTransform transform, Rect lot) {
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 5;
    final (start, end, labelOffset) = switch (site.streetSide) {
      StreetSide.north => (
        lot.topLeft,
        lot.topRight,
        Offset(lot.center.dx, lot.top - 16),
      ),
      StreetSide.south => (
        lot.bottomLeft,
        lot.bottomRight,
        Offset(lot.center.dx, lot.bottom + 16),
      ),
      StreetSide.east => (
        lot.topRight,
        lot.bottomRight,
        Offset(lot.right + 18, lot.center.dy),
      ),
      StreetSide.west => (
        lot.topLeft,
        lot.bottomLeft,
        Offset(lot.left - 18, lot.center.dy),
      ),
    };
    canvas.drawLine(start, end, paint);
    final label = TextPainter(
      text: const TextSpan(
        text: 'STREET',
        style: TextStyle(
          color: AppColors.accent,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      labelOffset - Offset(label.width / 2, label.height / 2),
    );
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    final path = Path()..addRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 6, metric.length)),
          paint,
        );
        distance += 10;
      }
    }
  }

  Color _roomColor(RoomType type) => switch (type) {
    RoomType.livingRoom => const Color(0xFFDDE9E3),
    RoomType.kitchen || RoomType.diningRoom => const Color(0xFFE8E3D5),
    RoomType.bedroom || RoomType.masterBedroom => const Color(0xFFDCE4EC),
    RoomType.bathroom ||
    RoomType.toilet ||
    RoomType.laundry => const Color(0xFFD8E9EA),
    RoomType.garage => const Color(0xFFE1E1DF),
    RoomType.office => const Color(0xFFE5DFEA),
    RoomType.stairs || RoomType.hallway => const Color(0xFFE9E6DD),
    RoomType.closet => const Color(0xFFE8E8E2),
  };

  @override
  bool shouldRepaint(covariant FloorPlanPainter oldDelegate) =>
      oldDelegate.floorPlan != floorPlan ||
      oldDelegate.selectedRoomId != selectedRoomId ||
      oldDelegate.site != site;
}

class _PlanTransform {
  const _PlanTransform(this.scale, this.offset);
  factory _PlanTransform.forSize(Size size, Site site) {
    const margin = 76.0;
    final scale = math
        .min(
          (size.width - margin * 2) / site.width,
          (size.height - margin * 2) / site.depth,
        )
        .clamp(1, 42)
        .toDouble();
    return _PlanTransform(
      scale,
      Offset(
        (size.width - site.width * scale) / 2,
        (size.height - site.depth * scale) / 2,
      ),
    );
  }
  final double scale;
  final Offset offset;

  Offset point(Point2D point) =>
      offset + Offset(point.x * scale, point.y * scale);
  Rect rect(Rect2D rect) => Rect.fromLTWH(
    offset.dx + rect.x * scale,
    offset.dy + rect.y * scale,
    rect.width * scale,
    rect.height * scale,
  );
  Point2D toWorld(Offset point) =>
      Point2D((point.dx - offset.dx) / scale, (point.dy - offset.dy) / scale);
}

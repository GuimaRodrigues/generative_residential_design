import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/requirements/room_requirement.dart';
import '../../../domain/requirements/room_type.dart';
import '../../../domain/site/site.dart';
import '../../project/application/project_cubit.dart';

class RequirementsPanel extends StatelessWidget {
  const RequirementsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: BlocBuilder<ProjectCubit, ProjectState>(
        builder: (context, state) {
          final project = state.project;
          final requirements = project.requirements;
          return CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 17, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _PanelHeading(number: '01', title: 'PROJECT BRIEF'),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: project.name,
                        decoration: const InputDecoration(
                          labelText: 'Project name',
                        ),
                        onChanged: context.read<ProjectCubit>().updateName,
                      ),
                      const SizedBox(height: 22),
                      const _PanelHeading(number: '02', title: 'SITE'),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _NumberInput(
                              label: 'Width',
                              value: requirements.site.width,
                              suffix: 'm',
                              onChanged: (value) => _site(
                                context,
                                requirements.site.copyWith(width: value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _NumberInput(
                              label: 'Depth',
                              value: requirements.site.depth,
                              suffix: 'm',
                              onChanged: (value) => _site(
                                context,
                                requirements.site.copyWith(depth: value),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<StreetSide>(
                        initialValue: requirements.site.streetSide,
                        decoration: const InputDecoration(
                          labelText: 'Street side',
                        ),
                        items: StreetSide.values
                            .map(
                              (side) => DropdownMenuItem(
                                value: side,
                                child: Text(_capitalized(side.name)),
                              ),
                            )
                            .toList(),
                        onChanged: (side) {
                          if (side != null) {
                            _site(
                              context,
                              requirements.site.copyWith(streetSide: side),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _NumberInput(
                              label: 'Front setback',
                              value: requirements.site.frontSetback,
                              suffix: 'm',
                              onChanged: (value) => _site(
                                context,
                                requirements.site.copyWith(frontSetback: value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _NumberInput(
                              label: 'Rear setback',
                              value: requirements.site.rearSetback,
                              suffix: 'm',
                              onChanged: (value) => _site(
                                context,
                                requirements.site.copyWith(rearSetback: value),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _NumberInput(
                              label: 'Left setback',
                              value: requirements.site.leftSetback,
                              suffix: 'm',
                              onChanged: (value) => _site(
                                context,
                                requirements.site.copyWith(leftSetback: value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _NumberInput(
                              label: 'Right setback',
                              value: requirements.site.rightSetback,
                              suffix: 'm',
                              onChanged: (value) => _site(
                                context,
                                requirements.site.copyWith(rightSetback: value),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const _PanelHeading(number: '03', title: 'BUILDING'),
                      const SizedBox(height: 12),
                      SegmentedButton<int>(
                        segments: const <ButtonSegment<int>>[
                          ButtonSegment(value: 1, label: Text('1 floor')),
                          ButtonSegment(value: 2, label: Text('2 floors')),
                        ],
                        selected: <int>{requirements.floorCount},
                        showSelectedIcon: false,
                        onSelectionChanged: (value) => context
                            .read<ProjectCubit>()
                            .updateFloorCount(value.first),
                      ),
                      const SizedBox(height: 8),
                      _OptionalNumberInput(
                        label: 'Maximum total area (optional)',
                        value: requirements.maximumTotalArea,
                        suffix: 'm²',
                        onChanged: context
                            .read<ProjectCubit>()
                            .updateMaximumArea,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: _PanelHeading(
                              number: '04',
                              title: 'ROOM PROGRAM',
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Add room requirement',
                            onPressed: context.read<ProjectCubit>().addRoom,
                            icon: const Icon(Icons.add, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverList.separated(
                  itemCount: requirements.rooms.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 7),
                  itemBuilder: (context, index) => _RoomRow(
                    room: requirements.rooms[index],
                    floorCount: requirements.floorCount,
                    canRemove: requirements.rooms.length > 1,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 23, 16, 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _PanelHeading(
                        number: '05',
                        title: 'SPATIAL PREFERENCES',
                      ),
                      const SizedBox(height: 8),
                      ...requirements.relationships.map(
                        (relationship) => SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            relationship.label,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          value: relationship.enabled,
                          activeTrackColor: AppColors.accent,
                          onChanged: (value) => context
                              .read<ProjectCubit>()
                              .toggleRelationship(relationship.id, value),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Area and dimension defaults are design heuristics—not building-code requirements.',
                        style: TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 10.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _site(BuildContext context, Site site) =>
      context.read<ProjectCubit>().updateSite(site);
  String _capitalized(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({required this.number, required this.title});
  final String number;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Text(
        number,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.05,
        ),
      ),
      const SizedBox(width: 9),
      const Expanded(child: Divider()),
    ],
  );
}

class _NumberInput extends StatelessWidget {
  const _NumberInput({
    required this.label,
    required this.value,
    required this.suffix,
    required this.onChanged,
  });
  final String label;
  final double value;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: value.toStringAsFixed(value % 1 == 0 ? 0 : 2),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, suffixText: suffix),
    onChanged: (text) {
      final parsed = double.tryParse(text.replaceAll(',', '.'));
      if (parsed != null) {
        onChanged(parsed);
      }
    },
  );
}

class _OptionalNumberInput extends StatelessWidget {
  const _OptionalNumberInput({
    required this.label,
    required this.value,
    required this.suffix,
    required this.onChanged,
  });
  final String label;
  final double? value;
  final String suffix;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: value?.toStringAsFixed(1) ?? '',
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, suffixText: suffix),
    onChanged: (text) => onChanged(
      text.trim().isEmpty ? null : double.tryParse(text.replaceAll(',', '.')),
    ),
  );
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.room,
    required this.floorCount,
    required this.canRemove,
  });
  final RoomRequirement room;
  final int floorCount;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 5, 9),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<RoomType>(
                      isDense: true,
                      isExpanded: true,
                      value: room.roomType,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      items: RoomType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (type) {
                        if (type != null) {
                          context.read<ProjectCubit>().updateRoom(
                            room.copyWith(
                              roomType: type,
                              targetArea: type.metadata.targetArea,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove room',
                  onPressed: canRemove
                      ? () => context.read<ProjectCubit>().removeRoom(room.id)
                      : null,
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: <Widget>[
                _Stepper(
                  value: room.count,
                  onChanged: (value) => context.read<ProjectCubit>().updateRoom(
                    room.copyWith(count: value),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: DropdownButtonFormField<PreferredFloor>(
                    initialValue: room.preferredFloor,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Floor',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 9,
                      ),
                    ),
                    items: PreferredFloor.values
                        .where(
                          (floor) =>
                              floorCount == 2 || floor != PreferredFloor.upper,
                        )
                        .map(
                          (floor) => DropdownMenuItem(
                            value: floor,
                            child: Text(
                              _floorLabel(floor),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (floor) {
                      if (floor != null) {
                        context.read<ProjectCubit>().updateRoom(
                          room.copyWith(preferredFloor: floor),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 7),
                SizedBox(
                  width: 75,
                  child: _NumberInput(
                    label: 'Target',
                    value: room.effectiveTargetArea,
                    suffix: 'm²',
                    onChanged: (value) => context
                        .read<ProjectCubit>()
                        .updateRoom(room.copyWith(targetArea: value)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _floorLabel(PreferredFloor floor) => switch (floor) {
    PreferredFloor.any => 'Any',
    PreferredFloor.ground => 'Ground',
    PreferredFloor.upper => 'Upper',
  };
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 39,
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InkWell(
          onTap: value > 1 ? () => onChanged(value - 1) : null,
          child: const SizedBox(width: 25, child: Icon(Icons.remove, size: 13)),
        ),
        Text(
          '$value×',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
        InkWell(
          onTap: value < 9 ? () => onChanged(value + 1) : null,
          child: const SizedBox(width: 25, child: Icon(Icons.add, size: 13)),
        ),
      ],
    ),
  );
}

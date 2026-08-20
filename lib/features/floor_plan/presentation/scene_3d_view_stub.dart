import 'package:flutter/material.dart';

import '../../../domain/building/architectural_scene_3d.dart';

class Scene3DView extends StatelessWidget {
  const Scene3DView({
    super.key,
    required this.scene,
    required this.selectedFloorIndex,
    required this.selectedRoomId,
    required this.onRoomSelected,
  });

  final ArchitecturalScene3D scene;
  final int selectedFloorIndex;
  final String? selectedRoomId;
  final void Function(String roomId, int floorIndex) onRoomSelected;

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFECEEEA),
    child: Center(
      child: Text(
        'The interactive 3D model is available in Flutter Web.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

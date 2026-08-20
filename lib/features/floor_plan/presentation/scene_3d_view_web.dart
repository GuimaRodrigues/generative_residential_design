import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';

import '../../../domain/building/architectural_scene_3d.dart';

@JS('Forma3DBridge.create')
external void _createViewer(
  JSObject container,
  JSString sceneJson,
  JSFunction onRoomSelected,
);

@JS('Forma3DBridge.update')
external void _updateViewer(JSObject container, JSString sceneJson);

@JS('Forma3DBridge.resetCamera')
external void _resetCamera(JSObject container);

@JS('Forma3DBridge.dispose')
external void _disposeViewer(JSObject container);

class Scene3DView extends StatefulWidget {
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
  State<Scene3DView> createState() => _Scene3DViewState();
}

class _Scene3DViewState extends State<Scene3DView> {
  JSObject? _container;
  late final JSFunction _roomSelectionCallback;
  Scene3DDisplayMode _displayMode = Scene3DDisplayMode.exterior;

  @override
  void initState() {
    super.initState();
    _roomSelectionCallback = ((JSString roomId, JSNumber floorIndex) {
      if (!mounted) return;
      widget.onRoomSelected(roomId.toDart, floorIndex.toDartInt);
    }).toJS;
  }

  @override
  void didUpdateWidget(covariant Scene3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final container = _container;
    if (container != null) _updateViewer(container, _sceneJson().toJS);
  }

  @override
  void dispose() {
    final container = _container;
    if (container != null) _disposeViewer(container);
    _container = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      Positioned.fill(
        child: HtmlElementView.fromTagName(
          tagName: 'div',
          onElementCreated: (element) {
            final container = element as JSObject;
            _container = container;
            _createViewer(container, _sceneJson().toJS, _roomSelectionCallback);
          },
        ),
      ),
      Positioned(
        right: 12,
        top: 12,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            border: Border.all(color: const Color(0xFFD7DCD8)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: IconButton(
            tooltip: 'Reset 3D camera',
            icon: const Icon(Icons.center_focus_strong, size: 18),
            onPressed: () {
              final container = _container;
              if (container != null) _resetCamera(container);
            },
          ),
        ),
      ),
      Positioned(
        right: 58,
        top: 12,
        child: SegmentedButton<Scene3DDisplayMode>(
          segments: const <ButtonSegment<Scene3DDisplayMode>>[
            ButtonSegment<Scene3DDisplayMode>(
              value: Scene3DDisplayMode.exterior,
              icon: Icon(Icons.home_work_outlined, size: 15),
              label: Text('EXTERIOR'),
            ),
            ButtonSegment<Scene3DDisplayMode>(
              value: Scene3DDisplayMode.cutaway,
              icon: Icon(Icons.layers_outlined, size: 15),
              label: Text('CUTAWAY'),
            ),
          ],
          selected: <Scene3DDisplayMode>{_displayMode},
          showSelectedIcon: false,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? const Color(0xFFD5E8E4)
                  : Colors.white.withValues(alpha: 0.94);
            }),
            visualDensity: VisualDensity.compact,
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
            ),
          ),
          onSelectionChanged: (selection) {
            setState(() => _displayMode = selection.single);
            final container = _container;
            if (container != null) {
              _updateViewer(container, _sceneJson().toJS);
            }
          },
        ),
      ),
      Positioned(
        left: 12,
        bottom: 10,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xDDF7F8F5)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Text(
                _displayMode == Scene3DDisplayMode.exterior
                    ? 'Exterior model · Drag to orbit · Scroll to zoom'
                    : 'Cutaway model · Select a room to inspect',
                style: const TextStyle(fontSize: 9.5, color: Color(0xFF58676A)),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  String _sceneJson() => jsonEncode(
    widget.scene.toJson(
      selectedFloorIndex: widget.selectedFloorIndex,
      selectedRoomId: widget.selectedRoomId,
      displayMode: _displayMode,
    ),
  );
}

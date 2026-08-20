import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generative_residential_design/app/app.dart';

void main() {
  testWidgets('workspace loads the editable sample project', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GenerativeResidentialDesignApp());
    await tester.pump();

    expect(find.text('FORMA'), findsOneWidget);
    expect(find.text('Courtyard House Study'), findsOneWidget);
    expect(find.text('GENERATE'), findsOneWidget);
    expect(find.text('Ready to generate'), findsOneWidget);
  });

  testWidgets('sample project generates and selects a conceptual plan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GenerativeResidentialDesignApp());
    await tester.pump();
    await tester.tap(find.text('GENERATE'));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    expect(find.text('CANDIDATE 1'), findsOneWidget);
    expect(find.text('GROUND FLOOR'), findsOneWidget);
    expect(find.textContaining('valid designs'), findsOneWidget);

    await tester.tap(find.text('3D'));
    await tester.pumpAndSettle();
    expect(
      find.text('The interactive 3D model is available in Flutter Web.'),
      findsOneWidget,
    );
  });

  testWidgets('seed editing preserves focus while updating', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GenerativeResidentialDesignApp());
    await tester.pump();
    final seedField = find.byKey(
      const ValueKey<String>('generation-seed-field'),
    );
    await tester.tap(seedField);
    await tester.enterText(seedField, '123456');
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(of: seedField, matching: find.byType(EditableText)),
    );
    expect(editable.controller.text, '123456');
    expect(editable.focusNode.hasFocus, isTrue);
  });
}

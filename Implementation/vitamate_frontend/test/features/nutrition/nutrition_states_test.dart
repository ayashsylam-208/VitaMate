import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/core/theme/vitamate_theme.dart';
import 'package:vitamate/features/nutrition/models/nutrition_summary.dart';
import 'package:vitamate/features/nutrition/screens/nutrition_dashboard_screen.dart';
import 'package:vitamate/features/nutrition/state/nutrition_controller.dart';
import 'package:vitamate/features/nutrition/widgets/nutrition_reference_ui.dart';

void main() {
  testWidgets('dashboard renders its initial loading state', (tester) async {
    final controller = NutritionController()..loading = true;
    addTearDown(controller.dispose);

    await _pumpDashboard(tester, controller);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('dashboard renders an inline retryable error state', (
    tester,
  ) async {
    final controller = NutritionController()
      ..error = 'Nutrition is temporarily unavailable.';
    addTearDown(controller.dispose);

    await _pumpDashboard(tester, controller);

    expect(find.text('Nutrition is temporarily unavailable.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('dashboard renders the empty meals state without fake values', (
    tester,
  ) async {
    final controller = NutritionController();
    addTearDown(controller.dispose);

    await _pumpDashboard(tester, controller);

    expect(
      find.text('No meals yet. Start with a quick log or scan.'),
      findsOneWidget,
    );
    expect(find.text('0 kcal'), findsNothing);
  });

  testWidgets('daily summary visibly updates calorie progress', (tester) async {
    final controller = NutritionController()
      ..summary = const NutritionSummary(
        targetCalories: 1589,
        consumedCalories: 151,
        burnedCalories: 0,
        remainingCalories: 1438,
        points: 0,
        progressPercent: 9.5,
        status: 'low',
      );
    addTearDown(controller.dispose);

    await _pumpDashboard(tester, controller);

    expect(find.text('10%'), findsOneWidget);
    expect(find.text('10% of goal'), findsOneWidget);

    controller.summary = const NutritionSummary(
      targetCalories: 1589,
      consumedCalories: 795,
      burnedCalories: 0,
      remainingCalories: 794,
      points: 0,
      progressPercent: 50,
      status: 'low',
    );
    controller.notifyListeners();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('50%'), findsOneWidget);
    expect(find.text('50% of goal'), findsOneWidget);
  });

  testWidgets('compact outline action does not overflow', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 140,
              child: NutritionOutlineButton(
                label: 'Retake Photo',
                icon: Icons.photo_camera_outlined,
                onTap: null,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Retake Photo'), findsOneWidget);
  });
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  NutritionController controller,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: VitaMateTheme.light(),
      home: NutritionScreen(controller: controller, autoLoad: false),
    ),
  );
  await tester.pump();
}

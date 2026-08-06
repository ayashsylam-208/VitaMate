import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/core/theme/vitamate_theme.dart';
import 'package:vitamate/features/nutrition/models/food_item.dart';
import 'package:vitamate/features/nutrition/screens/food_library_screen.dart';
import 'package:vitamate/features/nutrition/state/nutrition_controller.dart';

void main() {
  testWidgets('food library requests the next offset page', (tester) async {
    final controller = _FoodLibraryController();
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    expect(controller.offsets, <int>[0]);
    expect(find.text('Catalog food 1'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -5000));
    await tester.pumpAndSettle();

    expect(controller.offsets, contains(24));
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Catalog food 30'), findsOneWidget);
  });

  testWidgets('favorite icon rolls back when the API fails', (tester) async {
    final controller = _FoodLibraryController(failFavorite: true);
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    final addFavorite = find.byTooltip('Add favorite').first;
    await tester.tap(addFavorite);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add favorite'), findsWidgets);
    expect(find.byTooltip('Remove favorite'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FoodLibraryController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: VitaMateTheme.light(),
      home: FoodLibraryScreen(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
}

class _FoodLibraryController extends NutritionController {
  _FoodLibraryController({this.failFavorite = false});

  final bool failFavorite;
  final List<int> offsets = <int>[];
  final List<FoodItem> catalog = List<FoodItem>.generate(
    30,
    (index) => FoodItem(
      id: index + 1,
      name: 'Catalog food ${index + 1}',
      category: 'Lunch',
      calories100g: 100 + index,
      protein100g: 5,
      carbs100g: 12,
      fat100g: 3,
      servingLabel: '100 g',
      servingGrams: 100,
    ),
  );

  @override
  Future<List<FoodItem>> searchFoods({
    required String mealType,
    String query = '',
    String? category,
    int limit = 12,
    int offset = 0,
    bool includeMealSlot = true,
  }) async {
    offsets.add(offset);
    return catalog.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<List<FoodItem>> getFavoriteFoods() async => const <FoodItem>[];

  @override
  Future<bool> setFoodFavorite({
    required int foodId,
    required bool isFavorite,
  }) async {
    if (failFavorite) throw StateError('offline');
    return isFavorite;
  }
}

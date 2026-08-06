import 'package:flutter_test/flutter_test.dart';
import 'package:vitamate/features/nutrition/data/ai_meal_api.dart';
import 'package:vitamate/features/nutrition/models/ai_meal_analysis.dart';
import 'package:vitamate/features/nutrition/models/food_item.dart';
import 'package:vitamate/features/nutrition/models/meal_log.dart';
import 'package:vitamate/features/nutrition/state/ai_meal_controller.dart';

class _FakeAiMealApi extends AiMealApi {
  _FakeAiMealApi({required this.analysis});

  AiMealAnalysis analysis;
  Object? analyzeError;
  Object? finalizeError;
  final List<String> analyzeKeys = <String>[];
  final List<String> finalizeKeys = <String>[];

  @override
  Future<AiMealAnalysis> analyze({
    required String imagePath,
    required String idempotencyKey,
    String autoWeightMode = 'try',
  }) async {
    analyzeKeys.add(idempotencyKey);
    if (analyzeError != null) throw analyzeError!;
    return analysis;
  }

  @override
  Future<AiMealAnalysis> confirm({
    required AiMealAnalysis analysis,
    required String selectedDishLabel,
    required String selectedDishId,
    required String mealType,
    required DateTime consumedAt,
    required List<AiMealComponent> components,
  }) async {
    this.analysis = _analysis(status: 'ready_to_finalize', confidence: 0.9);
    return this.analysis;
  }

  @override
  Future<AiMealFinalizeResult> finalize({
    required String analysisId,
    required String idempotencyKey,
    String notes = '',
  }) async {
    finalizeKeys.add(idempotencyKey);
    final failure = finalizeError;
    finalizeError = null;
    if (failure != null) throw failure;
    return AiMealFinalizeResult(
      meal: MealLog(
        id: 44,
        foodId: null,
        foodName: 'Chicken bowl',
        isComposite: true,
        source: 'ai',
        mealType: 'lunch',
        quantityGrams: 300,
        quantity: 300,
        unit: 'g',
        caloriesKcal: 480,
        proteinG: 32,
        carbsG: 50,
        fatG: 12,
      ),
      summary: const <String, dynamic>{},
      points: const <String, dynamic>{'total_points': 20},
      nutritionSummary: const <String, dynamic>{'calories_kcal': 480},
      pointsDelta: 15,
    );
  }
}

AiMealAnalysis _analysis({
  String status = 'review',
  double confidence = 0.9,
  List<AiMealComponent>? components,
}) => AiMealAnalysis(
  id: 'analysis-1',
  status: status,
  imageUrl: '/media/analysis.jpg',
  selectedDishId: 'chicken_bowl',
  selectedDishLabel: 'Chicken bowl',
  estimatedWeightGrams: 300,
  mealType: 'lunch',
  candidates: <AiMealCandidate>[
    AiMealCandidate(
      id: 1,
      kind: 'dish',
      providerId: 'chicken_bowl',
      label: 'Chicken bowl',
      arabicLabel: '',
      confidence: confidence,
      mappedFoodItemId: null,
      mappedFoodName: '',
    ),
  ],
  components:
      components ??
      const <AiMealComponent>[
        AiMealComponent(
          id: 10,
          providerId: 'chicken',
          providerLabel: 'Chicken',
          mappedFoodItemId: 7,
          mappedFoodName: 'Chicken',
          confidence: 0.9,
          suggestedGrams: 150,
          confirmedGrams: 150,
          isIncluded: true,
          isUserConfirmed: true,
        ),
      ],
  maskPreview: const <String, dynamic>{},
  userMessage: 'Review the result',
  weightStatus: 'ok',
  weightMessage: '',
  weightEstimationAttempted: true,
  failureMessage: '',
  expiresAt: DateTime(2030),
  finalizeAllowed: true,
  requiredUserInputs: const <String>[],
  modelVersions: const <String, dynamic>{'dish': 'test-v1'},
);

void main() {
  test('analyze moves through upload and analysis into review', () async {
    final api = _FakeAiMealApi(analysis: _analysis());
    final controller = AiMealController(api: api);
    final states = <AiMealFlowStatus>[];
    controller.addListener(() => states.add(controller.state));

    controller.beginCapture();
    final succeeded = await controller.analyze('meal.png');

    expect(succeeded, isTrue);
    expect(controller.state, AiMealFlowStatus.reviewing);
    expect(
      states,
      containsAllInOrder(<AiMealFlowStatus>[
        AiMealFlowStatus.capturing,
        AiMealFlowStatus.uploading,
        AiMealFlowStatus.analyzing,
        AiMealFlowStatus.reviewing,
      ]),
    );
    expect(api.analyzeKeys.single, startsWith('capture-'));
  });

  test('expired provider result becomes an explicit expired state', () async {
    final controller = AiMealController(
      api: _FakeAiMealApi(analysis: _analysis(status: 'expired')),
    );

    expect(await controller.analyze('meal.png'), isTrue);
    expect(controller.state, AiMealFlowStatus.expired);
  });

  test('mapping and weight edits update the nutrition preview', () {
    final controller = AiMealController()
      ..analysis = _analysis()
      ..state = AiMealFlowStatus.reviewing;
    addTearDown(controller.dispose);
    const fries = FoodItem(
      id: 971,
      name: 'french fries',
      calories100g: 312,
      protein100g: 3.4,
      carbs100g: 41,
      fat100g: 15,
      servingLabel: '100 g',
      servingGrams: 100,
    );

    controller.mapComponent(10, fries);

    var component = controller.analysis!.components.single;
    expect(component.mappedFoodItemId, fries.id);
    expect(component.estimatedNutrition['calories_kcal'], 468);

    controller.updateComponentGrams(10, 200);

    component = controller.analysis!.components.single;
    expect(component.estimatedNutrition['calories_kcal'], 624);
    expect(component.estimatedNutrition['carbs_g'], 82);
  });

  test('total meal weight is distributed by component percentage', () {
    final controller = AiMealController()
      ..analysis = _analysis(
        components: const <AiMealComponent>[
          AiMealComponent(
            id: 10,
            providerId: 'rice',
            providerLabel: 'Rice',
            mappedFoodItemId: 1,
            mappedFoodName: 'Rice',
            confidence: 0.9,
            suggestedPercentage: 0.6,
            suggestedGrams: null,
            confirmedGrams: null,
            isIncluded: true,
            isUserConfirmed: false,
          ),
          AiMealComponent(
            id: 11,
            providerId: 'chicken',
            providerLabel: 'Chicken',
            mappedFoodItemId: 2,
            mappedFoodName: 'Chicken',
            confidence: 0.8,
            suggestedPercentage: 0.4,
            suggestedGrams: null,
            confirmedGrams: null,
            isIncluded: true,
            isUserConfirmed: false,
          ),
        ],
      )
      ..state = AiMealFlowStatus.reviewing;
    addTearDown(controller.dispose);

    controller.updateTotalGrams(300);

    expect(controller.analysis!.components[0].confirmedGrams, 180);
    expect(controller.analysis!.components[1].confirmedGrams, 120);
    expect(controller.analysis!.needsManualWeights, isFalse);
    expect(controller.analysis!.estimatedWeightGrams, 300);
  });

  test(
    'low confidence dish blocks confirmation until explicitly selected',
    () async {
      final analysis = _analysis(confidence: 0.4);
      final controller = AiMealController(
        api: _FakeAiMealApi(analysis: analysis),
      );
      await controller.analyze('meal.png');

      expect(controller.requiresDishChoice, isTrue);
      expect(
        await controller.confirm(
          dishLabel: 'Chicken bowl',
          dishId: 'chicken_bowl',
          mealType: 'lunch',
          consumedAt: DateTime(2026, 8, 3),
        ),
        isFalse,
      );

      controller.selectDish(analysis.candidates.single);
      expect(controller.dishChoiceConfirmed, isTrue);
    },
  );

  test('finalize retries with one stable idempotency key', () async {
    final api = _FakeAiMealApi(analysis: _analysis(status: 'ready_to_finalize'))
      ..finalizeError = const FormatException('Malformed response');
    final controller = AiMealController(api: api);
    await controller.analyze('meal.png');

    expect(await controller.finalize(), isFalse);
    expect(controller.state, AiMealFlowStatus.failure);
    expect(await controller.finalize(), isTrue);
    expect(controller.state, AiMealFlowStatus.success);
    expect(controller.result?.meal.id, 44);
    expect(api.finalizeKeys, hasLength(2));
    expect(api.finalizeKeys.first, api.finalizeKeys.last);
  });
}

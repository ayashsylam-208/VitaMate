import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vitamate/app.dart';
import 'package:vitamate/core/network/http_client.dart';
import 'package:vitamate/features/chronic_conditions/data/chronic_conditions_api.dart';

class VitamateTestHarness implements HttpClientAdapter {
  VitamateTestHarness({this.staleEmptyHomeOverview = false});

  final bool staleEmptyHomeOverview;

  final List<String> _requestLog = <String>[];
  final Map<String, dynamic> _user = _sampleUser();
  final List<Map<String, dynamic>> _foods = _sampleFoods();
  final List<Map<String, dynamic>> _meals = _sampleMeals();
  final List<Map<String, dynamic>> _waterLogs = _sampleWaterLogs();
  final List<Map<String, dynamic>> _sleepLogs = _sampleSleepLogs();
  final List<Map<String, dynamic>> _activityLogs = _sampleActivityLogs();
  final List<Map<String, dynamic>> _exercises = _sampleExercises();
  final List<Map<String, dynamic>> _medications = _sampleMedications();
  final List<Map<String, dynamic>> _todayPlan = _sampleMedicationTodayPlan();
  final List<Map<String, dynamic>> _supportedConditionTypes =
      _sampleSupportedConditionTypes();
  final List<Map<String, dynamic>> _overviewConditions = <Map<String, dynamic>>[
    _sampleCompactCondition(),
  ];

  int _nextFoodId = 400;
  int _nextMealId = 900;
  int _nextWaterLogId = 300;
  int _nextSleepId = 80;
  int _nextActivityId = 30;

  List<String> get requestLog => List<String>.unmodifiable(_requestLog);

  int requestCount(String method, String uriFragment) {
    final expectedPrefix = '${method.toUpperCase()} ';
    return _requestLog
        .where(
          (entry) =>
              entry.startsWith(expectedPrefix) && entry.contains(uriFragment),
        )
        .length;
  }

  Future<void> bootstrap({
    bool stepsPermissionGranted = true,
    Map<String, Object> sharedPreferences = const <String, Object>{},
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(sharedPreferences);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async {
        final granted = stepsPermissionGranted ? 1 : 0;
        switch (call.method) {
          case 'checkPermissionStatus':
            return granted;
          case 'requestPermissions':
            return <int, int>{call.arguments.first as int: granted};
          default:
            return null;
        }
      },
    );
    messenger.setMockMessageHandler(
      'dev.flutter.pedometer.event',
      (message) async => null,
    );

    ChronicConditionsApi.invalidateOverviewCache();
    HttpClient.initForTesting();
    HttpClient.setTestAdapter(this);
  }

  Future<void> pumpAppRoute(
    WidgetTester tester, {
    required String initialRoute,
    Map<String, WidgetBuilder> routeOverrides = const <String, WidgetBuilder>{},
  }) async {
    await tester.pumpWidget(
      VitaMateApp(initialRoute: initialRoute, routeOverrides: routeOverrides),
    );
  }

  Future<void> settleApp(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = _canonicalUri(options.uri);
    _requestLog.add('${options.method.toUpperCase()} $uri');

    final method = options.method.toUpperCase();
    final path = options.path;
    final query = options.uri.queryParameters;
    final data = _asMap(options.data);

    if (method == 'GET' && path == '/api/health/') {
      return _json(200, const <String, dynamic>{'status': 'ok'});
    }
    if (method == 'GET' && path == '/api/auth/me/') {
      return _json(200, _userResponse());
    }
    if (method == 'PATCH' && path == '/api/auth/me/') {
      _mergeUserPatch(data);
      return _json(200, _userResponse());
    }

    if (method == 'GET' && path == '/api/home/overview/') {
      return _json(
        200,
        _envelope(
          staleEmptyHomeOverview
              ? _emptyHomeOverviewData()
              : _homeOverviewData(),
          isStale: staleEmptyHomeOverview,
        ),
      );
    }
    if (method == 'GET' && path == '/api/dashboard/') {
      return _json(200, _progressOverviewData());
    }
    if (method == 'GET' && path == '/api/progress/overview/') {
      return _json(200, _envelope(_progressOverviewData()));
    }
    if (method == 'GET' && path == '/api/progress/history/') {
      return _json(
        200,
        _envelope(<String, dynamic>{'history': _historyData()}),
      );
    }
    if (method == 'GET' && path.startsWith('/api/progress/details/')) {
      final tracker = path
          .replaceFirst('/api/progress/details/', '')
          .replaceAll('/', '');
      return _json(200, _envelope(_progressDetailData(tracker)));
    }

    if (method == 'GET' && path == '/api/nutrition/summary/') {
      return _json(200, _envelope(_nutritionSummaryData()));
    }
    if (method == 'GET' && path == '/api/nutrition/micronutrients/') {
      return _json(200, _envelope(_micronutrientData()));
    }
    if (method == 'POST' && path == '/api/nutrition/micronutrients/targets/') {
      return _json(201, _envelope(_micronutrientData(deficiencyTracked: true)));
    }
    if (method == 'GET' && path == '/api/meals/') {
      return _json(200, _meals);
    }
    if (method == 'POST' && path == '/api/meals/') {
      _createMeal(data);
      return _json(201, const <String, dynamic>{});
    }

    if (method == 'GET' &&
        (path == '/api/foods/' || path == '/api/foods/autocomplete/')) {
      return _json(200, _filterFoods(query));
    }
    if (method == 'POST' && path == '/api/foods/') {
      _createFood(data);
      return _json(201, const <String, dynamic>{});
    }

    if (method == 'GET' && path == '/api/hydration/summary/') {
      return _json(200, _envelope(_hydrationSummaryData()));
    }
    if (method == 'GET' && path == '/api/water/') {
      return _json(200, _waterLogs);
    }
    if (method == 'POST' && path == '/api/water/') {
      _createWaterLog(data);
      return _json(201, const <String, dynamic>{});
    }

    if (method == 'GET' && path == '/api/activity/summary/') {
      return _json(200, _envelope(_activitySummaryData()));
    }
    if (method == 'GET' && path == '/api/exercises/') {
      return _json(200, _exercises);
    }
    if (method == 'GET' && path == '/api/activities/') {
      return _json(200, _activityLogs);
    }
    if (method == 'POST' && path == '/api/activities/') {
      _createActivity(data);
      return _json(201, const <String, dynamic>{});
    }

    if (method == 'GET' && path == '/api/steps/summary/') {
      return _json(200, _envelope(_stepsSummaryData()));
    }
    if (method == 'POST' && path == '/api/steps/') {
      _updateSteps(data);
      return _json(201, const <String, dynamic>{});
    }

    if (method == 'GET' && path == '/api/sleep/summary/') {
      return _json(200, _envelope(_sleepSummaryData()));
    }
    if (method == 'GET' && path == '/api/sleep/') {
      return _json(200, _sleepLogs);
    }
    if (method == 'POST' && path == '/api/sleep/') {
      _createSleepLog(data);
      return _json(201, const <String, dynamic>{});
    }

    if (method == 'GET' && path == '/api/medications/overview/') {
      return _json(200, _medicationsOverviewData());
    }
    if (method == 'GET' && path == '/api/medications/today/') {
      return _json(200, _todayPlan);
    }

    if (method == 'GET' && path == '/api/chronic/overview/') {
      return _json(
        200,
        _envelope(<String, dynamic>{'conditions': _overviewConditions}),
      );
    }
    if (method == 'GET' && path == '/api/chronic/condition-types/supported/') {
      return _json(200, _supportedConditionTypes);
    }

    return _json(404, const <String, dynamic>{});
  }

  ResponseBody _json(int statusCode, Object body) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  String _canonicalUri(Uri uri) {
    final keys = uri.queryParameters.keys.toList()..sort();
    final parts = <String>[];
    for (final key in keys) {
      parts.add('$key=${uri.queryParameters[key]}');
    }
    if (parts.isEmpty) {
      return uri.path;
    }
    return '${uri.path}?${parts.join('&')}';
  }

  Map<String, dynamic> _envelope(
    Map<String, dynamic> data, {
    bool isStale = false,
  }) {
    return <String, dynamic>{
      'data': data,
      'meta': <String, dynamic>{
        'is_stale': isStale,
        'computed_at': isStale ? null : '2026-04-28T12:00:00Z',
        'snapshot_version': 1,
        'request_id': 'test-request',
      },
    };
  }

  Map<String, dynamic> _userResponse() {
    return <String, dynamic>{
      ..._user,
      'profile': <String, dynamic>{..._user},
    };
  }

  void _mergeUserPatch(Map<String, dynamic> payload) {
    for (final entry in payload.entries) {
      if (entry.value != null) {
        _user[entry.key] = entry.value;
      }
    }
  }

  Map<String, dynamic> _homeOverviewData() {
    return <String, dynamic>{
      'points': 130,
      'today_steps': 5120,
      'water_ml': 1200,
      'sleep_minutes': 435,
      'calories': _nutritionSummaryData()['consumed_calories'],
      'chronic_conditions': <String, dynamic>{
        'count': 1,
        'labels': const <String>['Diabetes'],
        'adherence_percent': 92,
        'active_medications_today': 1,
        'pending_doses_today': 1,
        'applied_summaries': const <String>[
          'Keep added sugar under 25 g per day.',
        ],
        'disclaimer': 'Supportive self-management only.',
      },
      'conditions_center': _overviewConditions,
    };
  }

  Map<String, dynamic> _emptyHomeOverviewData() {
    return <String, dynamic>{
      'points': 0,
      'today_steps': 0,
      'water_ml': 0,
      'sleep_minutes': 0,
      'calories': 0,
      'chronic_conditions': <String, dynamic>{
        'count': 0,
        'labels': const <String>[],
        'adherence_percent': 0,
        'active_medications_today': 0,
        'pending_doses_today': 0,
        'applied_summaries': const <String>[],
        'disclaimer': '',
      },
      'conditions_center': _overviewConditions,
    };
  }

  Map<String, dynamic> _progressOverviewData() {
    return <String, dynamic>{
      'summary': <String, dynamic>{
        'calories_target': 2100,
        'calories_consumed': _nutritionSummaryData()['consumed_calories'],
        'calories_remaining':
            2100 - _toInt(_nutritionSummaryData()['consumed_calories']),
        'calories_burned': 320,
        'protein_g': _nutritionSummaryData()['protein_g'],
        'carbs_g': _nutritionSummaryData()['carbs_g'],
        'fat_g': _nutritionSummaryData()['fat_g'],
        'sugars_g': _nutritionSummaryData()['sugars_g'],
        'fiber_g': _nutritionSummaryData()['fiber_g'],
        'caffeine_mg': _nutritionSummaryData()['caffeine_mg'],
        'burn_target': 500,
      },
      'hydration': <String, dynamic>{'target': 2.3, 'current': 1.2},
      'sleep': <String, dynamic>{
        'recommended_sleep_hours': 8.0,
        'logged_hours_today': 7.25,
      },
      'activity': <String, dynamic>{'steps_target': 8000, 'steps': 5120},
      'gamification': <String, dynamic>{'points': 130, 'level': 3},
      'chronic_conditions': <String, dynamic>{
        'count': 1,
        'pending_doses_today': 1,
        'adherence_percent': 92,
        'applied_summaries': const <String>[
          'Added sugar limit applies to beverages and meals.',
        ],
        'disclaimer': 'Supportive self-management only.',
      },
      'overall_score': 78,
      'points': 130,
      'level': 3,
      'weekly_consistency': <String, dynamic>{
        'days_met': 5,
        'total_days': 7,
        'percent': 71,
      },
      'tracker_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'code': 'nutrition',
          'title': 'Nutrition',
          'percent': 85,
          'current': 1780,
          'target': 2100,
          'status': 'Good',
          'summary': 'Meal quality good',
          'detail_endpoint': '/api/progress/details/nutrition/',
        },
        <String, dynamic>{
          'code': 'hydration',
          'title': 'Water',
          'percent': 52,
          'current': 1.2,
          'target': 2.3,
          'status': 'Building',
          'summary': '1.2 / 2.3 L',
          'detail_endpoint': '/api/progress/details/hydration/',
        },
        <String, dynamic>{
          'code': 'activity',
          'title': 'Activity',
          'percent': 64,
          'current': 320,
          'target': 500,
          'status': 'On track',
          'summary': '320 kcal burned',
          'detail_endpoint': '/api/progress/details/activity/',
        },
        <String, dynamic>{
          'code': 'steps',
          'title': 'Steps',
          'percent': 64,
          'current': 5120,
          'target': 8000,
          'status': 'On track',
          'summary': '5120 / 8000 steps',
          'detail_endpoint': '/api/progress/details/steps/',
        },
        <String, dynamic>{
          'code': 'sleep',
          'title': 'Sleep',
          'percent': 91,
          'current': 7.25,
          'target': 8.0,
          'status': 'Good',
          'summary': '7.3 / 8.0 h',
          'detail_endpoint': '/api/progress/details/sleep/',
        },
      ],
      'timeline_7d': _historyData()
          .map(
            (item) => <String, dynamic>{
              'date': item['date'],
              'score': 78,
              'points': item['points_estimate'],
              'complete': true,
            },
          )
          .toList(growable: false),
      'insight': <String, dynamic>{
        'title': 'Insight',
        'message': 'Your consistency is improving.',
      },
    };
  }

  List<Map<String, dynamic>> _historyData() {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'date': '2026-04-27',
        'water_current': 1.8,
        'water_target': 2.3,
        'steps': 7200,
        'steps_target': 8000,
        'distance_km': 5.4,
        'calories_in': 1820,
        'calories_target': 2100,
        'calories_burned': 340,
        'protein_g': 96,
        'carbs_g': 180,
        'fat_g': 58,
        'sugars_g': 22,
        'fiber_g': 26,
        'caffeine_mg': 110,
        'burn_target': 500,
        'sleep_hours': 7.5,
        'sleep_target': 8.0,
        'exercise_minutes': 35,
        'points_estimate': 120,
        'condition_adherence_percent': 92,
        'pending_condition_doses': 1,
      },
    ];
  }

  Map<String, dynamic> _progressDetailData(String tracker) {
    final overview = _progressOverviewData();
    final summary = _asMap(overview['summary']);
    final hydration = _asMap(overview['hydration']);
    final sleep = _asMap(overview['sleep']);
    final activity = _asMap(overview['activity']);
    final percent = switch (tracker) {
      'hydration' => 52,
      'activity' => 64,
      'steps' => 64,
      'sleep' => 91,
      'medications' => 78,
      'chronic' => 92,
      'habits' => 65,
      _ => 85,
    };
    return <String, dynamic>{
      'tracker': tracker,
      'title': tracker,
      'score': percent,
      'status': 'Good',
      'range_days': 7,
      'summary_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'label': 'Current',
          'current': tracker == 'hydration'
              ? hydration['current']
              : tracker == 'sleep'
              ? sleep['logged_hours_today']
              : tracker == 'steps'
              ? activity['steps']
              : summary['calories_consumed'],
          'target': tracker == 'hydration'
              ? hydration['target']
              : tracker == 'sleep'
              ? sleep['recommended_sleep_hours']
              : tracker == 'steps'
              ? activity['steps_target']
              : summary['calories_target'],
          'unit': tracker == 'steps'
              ? 'steps'
              : tracker == 'hydration'
              ? 'L'
              : tracker == 'sleep'
              ? 'h'
              : 'kcal',
          'percent': percent,
        },
      ],
      'metrics': <Map<String, dynamic>>[
        <String, dynamic>{
          'label': 'Progress',
          'current': percent,
          'target': 100,
          'unit': '%',
          'percent': percent,
          'limit': false,
          'status': 'Good',
        },
      ],
      'trend': _historyData()
          .map(
            (day) => <String, dynamic>{
              'date': day['date'],
              'value': percent,
              'target': 100,
              'percent': percent,
              'points': day['points_estimate'],
            },
          )
          .toList(growable: false),
      'sections': const <Map<String, dynamic>>[],
      'insight': 'Progress detail loaded lazily.',
    };
  }

  Map<String, dynamic> _nutritionSummaryData() {
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    double sugars = 0;
    double addedSugars = 0;
    double fiber = 0;
    double caffeine = 0;

    for (final meal in _meals) {
      calories += _toDouble(meal['snapshot_calories_kcal']);
      protein += _toDouble(meal['snapshot_protein_g']);
      carbs += _toDouble(meal['snapshot_carbohydrates_g']);
      fat += _toDouble(meal['snapshot_fat_g']);
      sugars += _toDouble(meal['snapshot_sugars_g']);
      addedSugars += _toDouble(meal['snapshot_added_sugars_g']);
      fiber += _toDouble(meal['snapshot_fiber_g']);
      caffeine += _toDouble(meal['snapshot_caffeine_mg']);
    }

    final consumedCalories = calories.round();
    return <String, dynamic>{
      'target_calories': 2100,
      'consumed_calories': consumedCalories,
      'burned_calories': 320,
      'remaining_calories': (2100 - consumedCalories).clamp(0, 2100),
      'points': _meals.length * 5,
      'protein_g': protein,
      'carbs_g': carbs,
      'fat_g': fat,
      'sugars_g': sugars,
      'added_sugars_g': addedSugars,
      'fiber_g': fiber,
      'caffeine_mg': caffeine,
    };
  }

  Map<String, dynamic> _micronutrientData({bool deficiencyTracked = false}) {
    return <String, dynamic>{
      'date': '2026-05-06',
      'disclaimer': 'Micronutrient tracking is informational.',
      'items': <Map<String, dynamic>>[
        {
          'code': 'calcium_mg',
          'name': 'Calcium',
          'unit': 'mg',
          'category': 'mineral',
          'food_consumed': 120.0,
          'supplement_consumed': 0.0,
          'total_consumed': 120.0,
          'min_value': null,
          'target_value': 1000.0,
          'max_value': null,
          'progress_percent': 12.0,
          'target_source': 'profile_derived_default',
          'source_label': 'Default',
          'deficiency_tracked': false,
          'status': 'in_progress',
          'note': '',
          'linked_medication': null,
        },
        {
          'code': 'vitamin_d_mcg',
          'name': 'Vitamin D',
          'unit': 'mcg',
          'category': 'vitamin',
          'food_consumed': 2.0,
          'supplement_consumed': deficiencyTracked ? 25.0 : 0.0,
          'total_consumed': deficiencyTracked ? 27.0 : 2.0,
          'min_value': null,
          'target_value': 15.0,
          'max_value': null,
          'progress_percent': deficiencyTracked ? 180.0 : 13.3,
          'target_source': deficiencyTracked
              ? 'manual'
              : 'profile_derived_default',
          'source_label': deficiencyTracked
              ? 'Deficiency target linked to supplement reminders.'
              : 'Default',
          'deficiency_tracked': deficiencyTracked,
          'status': deficiencyTracked ? 'met' : 'low',
          'note': deficiencyTracked ? 'Low vitamin D' : '',
          'linked_medication': deficiencyTracked
              ? <String, dynamic>{
                  'id': 10,
                  'display_name': 'Vitamin D',
                  'dose_amount': '25',
                  'dose_unit': 'mcg',
                  'is_active': true,
                }
              : null,
        },
      ],
    };
  }

  List<Map<String, dynamic>> _filterFoods(Map<String, String> query) {
    var results = List<Map<String, dynamic>>.from(_foods);
    final itemType = query['item_type']?.trim().toLowerCase();
    final category = query['category']?.trim().toLowerCase();
    final mealSlot = query['meal_slot']?.trim().toLowerCase();
    final search = query['q']?.trim().toLowerCase() ?? '';

    if (itemType != null && itemType.isNotEmpty) {
      results = results
          .where(
            (item) => item['item_type'].toString().toLowerCase() == itemType,
          )
          .toList();
    }
    if (category != null && category.isNotEmpty) {
      results = results.where((item) {
        final itemCategory = (item['category'] ?? '').toString().toLowerCase();
        return itemCategory == category;
      }).toList();
    }
    if (mealSlot != null && mealSlot.isNotEmpty) {
      results = results.where((item) {
        final tags = (item['meal_tags'] ?? '').toString().toLowerCase();
        return tags.split(',').map((tag) => tag.trim()).contains(mealSlot);
      }).toList();
    }
    if (search.isNotEmpty) {
      results = results.where((item) {
        final name = item['name'].toString().toLowerCase();
        final itemCategory = (item['category'] ?? '').toString().toLowerCase();
        return name.contains(search) || itemCategory.contains(search);
      }).toList();
    }

    final limit = int.tryParse(query['limit'] ?? '');
    if (limit != null && limit > 0 && results.length > limit) {
      results = results.take(limit).toList();
    }
    return results;
  }

  void _createFood(Map<String, dynamic> payload) {
    final servingGrams = _toInt(payload['serving_grams']);
    final item = <String, dynamic>{
      'id': _nextFoodId++,
      'name': payload['name']?.toString() ?? 'Custom food',
      'item_type': 'food',
      'category': 'Custom',
      'calories_100g': _toInt(payload['calories_100g']),
      'protein_100g': _toDouble(payload['protein_100g']),
      'carbs_100g': _toDouble(payload['carbs_100g']),
      'fat_100g': _toDouble(payload['fat_100g']),
      'default_serving_size': servingGrams,
      'default_serving_unit': 'g',
      'serving_label': payload['serving_label']?.toString() ?? 'Serving',
      'serving_grams': servingGrams <= 0 ? 200 : servingGrams,
      'serving_options': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': _nextFoodId + 1000,
          'name': payload['serving_label']?.toString() ?? 'Serving',
          'amount': 1,
          'unit': 'serving',
          'grams_equivalent': servingGrams <= 0 ? 200 : servingGrams,
          'is_default': true,
          'sort_order': 0,
        },
      ],
      'nutrition_facts': <String, dynamic>{
        'sugars_g': 0,
        'fiber_g': 0,
        'sodium_mg': 0,
        'water_g': 20,
        'caffeine_mg': 0,
      },
      'created_by': 1,
    };
    _foods.insert(0, item);
  }

  void _createMeal(Map<String, dynamic> payload) {
    final foodId = _toInt(payload['food']);
    final food = _foods.firstWhere(
      (item) => _toInt(item['id']) == foodId,
      orElse: () => _foods.first,
    );

    final unit = (payload['unit'] ?? '').toString();
    final quantity = _toDouble(payload['quantity']);
    final quantityGramsPayload = _toDouble(payload['quantity_grams']);
    final servingGramsEquivalent = _toDouble(
      payload['serving_grams_equivalent'],
    );
    final servingMillilitersEquivalent = _toDouble(
      payload['serving_milliliters_equivalent'],
    );

    double effectiveAmount = quantityGramsPayload;
    double servingsConsumed = 0;
    double millilitersConsumed = 0;

    if (unit == 'ml') {
      effectiveAmount = quantity;
      millilitersConsumed = quantity;
    } else if (unit == 'serving') {
      servingsConsumed = quantity;
      if (servingMillilitersEquivalent > 0) {
        effectiveAmount = servingMillilitersEquivalent * quantity;
        millilitersConsumed = effectiveAmount;
      } else if (servingGramsEquivalent > 0) {
        effectiveAmount = servingGramsEquivalent * quantity;
      } else {
        effectiveAmount = _toDouble(food['serving_grams']) * quantity;
      }
    }

    if (effectiveAmount <= 0) {
      effectiveAmount = quantity > 0
          ? quantity
          : _toDouble(food['serving_grams']);
    }

    final factor = effectiveAmount / 100.0;
    final nutritionFacts = _asMap(food['nutrition_facts']);
    _meals.insert(0, <String, dynamic>{
      'id': _nextMealId++,
      'food': foodId,
      'food_name': food['name'],
      'meal_type': payload['meal_type']?.toString() ?? 'breakfast',
      'quantity_grams': unit == 'ml' ? 0 : effectiveAmount,
      'quantity': quantity > 0 ? quantity : 1,
      'unit': unit.isEmpty ? 'g' : unit,
      'milliliters_consumed': millilitersConsumed,
      'servings_consumed': servingsConsumed,
      'serving_option': payload['serving_option'],
      'serving_option_name': payload['serving_label_snapshot'],
      'serving_label_snapshot': payload['serving_label_snapshot'],
      'consumed_at':
          payload['consumed_at']?.toString() ?? '2026-04-28T10:15:00Z',
      'snapshot_calories_kcal': _toDouble(food['calories_100g']) * factor,
      'snapshot_protein_g': _toDouble(food['protein_100g']) * factor,
      'snapshot_carbohydrates_g': _toDouble(food['carbs_100g']) * factor,
      'snapshot_fat_g': _toDouble(food['fat_100g']) * factor,
      'snapshot_sugars_g': _toDouble(nutritionFacts['sugars_g']) * factor,
      'snapshot_added_sugars_g': _toDouble(nutritionFacts['sugars_g']) * factor,
      'snapshot_fiber_g': _toDouble(nutritionFacts['fiber_g']) * factor,
      'snapshot_sodium_mg': _toDouble(nutritionFacts['sodium_mg']) * factor,
      'snapshot_saturated_fat_g': 0,
      'snapshot_trans_fat_g': 0,
      'snapshot_cholesterol_mg': 0,
      'snapshot_potassium_mg': 0,
      'snapshot_caffeine_mg': _toDouble(nutritionFacts['caffeine_mg']) * factor,
    });
  }

  Map<String, dynamic> _hydrationSummaryData() {
    final consumedMl = _waterLogs.fold<int>(
      0,
      (sum, item) => sum + _toInt(item['hydration_ml']),
    );
    return <String, dynamic>{
      'target_ml': 2300,
      'consumed_ml': consumedMl,
      'remaining_ml': (2300 - consumedMl).clamp(0, 2300),
      'progress_percent': ((consumedMl / 2300) * 100).round(),
    };
  }

  void _createWaterLog(Map<String, dynamic> payload) {
    final amountMl = _toInt(payload['amount_ml']);
    final beverageName = payload['beverage_name']?.toString();
    final beverageType = payload['beverage_type']?.toString().toLowerCase();
    final foodItemId = _toInt(payload['food_item']);
    final food = _foods.firstWhere(
      (item) => _toInt(item['id']) == foodItemId,
      orElse: () => const <String, dynamic>{},
    );
    final custom = _asMap(payload['custom_beverage']);
    final name = food.isNotEmpty
        ? food['name'].toString()
        : (beverageName?.isNotEmpty == true
              ? beverageName!
              : (custom['name']?.toString() ?? 'Beverage'));
    final type = food.isNotEmpty
        ? food['category'].toString().toLowerCase()
        : (beverageType?.isNotEmpty == true
              ? beverageType!
              : (custom['beverage_type']?.toString().toLowerCase() ?? 'other'));

    _waterLogs.insert(0, <String, dynamic>{
      'id': _nextWaterLogId++,
      'amount_liter': amountMl / 1000.0,
      'hydration_ml': amountMl,
      'beverage_type': type,
      'beverage_name': name,
      'food_item': food.isNotEmpty ? foodItemId : null,
      'food_item_name': food.isNotEmpty ? name : '',
      'linked_meal_log': null,
      'nutrition_preview': <String, dynamic>{
        'calories': _toDouble(custom['calories_kcal']),
        'protein': _toDouble(custom['protein_g']),
        'carbs': _toDouble(custom['carbohydrates_g']),
        'fat': _toDouble(custom['fat_g']),
        'sugars': _toDouble(custom['sugars_g']),
        'caffeine': _toDouble(custom['caffeine_mg']),
      },
      'date': '2026-04-28T12:30:00Z',
    });
  }

  Map<String, dynamic> _activitySummaryData() {
    return <String, dynamic>{'points_estimate': 15, 'burn_current': 220};
  }

  void _createActivity(Map<String, dynamic> payload) {
    final exerciseId = _toInt(payload['exercise']);
    final exercise = _exercises.firstWhere(
      (item) => _toInt(item['id']) == exerciseId,
      orElse: () => _exercises.first,
    );
    _activityLogs.insert(0, <String, dynamic>{
      'id': _nextActivityId++,
      'exercise': exerciseId,
      'exercise_name': exercise['name'],
      'duration_minutes': _toInt(payload['duration_minutes']),
      'calories_burned': 140,
      'date': '2026-04-28T09:10:00Z',
    });
  }

  Map<String, dynamic> _stepsSummaryData() {
    return <String, dynamic>{
      'target_steps': 8000,
      'steps_today': 5120,
      'distance_km': 3.9,
      'calories_burned': 205,
      'burn_rate_kcal_per_km': 52.6,
      'points': 25,
    };
  }

  void _updateSteps(Map<String, dynamic> payload) {}

  Map<String, dynamic> _sleepSummaryData() {
    return <String, dynamic>{
      'goal_hours': 8.0,
      'logged_hours_today': 7.25,
      'progress_percent': 91,
      'sleep_points': 10,
    };
  }

  void _createSleepLog(Map<String, dynamic> payload) {
    _sleepLogs.insert(0, <String, dynamic>{
      'id': _nextSleepId++,
      'start_time': payload['start_time']?.toString() ?? '2026-04-27T22:30:00Z',
      'end_time': payload['end_time']?.toString() ?? '2026-04-28T06:30:00Z',
      'quality': payload['quality']?.toString() ?? 'Deep',
      'duration_hours': 8,
      'points_earned': 10,
      'date': '2026-04-28',
    });
  }

  Map<String, dynamic> _medicationsOverviewData() {
    return <String, dynamic>{
      'medications': _medications,
      'today_plan': _todayPlan,
      'overall_adherence': <String, dynamic>{
        'expected_doses': 2,
        'taken_doses': 1,
        'missed_doses': 0,
        'skipped_doses': 0,
        'pending_doses': 1,
        'overdue_doses': 0,
        'adherence_percent': 92,
        'streak_days': 3,
        'on_time_percent': 88,
      },
      'reminder_sync': <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'medication_id': 10,
            'schedule_id': 501,
            'display_name': 'Metformin',
            'timezone': 'Asia/Damascus',
            'scheduled_times': const <String>['08:00'],
            'days_of_week': const <int>[0, 1, 2, 3, 4, 5, 6],
            'meal_relation': 'after_meal',
            'snooze_default_minutes': 15,
            'reminder_lead_minutes': 10,
            'linked_condition': <String, dynamic>{'id': 4, 'name': 'Diabetes'},
          },
        ],
      },
    };
  }
}

Map<String, dynamic> _sampleUser() {
  return <String, dynamic>{
    'username': 'user1',
    'first_name': 'Salam',
    'last_name': 'Ayash',
    'email': 'salam@example.com',
    'weight': 80,
    'height': 175,
    'activity_level': 1.55,
    'goal': 'maintain',
    'daily_step_goal': 8000,
    'gender': 'male',
    'birth_date': '2000-01-01',
    'recommended_sleep_hours': 8,
    'target_wake_time': '07:00:00',
    'target_bed_time': '23:00:00',
    'enable_sleep_improvement': true,
    'preferred_activity_type': 'walking',
    'enable_activity_reminders': true,
    'activity_reminder_interval_hours': 2,
    'enable_water_reminders': true,
    'water_reminder_interval_minutes': 60,
  };
}

List<Map<String, dynamic>> _sampleFoods() {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 101,
      'name': 'Overnight Oats',
      'item_type': 'food',
      'category': 'Breakfast',
      'meal_tags': 'breakfast',
      'calories_100g': 150,
      'protein_100g': 5,
      'carbs_100g': 20,
      'fat_100g': 4,
      'default_serving_size': 220,
      'default_serving_unit': 'g',
      'serving_label': 'Bowl',
      'serving_grams': 220,
      'serving_options': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1001,
          'name': 'Bowl',
          'amount': 1,
          'unit': 'serving',
          'grams_equivalent': 220,
          'is_default': true,
          'sort_order': 0,
        },
      ],
      'nutrition_facts': <String, dynamic>{
        'sugars_g': 4,
        'fiber_g': 6,
        'sodium_mg': 80,
        'water_g': 30,
        'caffeine_mg': 0,
      },
    },
    <String, dynamic>{
      'id': 102,
      'name': 'Chicken Rice Bowl',
      'item_type': 'food',
      'category': 'Lunch',
      'meal_tags': 'lunch',
      'calories_100g': 190,
      'protein_100g': 14,
      'carbs_100g': 18,
      'fat_100g': 7,
      'default_serving_size': 250,
      'default_serving_unit': 'g',
      'serving_label': 'Plate',
      'serving_grams': 250,
      'serving_options': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1002,
          'name': 'Plate',
          'amount': 1,
          'unit': 'serving',
          'grams_equivalent': 250,
          'is_default': true,
          'sort_order': 0,
        },
      ],
      'nutrition_facts': <String, dynamic>{
        'sugars_g': 3,
        'fiber_g': 4,
        'sodium_mg': 240,
        'water_g': 25,
        'caffeine_mg': 0,
      },
    },
    <String, dynamic>{
      'id': 201,
      'name': 'Cold Brew',
      'item_type': 'beverage',
      'category': 'Coffee',
      'meal_tags': 'drink',
      'calories_100g': 5,
      'protein_100g': 0,
      'carbs_100g': 1,
      'fat_100g': 0,
      'default_serving_size': 250,
      'default_serving_unit': 'ml',
      'serving_label': 'Cup',
      'serving_grams': 250,
      'serving_options': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 2001,
          'name': 'Cup',
          'amount': 1,
          'unit': 'serving',
          'milliliters_equivalent': 250,
          'is_default': true,
          'sort_order': 0,
        },
      ],
      'nutrition_facts': <String, dynamic>{
        'sugars_g': 0,
        'fiber_g': 0,
        'sodium_mg': 10,
        'water_g': 98,
        'caffeine_mg': 38,
      },
      'contains_caffeine': true,
      'is_hydration_trackable': true,
    },
    <String, dynamic>{
      'id': 202,
      'name': 'Orange Juice',
      'item_type': 'beverage',
      'category': 'Juice',
      'meal_tags': 'drink',
      'calories_100g': 45,
      'protein_100g': 0,
      'carbs_100g': 11,
      'fat_100g': 0,
      'default_serving_size': 250,
      'default_serving_unit': 'ml',
      'serving_label': 'Glass',
      'serving_grams': 250,
      'serving_options': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 2002,
          'name': 'Glass',
          'amount': 1,
          'unit': 'serving',
          'milliliters_equivalent': 250,
          'is_default': true,
          'sort_order': 0,
        },
      ],
      'nutrition_facts': <String, dynamic>{
        'sugars_g': 11,
        'fiber_g': 0.2,
        'sodium_mg': 2,
        'water_g': 89,
        'caffeine_mg': 0,
      },
      'is_hydration_trackable': true,
    },
  ];
}

List<Map<String, dynamic>> _sampleMeals() {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 1,
      'food': 101,
      'food_name': 'Overnight Oats',
      'meal_type': 'breakfast',
      'quantity_grams': 220,
      'quantity': 1,
      'unit': 'serving',
      'servings_consumed': 1,
      'serving_option': 1001,
      'serving_option_name': 'Bowl',
      'serving_label_snapshot': 'Bowl',
      'consumed_at': '2026-04-28T07:45:00Z',
      'snapshot_calories_kcal': 330,
      'snapshot_protein_g': 11,
      'snapshot_carbohydrates_g': 44,
      'snapshot_fat_g': 8.8,
      'snapshot_sugars_g': 8.8,
      'snapshot_added_sugars_g': 8.8,
      'snapshot_fiber_g': 13.2,
      'snapshot_sodium_mg': 176,
      'snapshot_saturated_fat_g': 0,
      'snapshot_trans_fat_g': 0,
      'snapshot_cholesterol_mg': 0,
      'snapshot_potassium_mg': 0,
      'snapshot_caffeine_mg': 0,
    },
  ];
}

List<Map<String, dynamic>> _sampleWaterLogs() {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 1,
      'amount_liter': 0.35,
      'hydration_ml': 350,
      'beverage_type': 'water',
      'beverage_name': 'Water',
      'food_item': null,
      'food_item_name': '',
      'linked_meal_log': null,
      'nutrition_preview': <String, dynamic>{
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
        'sugars': 0,
        'caffeine': 0,
      },
      'date': '2026-04-28T08:15:00Z',
    },
  ];
}

List<Map<String, dynamic>> _sampleSleepLogs() {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 71,
      'start_time': '2026-04-27T22:45:00Z',
      'end_time': '2026-04-28T06:00:00Z',
      'quality': 'Deep',
      'duration_hours': 7.25,
      'points_earned': 10,
      'date': '2026-04-28',
    },
  ];
}

List<Map<String, dynamic>> _sampleActivityLogs() {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 11,
      'exercise': 1,
      'exercise_name': 'Brisk Walk',
      'duration_minutes': 30,
      'calories_burned': 140,
      'date': '2026-04-28T09:00:00Z',
    },
  ];
}

List<Map<String, dynamic>> _sampleExercises() {
  return <Map<String, dynamic>>[
    <String, dynamic>{'id': 1, 'name': 'Brisk Walk', 'met_value': 4.3},
    <String, dynamic>{'id': 2, 'name': 'Cycling', 'met_value': 6.0},
  ];
}

List<Map<String, dynamic>> _sampleMedications() {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 10,
      'display_name': 'Metformin',
      'source_type': 'condition',
      'linked_condition_id': 4,
      'linked_condition_name': 'Diabetes',
      'dose_amount': '500',
      'dose_unit': 'mg',
      'dosage': '500 mg tablet',
      'form': 'tablet',
      'instructions': 'After breakfast',
      'start_date': '2026-04-20',
      'next_due': '2026-04-28T08:00:00Z',
      'is_active': true,
      'is_prn': false,
      'timezone': 'Asia/Damascus',
      'adherence_summary_short': <String, dynamic>{
        'expected_doses': 2,
        'taken_doses': 1,
        'missed_doses': 0,
        'skipped_doses': 0,
        'pending_doses': 1,
        'overdue_doses': 0,
        'adherence_percent': 92,
        'streak_days': 3,
        'on_time_percent': 88,
      },
      'schedules': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 501,
          'schedule_type': 'daily',
          'time': '08:00',
          'meal_relation': 'after_meal',
        },
      ],
    },
  ];
}

List<Map<String, dynamic>> _sampleMedicationTodayPlan() {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'log_id': 901,
      'medication_id': 10,
      'display_name': 'Metformin',
      'linked_condition': <String, dynamic>{'id': 4, 'name': 'Diabetes'},
      'scheduled_for': '2026-04-28T08:00:00Z',
      'status': 'pending',
      'dose_amount': '500',
      'dose_unit': 'mg',
      'form': 'tablet',
    },
  ];
}

List<Map<String, dynamic>> _sampleSupportedConditionTypes() {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 1,
      'code': 'diabetes',
      'slug': 'diabetes',
      'name': 'Diabetes',
      'display_name': 'Diabetes',
      'description': 'Blood glucose support',
      'can_add': true,
      'is_active_for_user': true,
      'setup_fields': const <Object>[],
      'measurement_types': const <String>['glucose'],
      'supports_direct_daily_reading': true,
      'severity_options': const <Map<String, dynamic>>[
        <String, dynamic>{
          'code': 'diabetes_managed',
          'label': 'Managed diabetes',
          'description': 'Sample severity',
        },
      ],
      'restrictions': const <Object>[],
      'rule_profiles': const <Object>[],
    },
    <String, dynamic>{
      'id': 2,
      'code': 'hypertension',
      'slug': 'hypertension',
      'name': 'Hypertension',
      'display_name': 'Hypertension',
      'description': 'Blood pressure support',
      'can_add': true,
      'is_active_for_user': false,
      'setup_fields': const <Object>[],
      'measurement_types': const <String>['blood_pressure'],
      'supports_direct_daily_reading': true,
      'severity_options': const <Map<String, dynamic>>[
        <String, dynamic>{
          'code': 'stage_1',
          'label': 'Moderate',
          'description': 'Sample severity',
        },
      ],
      'restrictions': const <Object>[],
      'rule_profiles': const <Object>[],
    },
    <String, dynamic>{
      'id': 3,
      'code': 'hyperlipidemia',
      'slug': 'dyslipidemia',
      'name': 'Dyslipidemia',
      'display_name': 'Cholesterol',
      'description': 'Lipids support',
      'can_add': true,
      'is_active_for_user': false,
      'setup_fields': const <Object>[],
      'measurement_types': const <String>['lipid_panel'],
      'supports_direct_daily_reading': false,
      'severity_options': const <Map<String, dynamic>>[
        <String, dynamic>{
          'code': 'stage_1',
          'label': 'Moderate',
          'description': 'Sample severity',
        },
      ],
      'restrictions': const <Object>[],
      'rule_profiles': const <Object>[],
    },
  ];
}

Map<String, dynamic> _sampleCompactCondition() {
  return <String, dynamic>{
    'view': 'compact',
    'id': 4,
    'condition_type': _sampleSupportedConditionTypes().first,
    'diagnosis_date': '2026-04-11',
    'condition_status': 'active',
    'severity': 'diabetes_managed',
    'notes': 'Clinician approved current plan.',
    'profile_data': const <String, dynamic>{'glucose_target': 110},
    'is_active': true,
    'daily_medication_count': 1,
    'daily_pending_doses': 1,
    'open_alerts_count': 0,
    'evaluation_status': 'stable',
    'summary_status_label': 'In range',
    'summary_subtitle': 'Latest fasting glucose recorded',
    'summary_line': '110 mg/dL',
    'secondary_summary_line':
        'Open tracking for targets, medications, and readings.',
    'latest_recorded_at': '2026-04-11T08:30:00Z',
    'targets': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 21,
        'target_key': 'added_sugars_g',
        'target_name': 'Added sugar',
        'category': 'nutrition',
        'metric_key': 'added_sugars_g',
        'evaluation_mode': 'daily_total',
        'status': 'within_target',
        'unit': 'g',
        'max_value': 25,
        'source_type': 'dynamic_condition_state',
        'priority': 0,
        'guidance': 'Keep added sugar under 25 g/day.',
        'evidence_source': 'Sample source',
        'is_scored': false,
      },
      <String, dynamic>{
        'id': 22,
        'target_key': 'water_liters',
        'target_name': 'Hydration',
        'category': 'hydration',
        'metric_key': 'water_liters',
        'evaluation_mode': 'daily_total',
        'status': 'within_target',
        'unit': 'L',
        'min_value': 2.0,
        'source_type': 'dynamic_condition_state',
        'priority': 1,
        'guidance': 'Aim for at least 2.0 L hydration daily.',
        'evidence_source': 'Sample source',
        'is_scored': false,
      },
      <String, dynamic>{
        'id': 23,
        'target_key': 'activity_minutes_7d',
        'target_name': 'Weekly activity',
        'category': 'activity',
        'metric_key': 'activity_minutes_7d',
        'evaluation_mode': 'weekly_total',
        'status': 'within_target',
        'unit': 'min',
        'min_value': 150,
        'source_type': 'dynamic_condition_state',
        'priority': 2,
        'guidance': 'Reach at least 150 minutes this week.',
        'evidence_source': 'Sample source',
        'is_scored': false,
      },
    ],
  };
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return <String, dynamic>{};
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

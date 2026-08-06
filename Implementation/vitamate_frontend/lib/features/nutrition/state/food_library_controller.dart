import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/food_item.dart';
import 'nutrition_controller.dart';

class FoodLibraryController extends ChangeNotifier {
  FoodLibraryController({required NutritionController source})
    : _source = source;

  static const int pageSize = 24;

  final NutritionController _source;
  Timer? _debounce;
  int _generation = 0;

  String query = '';
  String tab = 'all';
  String category = '';
  bool loading = false;
  bool canLoadMore = true;
  String? error;
  List<FoodItem> foods = const <FoodItem>[];
  final Set<int> favoriteIds = <int>{};

  Future<void> initialize() async {
    await Future.wait<void>(<Future<void>>[_loadFavoriteIds(), refresh()]);
  }

  void onQueryChanged(String value) {
    query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), refresh);
  }

  Future<void> setTab(String value) async {
    if (tab == value) return;
    tab = value;
    category = '';
    notifyListeners();
    await refresh();
  }

  Future<void> setCategory(String value) async {
    if (category == value) return;
    category = value;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() => _search();

  Future<void> loadNextPage() async {
    if (loading || !canLoadMore || tab == 'favorites' || tab == 'recent') {
      return;
    }
    await _search(append: true);
  }

  Future<void> _search({bool append = false}) async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    final offset = append ? foods.length : 0;
    try {
      final values = switch (tab) {
        'favorites' => await _source.getFavoriteFoods(),
        'recent' => await _source.getRecentFoods(limit: pageSize),
        _ => await _source.searchFoods(
          mealType: 'lunch',
          query: query,
          category: category.isEmpty ? null : category,
          includeMealSlot: false,
          limit: pageSize,
          offset: offset,
        ),
      };
      if (generation != _generation) return;
      final normalizedQuery = query.trim().toLowerCase();
      final filtered = values
          .where((food) {
            final queryMatches =
                normalizedQuery.isEmpty ||
                food.name.toLowerCase().contains(normalizedQuery);
            final categoryMatches =
                category.isEmpty ||
                food.category.toLowerCase() == category.toLowerCase();
            return queryMatches && categoryMatches;
          })
          .toList(growable: false);
      if (append) {
        final merged = <int, FoodItem>{for (final food in foods) food.id: food};
        for (final food in filtered) {
          merged[food.id] = food;
        }
        foods = merged.values.toList(growable: false);
      } else {
        foods = filtered;
      }
      canLoadMore =
          tab != 'favorites' && tab != 'recent' && values.length == pageSize;
    } catch (exception) {
      if (generation == _generation) error = exception.toString();
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadFavoriteIds() async {
    try {
      final values = await _source.getFavoriteFoods();
      favoriteIds
        ..clear()
        ..addAll(values.map((food) => food.id));
      notifyListeners();
    } catch (_) {
      // Food search remains available if favorite metadata cannot load.
    }
  }

  Future<void> toggleFavorite(FoodItem food) async {
    final next = !favoriteIds.contains(food.id);
    if (next) {
      favoriteIds.add(food.id);
    } else {
      favoriteIds.remove(food.id);
      if (tab == 'favorites') {
        foods = foods.where((item) => item.id != food.id).toList();
      }
    }
    notifyListeners();
    try {
      await _source.setFoodFavorite(foodId: food.id, isFavorite: next);
    } catch (exception) {
      if (next) {
        favoriteIds.remove(food.id);
      } else {
        favoriteIds.add(food.id);
      }
      error = exception.toString();
      notifyListeners();
      if (tab == 'favorites') await refresh();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

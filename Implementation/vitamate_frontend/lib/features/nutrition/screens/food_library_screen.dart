import 'package:flutter/material.dart';

import '../../../core/testing/app_test_keys.dart';
import '../../../core/theme/vitamate_theme.dart';
import '../models/food_item.dart';
import '../state/food_library_controller.dart';
import '../state/nutrition_controller.dart';
import '../widgets/nutrition_reference_ui.dart';
import '../widgets/nutrition_ui.dart' show NutritionErrorView, compactNumber;

class FoodLibrarySelection {
  const FoodLibrarySelection({
    required this.food,
    required this.quantity,
    required this.unit,
    this.servingOption,
  });

  final FoodItem food;
  final double quantity;
  final String unit;
  final NutritionServingOption? servingOption;
}

class FoodLibraryScreen extends StatefulWidget {
  const FoodLibraryScreen({
    super.key,
    required this.controller,
    this.selectionMode = false,
  });

  final NutritionController controller;
  final bool selectionMode;

  @override
  State<FoodLibraryScreen> createState() => _FoodLibraryScreenState();
}

class _FoodLibraryScreenState extends State<FoodLibraryScreen> {
  final TextEditingController query = TextEditingController();
  final ScrollController scroll = ScrollController();
  late final FoodLibraryController state;

  @override
  void initState() {
    super.initState();
    state = FoodLibraryController(source: widget.controller);
    scroll.addListener(_onScroll);
    state.initialize();
  }

  @override
  void dispose() {
    state.dispose();
    query.dispose();
    scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (scroll.position.extentAfter < 180) {
      state.loadNextPage();
    }
  }

  Future<void> _select(FoodItem food) async {
    final result = await showModalBottomSheet<FoodLibrarySelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _QuantitySheet(food: food),
    );
    if (result != null && mounted && widget.selectionMode) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final categories = state.foods
            .map((food) => food.category.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .take(8)
            .toList(growable: false);
        return Scaffold(
          body: NutritionReferenceBackground(
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: NutritionReferenceHeader(
                      title: 'Food library',
                      compact: true,
                      trailing: NutritionRoundButton(
                        icon: Icons.tune_rounded,
                        tooltip: 'Supported filters',
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          builder: (_) => const _SupportedFiltersSheet(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFCFC1EE)),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x153A2386),
                            blurRadius: 16,
                            offset: Offset(0, 7),
                          ),
                        ],
                      ),
                      child: TextField(
                        key: const ValueKey(AppTestKeys.nutritionSearchField),
                        controller: query,
                        onChanged: state.onQueryChanged,
                        decoration: const InputDecoration(
                          hintText: 'Search foods',
                          hintStyle: TextStyle(color: Color(0xFF8A80A3)),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: nutritionMuted,
                            size: 29,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 46,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      children: <Widget>[
                        for (final entry in const <String, (String, IconData)>{
                          'recent': ('Recent', Icons.schedule_rounded),
                          'favorites': ('Favorites', Icons.favorite_border),
                          'categories': ('Categories', Icons.grid_view_rounded),
                          'all': ('All', Icons.format_list_bulleted_rounded),
                        }.entries)
                          _LibraryTab(
                            label: entry.value.$1,
                            icon: entry.value.$2,
                            selected: state.tab == entry.key,
                            onTap: () => state.setTab(entry.key),
                          ),
                      ],
                    ),
                  ),
                  if (categories.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Categories',
                              style: TextStyle(
                                color: nutritionInk,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => state.setTab('categories'),
                            child: const Text('See all'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        children: <Widget>[
                          _CategoryChip(
                            label: 'All foods',
                            selected: state.category.isEmpty,
                            onTap: () => state.setCategory(''),
                          ),
                          for (final value in categories)
                            _CategoryChip(
                              label: value,
                              selected: state.category == value,
                              onTap: () => state.setCategory(value),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(child: _body()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body() {
    if (state.loading && state.foods.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 6,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: NutritionReferenceCard(
            child: SizedBox(height: 42, child: LinearProgressIndicator()),
          ),
        ),
      );
    }
    if (state.error != null && state.foods.isEmpty) {
      return NutritionErrorView(message: state.error!, onRetry: state.refresh);
    }
    if (state.foods.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.tab == 'favorites'
                ? 'No favorite foods are available yet.'
                : 'No foods match these filters.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VitaMateTheme.primaryDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      itemCount: state.foods.length + (state.loading ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == state.foods.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final food = state.foods[index];
        return _FoodCard(
          food: food,
          favorite: state.favoriteIds.contains(food.id),
          onFavorite: () => state.toggleFavorite(food),
          onSelect: () => _select(food),
        );
      },
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? nutritionPurple : Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minWidth: 108),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? nutritionPurple : const Color(0xFFD7CAED),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 19,
              color: selected ? Colors.white : nutritionPurple,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : nutritionPurple,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 9),
    child: ActionChip(
      onPressed: onTap,
      avatar: Icon(
        Icons.restaurant_menu_rounded,
        size: 17,
        color: selected ? Colors.white : nutritionPurple,
      ),
      label: Text(label),
      backgroundColor: selected ? nutritionPurple : Colors.white,
      side: BorderSide(
        color: selected ? nutritionPurple : const Color(0xFFE2D9F0),
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : nutritionInk,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({
    required this.food,
    required this.favorite,
    required this.onFavorite,
    required this.onSelect,
  });

  final FoodItem food;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => NutritionReferenceCard(
    onTap: onSelect,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    child: Row(
      children: <Widget>[
        Container(
          width: 68,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFF1E9FF), Color(0xFFFFF7E9)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.restaurant_rounded,
            color: nutritionPurple,
            size: 30,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                food.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: nutritionInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${compactNumber(food.calories100g)} kcal  ·  ${compactNumber(food.protein100g, decimals: 1)}g protein  ·  ${compactNumber(food.fat100g, decimals: 1)}g fat',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: nutritionMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'per 100g',
                style: TextStyle(color: Color(0xFF9489AC), fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: favorite ? 'Remove favorite' : 'Add favorite',
          visualDensity: VisualDensity.compact,
          onPressed: onFavorite,
          icon: Icon(
            favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: favorite ? VitaMateTheme.danger : nutritionPurple,
            size: 21,
          ),
        ),
        IconButton(
          tooltip: 'Choose quantity',
          onPressed: onSelect,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF4EEFF),
            side: const BorderSide(color: Color(0xFFD9CAFA)),
          ),
          icon: const Icon(Icons.add_rounded, color: nutritionPurple),
        ),
      ],
    ),
  );
}

class _QuantitySheet extends StatefulWidget {
  const _QuantitySheet({required this.food});
  final FoodItem food;

  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  String mode = 'serving';
  late final TextEditingController amount;
  NutritionServingOption? option;

  @override
  void initState() {
    super.initState();
    option = widget.food.defaultServingOption;
    if (option == null) mode = 'grams';
    amount = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          widget.food.name,
          style: const TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          segments: const <ButtonSegment<String>>[
            ButtonSegment(value: 'serving', label: Text('Serving')),
            ButtonSegment(value: 'grams', label: Text('Grams')),
          ],
          selected: <String>{mode},
          onSelectionChanged: (value) => setState(() => mode = value.first),
        ),
        const SizedBox(height: 12),
        if (mode == 'serving' && widget.food.servingOptions.isNotEmpty)
          DropdownButtonFormField<NutritionServingOption>(
            initialValue: option,
            decoration: const InputDecoration(labelText: 'Serving type'),
            items: widget.food.servingOptions
                .map(
                  (item) => DropdownMenuItem<NutritionServingOption>(
                    value: item,
                    child: Text('${item.displayLabel} (${item.summaryLabel})'),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() => option = value),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: mode == 'serving' ? 'Servings' : 'Weight',
            suffixText: mode == 'serving' ? null : 'g',
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () {
            final value = double.tryParse(amount.text);
            if (value == null ||
                value <= 0 ||
                (mode == 'serving' && option == null)) {
              return;
            }
            Navigator.pop(
              context,
              FoodLibrarySelection(
                food: widget.food,
                quantity: value,
                unit: mode == 'serving' ? 'serving' : 'g',
                servingOption: mode == 'serving' ? option : null,
              ),
            );
          },
          child: const Text('Use this amount'),
        ),
      ],
    ),
  );
}

class _SupportedFiltersSheet extends StatelessWidget {
  const _SupportedFiltersSheet();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Available filters',
          style: TextStyle(
            color: VitaMateTheme.primaryDeep,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Search text, category, meal slot, beverage, caffeine, and hydration support.',
        ),
      ],
    ),
  );
}

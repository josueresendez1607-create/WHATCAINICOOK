import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/routes.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/ingredient.dart';
import 'package:whatcanicook/models/ingredient_catalog.dart';
import 'package:whatcanicook/models/recipe_match.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/services/recipe_matcher.dart';
import 'package:whatcanicook/widgets/empty_state.dart';
import 'package:whatcanicook/widgets/recipe_card.dart';
import 'package:whatcanicook/widgets/section_header.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  final Set<RecipeFilter> _filters = {};
  RecipeSort _sort = RecipeSort.match;
  int _count = 5;
  List<RecipeMatch>? _results;

  @override
  Widget build(BuildContext context) {
    ref.watch(recipesProvider);
    final ingredientsAsync = ref.watch(ingredientsProvider);
    ref.watch(profileProvider);
    ref.watch(ingredientCatalogProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Generador de recetas',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Solo recetas verificadas de fuentes oficiales.',
            style: TextStyle(color: AppColors.gray),
          ),
          const SizedBox(height: 18),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cantidad de recetas',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 3, label: Text('3')),
                      ButtonSegment(value: 5, label: Text('5')),
                      ButtonSegment(value: 10, label: Text('10')),
                    ],
                    selected: {_count},
                    onSelectionChanged: (values) =>
                        setState(() => _count = values.first),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Filtros',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final filter in RecipeFilter.values)
                        FilterChip(
                          label: Text(filter.label),
                          selected: _filters.contains(filter),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _filters.add(filter);
                            } else {
                              _filters.remove(filter);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Ordenar por',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<RecipeSort>(
                    initialValue: _sort,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      for (final sort in RecipeSort.values)
                        DropdownMenuItem(value: sort, child: Text(sort.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _sort = value);
                    },
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () => _generate(),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text('Generar $_count recetas'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          ingredientsAsync.when(
            data: (items) => Text(
              items.isEmpty
                  ? 'Tienes 0 ingredientes en tu lista. Agrega algunos para mejorar la coincidencia.'
                  : 'Usando ${items.length} ingredientes de tu lista.',
              style: const TextStyle(fontSize: 13, color: AppColors.gray),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 10),

          if (_results != null) ...[
            SectionHeader(
              title: 'Resultados',
              subtitle: 'Fuente: MyPlate (USDA). Las etiquetas son de la app.',
            ),
            const SizedBox(height: 12),
            if (_results!.isEmpty)
              const EmptyState(
                icon: Icons.no_meals_rounded,
                title: 'Sin resultados',
                message: 'Prueba con menos filtros o cambia el orden.',
              )
            else
              for (final match in _results!) ...[
                RecipeCard(
                  match: match,
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.recipeDetail,
                    arguments: match.recipe.id,
                  ),
                ),
                const SizedBox(height: 12),
              ],
          ] else
            const EmptyState(
              icon: Icons.restaurant_menu_rounded,
              title: 'Listo para cocinar',
              message: 'Ajusta los filtros y genera tus recetas recomendadas.',
            ),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    final recipes = await ref.read(recipesProvider.future);
    final ingredients = await ref.read(ingredientsProvider.future);
    final profile = await ref.read(profileProvider.future);
    final catalog = await ref.read(ingredientCatalogProvider.future);

    final available = <String>{
      for (final ingredient in ingredients) _keyFor(ingredient, catalog),
    }..removeWhere((key) => key.isEmpty);

    final all = const RecipeMatcher().match(
      recipes: recipes,
      availableKeys: available,
      filters: _filters.toList(),
      sort: _sort,
      profile: profile,
    );

    await ref
        .read(historyProvider.notifier)
        .add('recetas', '$_count recetas · ${_filters.length} filtros');

    if (!mounted) return;
    setState(() => _results = all.take(_count).toList());
  }

  String _keyFor(Ingredient ingredient, IngredientCatalog catalog) {
    if (ingredient.key != null && ingredient.key!.isNotEmpty) {
      return ingredient.key!;
    }
    return catalog.resolveKey(ingredient.name) ?? '';
  }
}

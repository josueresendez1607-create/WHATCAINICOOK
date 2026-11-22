import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/async_value_ext.dart';
import 'package:whatcanicook/core/result.dart';
import 'package:whatcanicook/core/routes.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/ingredient.dart';
import 'package:whatcanicook/models/ingredient_catalog.dart';
import 'package:whatcanicook/models/recipe.dart';
import 'package:whatcanicook/models/recipe_match.dart';
import 'package:whatcanicook/models/user_profile.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/services/recipe_matcher.dart';
import 'package:whatcanicook/utils/feedback.dart';
import 'package:whatcanicook/widgets/empty_state.dart';
import 'package:whatcanicook/widgets/recipe_card.dart';
import 'package:whatcanicook/widgets/section_header.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  final _searchController = TextEditingController();
  final Set<RecipeFilter> _filters = {};
  RecipeSort _sort = RecipeSort.match;
  int _count = 5;
  String? _category;
  List<RecipeMatch>? _generated;
  String? _generationNote;
  bool _loading = false;

  static const List<_CategoryOption> _categories = [
    _CategoryOption(label: 'Todos', tag: null),
    _CategoryOption(label: 'Desayunos', tag: 'desayuno'),
    _CategoryOption(label: 'Comidas', tag: 'comida'),
    _CategoryOption(label: 'Cenas', tag: 'cena'),
    _CategoryOption(label: 'Postres', tag: 'postres'),
    _CategoryOption(label: 'Ensaladas', tag: 'ensaladas'),
    _CategoryOption(label: 'Bebidas', tag: 'bebidas'),
    _CategoryOption(label: 'Saludables', tag: 'saludable'),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(exploreCategoryProvider, (previous, next) {
      if (next == null) return;
      if (next == '__all__') {
        if (_category != null || _generated != null) {
          setState(() {
            _category = null;
            _generated = null;
            _generationNote = null;
          });
        }
      } else if (next != _category) {
        setState(() {
          _category = next;
          _generated = null;
          _generationNote = null;
        });
      }
      ref.read(exploreCategoryProvider.notifier).clear();
    });

    final recipesAsync = ref.watch(recipesProvider);
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final profileAsync = ref.watch(profileProvider);
    final catalogAsync = ref.watch(ingredientCatalogProvider);
    final favoritesAsync = ref.watch(favoritesProvider);
    final hiddenIds =
        ref
            .watch(hiddenRecipesProvider)
            .valueOrNull
            ?.map((h) => h.recipeId)
            .toSet() ??
        <String>{};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Explorar recetas',
            subtitle: 'Busca, filtra y genera ideas con IA desde recetas verificadas.',
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o ingrediente...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _searchController.clear(),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final option = _categories[index];
                return ChoiceChip(
                  label: Text(option.label),
                  selected: _category == option.tag,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    _category = option.tag;
                    _generated = null;
                    _generationNote = null;
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        color: AppColors.gold,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Filtros y generación',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Preferencias',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final filter in RecipeFilter.values)
                        FilterChip(
                          label: Text(filter.label),
                          selected: _filters.contains(filter),
                          showCheckmark: false,
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _filters.add(filter);
                            } else {
                              _filters.remove(filter);
                            }
                            _generated = null;
                            _generationNote = null;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Cantidad',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
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
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<RecipeSort>(
                    initialValue: _sort,
                    decoration: const InputDecoration(
                      labelText: 'Ordenar por',
                      prefixIcon: Icon(Icons.sort_rounded),
                    ),
                    items: [
                      for (final sort in RecipeSort.values)
                        DropdownMenuItem(value: sort, child: Text(sort.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _sort = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loading ? null : _generate,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      _loading ? 'Generando...' : 'Generar $_count recetas',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          ingredientsAsync.when(
            data: (items) => Text(
              items.isEmpty
                  ? 'Agrega ingredientes para descubrir qué puedes cocinar hoy.'
                  : 'Usando ${items.length} ingredientes de tu lista.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          if (_generationNote != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _generationNote!,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),

          recipesAsync.when(
            data: (recipes) => ingredientsAsync.when(
              data: (ingredients) {
                final catalog = catalogAsync.valueOrNull;
                final profile = profileAsync.valueOrNull;
                final available = <String>{
                  for (final ingredient in ingredients)
                    _keyFor(ingredient, catalog),
                }..removeWhere((key) => key.isEmpty);

                final matcher = const RecipeMatcher();
                final source =
                    _generated ??
                    matcher.match(
                      recipes: recipes,
                      availableKeys: available,
                      filters: _filters.toList(),
                      sort: _sort,
                      profile: profile ?? UserProfile.empty,
                    );
                final visible = _filterMatches(
                  source
                      .where((m) => !hiddenIds.contains(m.recipe.id))
                      .toList(),
                  catalog,
                  _generated == null ? _count : source.length,
                );
                final favoriteIds =
                    favoritesAsync.valueOrNull
                        ?.map((item) => item.recipeId)
                        .toSet() ??
                    <String>{};

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: _generated == null
                          ? 'Catálogo verificado'
                          : 'Resultados generados',
                      subtitle: 'Fuente: MyPlate (USDA). Etiquetas estimadas por la app.',
                    ),
                    const SizedBox(height: 12),
                    if (visible.isEmpty)
                      EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Sin coincidencias',
                        message: 'Prueba con otro término, categoría o filtro.',
                        actionLabel: 'Limpiar filtros',
                        onAction: _resetFilters,
                      )
                    else
                      for (final match in visible) ...[
                        RecipeCard(
                          match: match,
                          hasIngredients: available.isNotEmpty,
                          isFavorite: favoriteIds.contains(match.recipe.id),
                          onFavoriteTap: () => ref
                              .read(favoritesProvider.notifier)
                              .toggle(match.recipe.id),
                          onHideTap: () => _hideWithUndo(match.recipe),
                          onTap: () => Navigator.of(context).pushNamed(
                            AppRoutes.recipeDetail,
                            arguments: match.recipe.id,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => const Text(
                'No se pudo cargar tu lista de ingredientes.',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) => Text(
              'Error al cargar recetas: $error',
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _hideWithUndo(Recipe recipe) async {
    final notifier = ref.read(hiddenRecipesProvider.notifier);
    await notifier.hide(recipe.id, recipe.title);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: '${recipe.title} se ocultó de tus listados.',
      actionLabel: 'Deshacer',
      onUndo: () => notifier.unhide(recipe.id),
    );
  }

  List<RecipeMatch> _filterMatches(
    List<RecipeMatch> source,
    IngredientCatalog? catalog,
    int limit,
  ) {
    final query = _normalize(_searchController.text);
    final matches = source.where((match) {
      if (_category != null && !match.recipe.tags.contains(_category)) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = <String>[
        match.recipe.title,
        match.recipe.description,
        ...match.recipe.tags,
        for (final ingredient in match.recipe.ingredients) ingredient.key,
        for (final ingredient in match.recipe.ingredients)
          catalog?.labelForKey(ingredient.key) ?? ingredient.key,
      ].join(' ');
      return _normalize(haystack).contains(query);
    });
    return matches.take(limit).toList();
  }

  Future<void> _generate() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _generationNote = null;
    });

    try {
      final recipes = await ref.read(recipesProvider.future);
      final ingredients = await ref.read(ingredientsProvider.future);
      final profile = await ref.read(profileProvider.future);
      final catalog = await ref.read(ingredientCatalogProvider.future);

      final available = <String>{
        for (final ingredient in ingredients) _keyFor(ingredient, catalog),
      }..removeWhere((key) => key.isEmpty);

      final payload = <Map<String, String>>[
        for (final ingredient in ingredients)
          {'name': ingredient.name, 'key': _keyFor(ingredient, catalog)},
      ];
      final filterTags = <String>[
        for (final filter in _filters) filter.tag,
        ?_category,
      ];

      final service = ref.read(recipeGenerationServiceProvider);
      final generation = await service.generate(
        ingredients: payload
            .map((item) => item.values.where((value) => value.isNotEmpty).first)
            .toList(),
        count: _count,
        filters: filterTags,
      );

      final matcher = const RecipeMatcher();
      List<RecipeMatch> results;
      String note;

      switch (generation) {
        case AppSuccess(:final value):
          results = value.recipes
              .map(
                (recipe) => matcher
                    .match(recipes: [recipe], availableKeys: available)
                    .first,
              )
              .toList();
          note = value.usedGemini
              ? 'IA: ${value.recipes.length} recetas seleccionadas del catálogo verificado.'
              : 'Mostrando recetas del catálogo verificado según tus ingredientes.';
          if (value.warning != null && value.usedGemini) {
            note = '$note ${value.warning}';
          }

        case AppFailure():
          final fallback = matcher.match(
            recipes: recipes,
            availableKeys: available,
            filters: _filters.toList(),
            sort: _sort,
            profile: profile,
          );
          results = fallback.take(_count).toList();
          note = 'Mostrando recetas del catálogo verificado según tus ingredientes.';
      }

      final hiddenIds =
          ref
              .read(hiddenRecipesProvider)
              .valueOrNull
              ?.map((h) => h.recipeId)
              .toSet() ??
          <String>{};
      results = results.where((match) {
        if (hiddenIds.contains(match.recipe.id)) return false;
        if (_category == null) return true;
        return match.recipe.tags.contains(_category);
      }).toList();

      await ref
          .read(historyProvider.notifier)
          .add('recetas', '$_count recetas · ${_filters.length} filtros');
      if (!mounted) return;
      setState(() {
        _generated = results;
        _generationNote = note;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _generationNote = 'No se pudo generar: $error';
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _filters.clear();
      _category = null;
      _generated = null;
      _generationNote = null;
    });
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâã]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöôõ]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'ñ'), 'n')
        .trim();
  }

  String _keyFor(Ingredient ingredient, IngredientCatalog? catalog) {
    if (ingredient.key != null && ingredient.key!.isNotEmpty) {
      return ingredient.key!;
    }
    return catalog?.resolveKey(ingredient.name) ?? '';
  }
}

class _CategoryOption {
  const _CategoryOption({required this.label, required this.tag});

  final String label;
  final String? tag;
}

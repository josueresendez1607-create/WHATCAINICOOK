import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/async_value_ext.dart';
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
  final _manualIngredientController = TextEditingController();
  final Set<int> _selectedIngredientIds = <int>{};
  final Set<int> _knownIngredientIds = <int>{};
  bool _ingredientsSelectionInitialized = false;
  final int _count = 5;
  List<RecipeMatch>? _generated;
  String? _generationNote;
  bool _loading = false;
  int _generationRequestId = 0;

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
    _manualIngredientController.dispose();
    super.dispose();
  }

  void _syncIngredientSelection(
    List<Ingredient> ingredients, {
    required bool notify,
  }) {
    final currentIds = <int>{
      for (final ingredient in ingredients)
        if (ingredient.id != null) ingredient.id!,
    };
    final newIds = currentIds.difference(_knownIngredientIds);
    var changed = false;

    if (!_ingredientsSelectionInitialized) {
      _selectedIngredientIds
        ..clear()
        ..addAll(currentIds);
      _knownIngredientIds
        ..clear()
        ..addAll(currentIds);
      _ingredientsSelectionInitialized = true;
      changed = true;
    } else {
      final beforeSelected = _selectedIngredientIds.length;
      _selectedIngredientIds.removeWhere((id) => !currentIds.contains(id));
      if (_selectedIngredientIds.length != beforeSelected) changed = true;

      final beforeKnown = _knownIngredientIds.length;
      _knownIngredientIds.removeWhere((id) => !currentIds.contains(id));
      if (_knownIngredientIds.length != beforeKnown) changed = true;

      if (newIds.isNotEmpty) {
        _selectedIngredientIds.addAll(newIds);
        _knownIngredientIds.addAll(newIds);
        changed = true;
      }
    }

    if (changed && notify && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Ingredient>>>(ingredientsProvider, (_, next) {
      final items = next.valueOrNull;
      if (items != null) _syncIngredientSelection(items, notify: true);
    });

    final recipesAsync = ref.watch(recipesProvider);
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final ingredientsForSelection = ingredientsAsync.valueOrNull;
    if (ingredientsForSelection != null) {
      _syncIngredientSelection(ingredientsForSelection, notify: false);
    }
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
            subtitle:
                'Selecciona tus ingredientes y genera recetas compatibles del catálogo verificado.',
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
          _buildIngredientSelectionCard(ingredientsAsync, catalogAsync),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Generación de recetas',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Se mostrarán recetas compatibles con los ingredientes seleccionados, priorizando las de mayor coincidencia.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
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
            data: (items) {
              final selectedCount = items
                  .where(
                    (i) =>
                        i.id != null && _selectedIngredientIds.contains(i.id),
                  )
                  .length;
              final message = items.isEmpty
                  ? 'Agrega ingredientes para descubrir qué puedes cocinar hoy.'
                  : selectedCount == 0
                  ? 'Selecciona al menos un ingrediente para generar recetas.'
                  : 'Generación usará $selectedCount ingrediente${selectedCount == 1 ? '' : 's'} seleccionados.';
              return Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: selectedCount == 0 && items.isNotEmpty
                      ? AppColors.gold
                      : AppColors.textSecondary,
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          if (_generationNote != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _generationNote!,
                style: const TextStyle(
                  fontSize: 12,
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
                final available = <String>{
                  for (final ingredient in ingredients)
                    _keyFor(ingredient, catalog),
                }..removeWhere((key) => key.isEmpty);

                final matcher = const RecipeMatcher();
                final source =
                    _generated ??
                    matcher
                        .match(
                          recipes: recipes,
                          availableKeys: available,
                          profile: UserProfile.empty,
                        )
                        .where((m) => m.matchedCount > 0)
                        .take(_count)
                        .toList();

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
                          ? 'Recetas compatibles'
                          : 'Resultados generados',
                      subtitle:
                          'Catálogo local verificado. Se priorizan las recetas con mayor coincidencia.',
                    ),
                    const SizedBox(height: 12),
                    if (visible.isEmpty)
                      EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Sin coincidencias',
                        message: _searchController.text.trim().isNotEmpty
                            ? 'No hay recetas que coincidan con tu búsqueda actual.'
                            : 'No encontramos recetas compatibles con los ingredientes seleccionados. Prueba agregar o cambiar ingredientes.',
                        actionLabel: _searchController.text.trim().isNotEmpty
                            ? 'Limpiar búsqueda'
                            : null,
                        onAction: _searchController.text.trim().isNotEmpty
                            ? () => _searchController.clear()
                            : null,
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
                            arguments: match.recipe,
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

  Widget _buildIngredientSelectionCard(
    AsyncValue<List<Ingredient>> ingredientsAsync,
    AsyncValue<IngredientCatalog> catalogAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ingredientsAsync.when(
          data: (items) {
            final catalog = catalogAsync.valueOrNull;
            final selectedCount = items
                .where(
                  (i) => i.id != null && _selectedIngredientIds.contains(i.id),
                )
                .length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.kitchen_rounded,
                      color: AppColors.gold,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Mis ingredientes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        '$selectedCount seleccionados',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Selecciona los ingredientes que quieres usar para generar recetas.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'No tienes ingredientes guardados. Agrega al menos uno para generar recetas personalizadas.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in items)
                        _buildIngredientChip(item, catalog),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _selectedIngredientIds
                            ..clear()
                            ..addAll(
                              items
                                  .where((i) => i.id != null)
                                  .map((i) => i.id!),
                            );
                        }),
                        icon: const Icon(Icons.select_all_rounded, size: 16),
                        label: const Text('Todos'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(_selectedIngredientIds.clear),
                        icon: const Icon(Icons.deselect_rounded, size: 16),
                        label: const Text('Ninguno'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openManualIngredients,
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: const Text('Administrar'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualIngredientController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addManualIngredient(catalog),
                        decoration: const InputDecoration(
                          hintText: 'Agregar ingrediente manualmente...',
                          prefixIcon: Icon(Icons.add_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _addManualIngredient(catalog),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text('Agregar'),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const Text(
            'No se pudieron cargar tus ingredientes.',
            style: TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientChip(Ingredient item, IngredientCatalog? catalog) {
    final id = item.id;
    final selected = id != null && _selectedIngredientIds.contains(id);
    final label = item.quantity == null || item.quantity!.isEmpty
        ? item.name
        : '${item.name} (${item.quantity})';
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: true,
      checkmarkColor: AppColors.background,
      selectedColor: AppColors.gold,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: selected
            ? AppColors.gold
            : AppColors.border.withValues(alpha: 0.9),
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? AppColors.background : AppColors.textPrimary,
      ),
      onSelected: id == null
          ? null
          : (value) => setState(() {
              if (value) {
                _selectedIngredientIds.add(id);
              } else {
                _selectedIngredientIds.remove(id);
              }
              _generated = null;
              _generationNote = null;
            }),
      onDeleted: id == null ? null : () => _removeIngredient(item),
      deleteButtonTooltipMessage: 'Quitar de mi lista',
      deleteIcon: Icon(
        Icons.close_rounded,
        size: 16,
        color: selected ? AppColors.background : AppColors.textSecondary,
      ),
    );
  }

  Future<void> _addManualIngredient(IngredientCatalog? catalog) async {
    final name = _manualIngredientController.text.trim();
    if (name.isEmpty) return;
    final key = catalog?.resolveKey(name);
    final category = key == null
        ? 'otros'
        : catalog?.itemForKey(key)?.category ?? 'otros';
    await ref.read(ingredientsProvider.notifier).add(
      Ingredient(
        name: name,
        key: key,
        category: category,
        source: 'manual',
      ),
    );
    _manualIngredientController.clear();
    if (!mounted) return;
    setState(() {
      _generated = null;
      _generationNote = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name agregado a tus ingredientes.')));
  }

  Future<void> _removeIngredient(Ingredient item) async {
    final id = item.id;
    if (id == null) return;
    await ref.read(ingredientsProvider.notifier).remove(id);
    if (!mounted) return;
    setState(() {
      _selectedIngredientIds.remove(id);
      _knownIngredientIds.remove(id);
      _generated = null;
      _generationNote = null;
    });
  }

  Future<void> _openManualIngredients() async {
    await Navigator.of(context).pushNamed(AppRoutes.manualIngredients);
    if (!mounted) return;
    final items = ref.read(ingredientsProvider).valueOrNull;
    if (items != null) _syncIngredientSelection(items, notify: true);
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
    final requestId = ++_generationRequestId;
    setState(() {
      _loading = true;
      _generationNote = null;
    });

    try {
      final recipes = await ref.read(recipesProvider.future);
      final ingredients = await ref.read(ingredientsProvider.future);
      final catalog = await ref.read(ingredientCatalogProvider.future);

      final selectedIngredients = ingredients
          .where(
            (ingredient) =>
                ingredient.id != null &&
                _selectedIngredientIds.contains(ingredient.id),
          )
          .toList();

      if (selectedIngredients.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _generated = null;
          _generationNote = ingredients.isEmpty
              ? 'Agrega al menos un ingrediente para generar recetas.'
              : 'Selecciona al menos un ingrediente para generar recetas.';
        });
        return;
      }

      final available = <String>{
        for (final ingredient in selectedIngredients)
          _keyFor(ingredient, catalog),
      }..removeWhere((key) => key.isEmpty);

      final matcher = const RecipeMatcher();
      final hiddenIds =
          ref
              .read(hiddenRecipesProvider)
              .valueOrNull
              ?.map((h) => h.recipeId)
              .toSet() ??
          <String>{};

      final localResults = matcher
          .match(
            recipes: recipes,
            availableKeys: available,
            profile: UserProfile.empty,
          )
          .where((m) => !hiddenIds.contains(m.recipe.id))
          .where((m) => m.matchedCount > 0)
          .toList();

      localResults.sort((a, b) {
        final byScore = b.matchScore.compareTo(a.matchScore);
        if (byScore != 0) return byScore;
        final byMatched = b.matchedCount.compareTo(a.matchedCount);
        if (byMatched != 0) return byMatched;
        return a.missingCount.compareTo(b.missingCount);
      });

      final lastIds = ref.read(lastGeneratedRecipeIdsProvider).toSet();
      final fresh = <RecipeMatch>[];
      final repeated = <RecipeMatch>[];
      for (final match in localResults) {
        if (lastIds.contains(match.recipe.id)) {
          repeated.add(match);
        } else {
          fresh.add(match);
        }
      }
      final display = <RecipeMatch>[
        ...fresh.take(_count),
        if (fresh.length < _count) ...repeated.take(_count - fresh.length),
      ];

      final note = display.isEmpty
          ? 'No hay recetas compatibles con los ingredientes seleccionados.'
          : fresh.isEmpty
          ? 'Mostrando recetas compatibles. Ya se agotaron las opciones nuevas; se permiten repeticiones controladas.'
          : 'Mostrando recetas compatibles del catálogo verificado según tus ingredientes.';

      ref
          .read(lastGeneratedRecipeIdsProvider.notifier)
          .setIds(display.map((m) => m.recipe.id).toList());

      await ref.read(historyProvider.notifier).add(
        'recetas',
        'Catálogo verificado: ${display.length} recetas generadas',
      );

      if (!mounted || requestId != _generationRequestId) return;
      setState(() {
        _generated = display;
        _generationNote = note;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _generationRequestId) return;
      setState(() {
        _loading = false;
        _generationNote = 'No se pudo generar: $error';
      });
    }
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

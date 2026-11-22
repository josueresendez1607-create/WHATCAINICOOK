import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whatcanicook/core/async_value_ext.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/ingredient.dart';
import 'package:whatcanicook/models/ingredient_catalog.dart';
import 'package:whatcanicook/models/recipe.dart';
import 'package:whatcanicook/models/shopping_item.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/services/recipe_matcher.dart';
import 'package:whatcanicook/utils/feedback.dart';
import 'package:whatcanicook/utils/normalization.dart';
import 'package:whatcanicook/widgets/food_image.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  final Set<String> _recorded = {};
  int? _servingsOverride;
  final Set<int> _doneSteps = <int>{};
  Timer? _stepTimer;
  int _timerSecondsLeft = 0;
  int? _timerStep;
  bool _timerRunning = false;

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final favoritesAsync = ref.watch(favoritesProvider);
    final hiddenAsync = ref.watch(hiddenRecipesProvider);
    final catalogAsync = ref.watch(ingredientCatalogProvider);

    return Scaffold(
      body: recipesAsync.when(
        data: (recipes) {
          final recipe = recipes
              .where((item) => item.id == widget.recipeId)
              .firstOrNull;
          if (recipe == null) {
            return const Center(
              child: Text(
                'No se encontró la receta.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          if (_recorded.add(recipe.id)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref
                  .read(historyProvider.notifier)
                  .add('receta', recipe.title, recipeId: recipe.id);
            });
          }

          final isFavorite =
              favoritesAsync.valueOrNull?.any((f) => f.recipeId == recipe.id) ??
              false;
          final isHidden =
              hiddenAsync.valueOrNull?.any((h) => h.recipeId == recipe.id) ??
              false;
          final catalog = catalogAsync.valueOrNull;
          final availableKeys = <String>{
            for (final ingredient
                in ingredientsAsync.valueOrNull ?? const <Ingredient>[])
              _keyFor(ingredient, catalog),
          }..removeWhere((key) => key.isEmpty);
          final match = const RecipeMatcher()
              .match(recipes: [recipe], availableKeys: availableKeys)
              .first;
          final servings = _servingsOverride ?? recipe.servings;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      FoodImage(
                        imagePath: recipe.imageUrl,
                        borderRadius: BorderRadius.zero,
                        showBottomShade: true,
                        semanticLabel: 'Fotografía de ${recipe.title}',
                      ),
                      const Positioned(
                        left: 20,
                        bottom: 18,
                        right: 20,
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppColors.success,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Receta verificada',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: isFavorite
                        ? 'Quitar de favoritos'
                        : 'Guardar en favoritos',
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite
                          ? AppColors.danger
                          : AppColors.goldBright,
                    ),
                    onPressed: () =>
                        ref.read(favoritesProvider.notifier).toggle(recipe.id),
                  ),
                  IconButton(
                    tooltip: isHidden ? 'Mostrar platillo' : 'Ocultar platillo',
                    icon: Icon(
                      isHidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.goldBright,
                    ),
                    onPressed: () => _toggleHiddenWithUndo(recipe, isHidden),
                  ),
                  IconButton(
                    tooltip: 'Compartir receta',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => _share(recipe),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(title: recipe.sourceName),
                      const SizedBox(height: 8),
                      Text(
                        recipe.title,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          height: 1.18,
                        ),
                      ),
                      if (recipe.originalTitle.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Título original: ${recipe.originalTitle}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        recipe.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _Info(
                                  icon: Icons.timer_outlined,
                                  label: 'Preparación',
                                  value: formatMinutes(recipe.prepMinutes),
                                ),
                              ),
                              Expanded(
                                child: _Info(
                                  icon: Icons.local_fire_department_outlined,
                                  label: 'Cocción',
                                  value: formatMinutes(recipe.cookMinutes),
                                ),
                              ),
                              Expanded(
                                child: _Info(
                                  icon: Icons.signal_cellular_alt_rounded,
                                  label: 'Nivel',
                                  value: recipe.difficulty,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.people_outline,
                                      size: 18,
                                      color: AppColors.gold,
                                    ),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'Porciones',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _MiniIconButton(
                                          icon: Icons.remove,
                                          onTap: servings > 1
                                              ? () => _changeServings(
                                                  recipe.servings,
                                                  -1,
                                                )
                                              : null,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            '$servings',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        _MiniIconButton(
                                          icon: Icons.add,
                                          onTap: servings < 20
                                              ? () => _changeServings(
                                                  recipe.servings,
                                                  1,
                                                )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (recipe.difficultyIsEstimated) ...[
                        const SizedBox(height: 7),
                        const Text(
                          'La dificultad es una estimación de la app; la fuente no la publica.',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 26),

                      const _SectionTitle(title: 'Ingredientes'),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            children: [
                              for (final ingredient in recipe.ingredients) ...[
                                _IngredientLine(
                                  name:
                                      catalog?.labelForKey(ingredient.key) ??
                                      ingredient.key,
                                  quantity: _scaleQuantity(
                                    ingredient.quantityText,
                                    recipe.servings,
                                    servings,
                                  ),
                                ),
                                if (ingredient != recipe.ingredients.last)
                                  const SizedBox(height: 12),
                              ],
                              if (servings != recipe.servings) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Cantidades ajustadas para $servings porciones (original: ${recipe.servings}).',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      _SectionTitle(
                        title: availableKeys.isEmpty
                            ? 'Coincidencia de ingredientes'
                            : 'Lo que te falta',
                      ),
                      const SizedBox(height: 10),
                      if (availableKeys.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.gold,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Agrega ingredientes a tu lista para ver '
                                  'cuáles tienes y cuáles te faltan. Sin '
                                  'ingredientes activos no mostramos '
                                  'porcentajes ni conteos de faltantes.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (match.missing.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.45),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: AppColors.success,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '¡Tienes todos los ingredientes de esta receta!',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final missing in match.missing) ...[
                                  _IngredientLine(
                                    name:
                                        catalog?.labelForKey(missing.key) ??
                                        missing.key,
                                    quantity: missing.quantityText,
                                    isMissing: true,
                                  ),
                                  if (missing != match.missing.last)
                                    const SizedBox(height: 12),
                                ],
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: () => _addMissingToShopping(
                                    match.missing,
                                    catalog,
                                    recipe,
                                  ),
                                  icon: const Icon(
                                    Icons.add_shopping_cart_outlined,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Agregar faltantes a lista de compras',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 26),

                      _SectionTitle(
                        title: 'Preparación',
                        trailing: Text(
                          '${_doneSteps.length}/${recipe.steps.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_timerStep != null)
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  _timerRunning
                                      ? Icons.timer_outlined
                                      : Icons.pause_circle_outline,
                                  color: AppColors.gold,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Paso $_timerStep · ${_formatTimer(_timerSecondsLeft)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: _timerRunning
                                      ? 'Pausar'
                                      : 'Reanudar',
                                  onPressed: _toggleTimerPause,
                                  icon: Icon(
                                    _timerRunning
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Detener',
                                  onPressed: _stopTimer,
                                  icon: const Icon(Icons.stop_rounded),
                                ),
                              ],
                            ),
                          ),
                        ),
                      for (var i = 0; i < recipe.steps.length; i++) ...[
                        _StepTile(
                          number: i + 1,
                          text: recipe.steps[i],
                          done: _doneSteps.contains(i),
                          onToggle: () => _toggleStep(i),
                          onTimer: () => _showTimerSheet(i + 1),
                        ),
                        if (i != recipe.steps.length - 1)
                          const SizedBox(height: 10),
                      ],

                      if (recipe.nutrition.hasAny) ...[
                        const SizedBox(height: 28),
                        const _SectionTitle(title: 'Información nutricional'),
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(
                              spacing: 24,
                              runSpacing: 14,
                              children: [
                                if (recipe.nutrition.calories != null)
                                  _Nutrient(
                                    label: 'Calorías',
                                    value: '${recipe.nutrition.calories} kcal',
                                  ),
                                if (recipe.nutrition.proteinG != null)
                                  _Nutrient(
                                    label: 'Proteínas',
                                    value: '${recipe.nutrition.proteinG} g',
                                  ),
                                if (recipe.nutrition.carbsG != null)
                                  _Nutrient(
                                    label: 'Carbohidratos',
                                    value: '${recipe.nutrition.carbsG} g',
                                  ),
                                if (recipe.nutrition.fatG != null)
                                  _Nutrient(
                                    label: 'Grasas',
                                    value: '${recipe.nutrition.fatG} g',
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Valores publicados por la fuente original.',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),
                      const _SectionTitle(title: 'Fuente original'),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recipe.sourceName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                recipe.originalSource,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: () => _openSource(recipe.sourceUrl),
                                icon: const Icon(Icons.open_in_new, size: 17),
                                label: const Text('Ver receta original'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Error: $error',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleHiddenWithUndo(
    Recipe recipe,
    bool currentlyHidden,
  ) async {
    final notifier = ref.read(hiddenRecipesProvider.notifier);
    if (currentlyHidden) {
      await notifier.unhide(recipe.id);
    } else {
      await notifier.hide(recipe.id, recipe.title);
    }
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: currentlyHidden
          ? '${recipe.title} vuelve a aparecer en tus listados.'
          : '${recipe.title} se ocultó de tus listados.',
      actionLabel: 'Deshacer',
      onUndo: () => currentlyHidden
          ? notifier.hide(recipe.id, recipe.title)
          : notifier.unhide(recipe.id),
    );
  }

  String _keyFor(Ingredient ingredient, IngredientCatalog? catalog) {
    if (ingredient.key != null && ingredient.key!.isNotEmpty) {
      return ingredient.key!;
    }
    return catalog?.resolveKey(ingredient.name) ?? '';
  }

  String _scaleQuantity(String quantity, int baseServings, int targetServings) {
    if (quantity.trim().isEmpty ||
        baseServings <= 0 ||
        baseServings == targetServings) {
      return quantity;
    }
    final factor = targetServings / baseServings;
    final match = RegExp(r'^(\d+\s+\d+/\d+|\d+/\d+|\d+(?:[.,]\d+)?)')
        .firstMatch(quantity.trim());
    if (match == null) return quantity;
    final raw = match.group(1)!;
    double? value;
    if (raw.contains('/')) {
      final parts = raw.split(RegExp(r'\s+'));
      if (parts.length == 2 && parts[1].contains('/')) {
        final frac = parts[1].split('/');
        final whole = double.tryParse(parts[0]);
        final num = double.tryParse(frac[0]);
        final den = double.tryParse(frac[1]);
        if (whole != null && num != null && den != null && den != 0) {
          value = whole + num / den;
        }
      } else {
        final frac = raw.split('/');
        final num = double.tryParse(frac[0]);
        final den = double.tryParse(frac[1]);
        if (num != null && den != null && den != 0) value = num / den;
      }
    } else {
      value = double.tryParse(raw.replaceAll(',', '.'));
    }
    if (value == null) return quantity;
    final scaled = value * factor;
    final formatted = scaled == scaled.roundToDouble()
        ? scaled.toInt().toString()
        : scaled
              .toStringAsFixed(scaled < 10 ? 2 : 1)
              .replaceAll(RegExp(r'([.]\d*?)0+$'), r'$1')
              .replaceAll(RegExp(r'[.]$'), '');
    return quantity.trim().replaceFirst(raw, formatted);
  }

  void _changeServings(int base, int delta) {
    final current = _servingsOverride ?? base;
    final next = (current + delta).clamp(1, 20);
    setState(() => _servingsOverride = next == base ? null : next);
  }

  void _toggleStep(int index) {
    setState(() {
      if (_doneSteps.contains(index)) {
        _doneSteps.remove(index);
      } else {
        _doneSteps.add(index);
      }
    });
  }

  void _startStepTimer(int step, int minutes) {
    _stepTimer?.cancel();
    setState(() {
      _timerStep = step;
      _timerSecondsLeft = minutes * 60;
      _timerRunning = true;
    });
    _stepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timerSecondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _timerSecondsLeft = 0;
          _timerRunning = false;
        });
        showAppSnackBar(context, 'Temporizador del paso $step finalizado.');
      } else {
        setState(() => _timerSecondsLeft--);
      }
    });
  }

  void _toggleTimerPause() {
    if (_timerStep == null) return;
    if (_timerRunning) {
      _stepTimer?.cancel();
      setState(() => _timerRunning = false);
    } else if (_timerSecondsLeft > 0) {
      final step = _timerStep!;
      setState(() => _timerRunning = true);
      _stepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_timerSecondsLeft <= 1) {
          timer.cancel();
          setState(() {
            _timerSecondsLeft = 0;
            _timerRunning = false;
          });
          showAppSnackBar(context, 'Temporizador del paso $step finalizado.');
        } else {
          setState(() => _timerSecondsLeft--);
        }
      });
    }
  }

  void _stopTimer() {
    _stepTimer?.cancel();
    setState(() {
      _timerStep = null;
      _timerSecondsLeft = 0;
      _timerRunning = false;
    });
  }

  String _formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _showTimerSheet(int step) async {
    int minutes = 5;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Temporizador - Paso $step',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: minutes > 1
                            ? () => setModalState(() => minutes--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$minutes min',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                        ),
                      ),
                      IconButton(
                        onPressed: minutes < 120
                            ? () => setModalState(() => minutes++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in [1, 5, 10, 15, 20])
                        ChoiceChip(
                          label: Text('$m min'),
                          selected: minutes == m,
                          onSelected: (_) => setModalState(() => minutes = m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _startStepTimer(step, minutes);
                      },
                      icon: const Icon(Icons.timer_outlined),
                      label: const Text('Iniciar temporizador'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _share(Recipe recipe) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              '${recipe.title}\n\n${recipe.description}\n\nFuente: ${recipe.sourceUrl}',
          subject: recipe.title,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir la receta.')),
      );
    }
  }

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  Future<void> _addMissingToShopping(
    List<RecipeIngredient> missing,
    IngredientCatalog? catalog,
    Recipe recipe,
  ) async {
    final items = [
      for (final m in missing)
        ShoppingItem(
          name: catalog?.labelForKey(m.key) ?? m.key,
          key: m.key,
          quantity: m.quantityText,
          recipeId: recipe.id,
          recipeTitle: recipe.title,
        ),
    ];
    await ref.read(shoppingListProvider.notifier).addMissing(items: items);
    if (!mounted) return;
    showAppSnackBar(
      context,
      '${items.length} ingrediente${items.length == 1 ? '' : 's'} agregado${items.length == 1 ? '' : 's'} a la lista de compras.',
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.goldBright,
              letterSpacing: 0.7,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.gold),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _IngredientLine extends StatelessWidget {
  const _IngredientLine({
    required this.name,
    required this.quantity,
    this.isMissing = false,
  });

  final String name;
  final String quantity;
  final bool isMissing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isMissing ? Icons.shopping_bag_outlined : Icons.check_circle_outline,
          size: 17,
          color: isMissing ? AppColors.gold : AppColors.success,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            quantity.isEmpty ? name : '$name — $quantity',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.text,
    required this.done,
    required this.onToggle,
    required this.onTimer,
  });

  final int number;
  final String text;
  final bool done;
  final VoidCallback onToggle;
  final VoidCallback onTimer;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: done
                  ? AppColors.success.withValues(alpha: 0.18)
                  : AppColors.gold.withValues(alpha: 0.18),
              child: done
                  ? const Icon(Icons.check, size: 16, color: AppColors.success)
                  : Text(
                      '$number',
                      style: const TextStyle(
                        color: AppColors.goldBright,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: done ? AppColors.textSecondary : AppColors.textPrimary,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Temporizador',
              onPressed: onTimer,
              icon: const Icon(Icons.timer_outlined, size: 20),
              color: AppColors.gold,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          icon,
          size: 14,
          color: onTap == null ? AppColors.border : AppColors.gold,
        ),
      ),
    );
  }
}

class _Nutrient extends StatelessWidget {
  const _Nutrient({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

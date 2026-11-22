import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatcanicook/core/async_value_ext.dart';
import 'package:whatcanicook/core/config.dart';
import 'package:whatcanicook/core/result.dart';
import 'package:whatcanicook/core/routes.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/ingredient.dart';
import 'package:whatcanicook/models/ingredient_catalog.dart';
import 'package:whatcanicook/models/recipe.dart';
import 'package:whatcanicook/navigation/app_shell.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/services/recipe_matcher.dart';
import 'package:whatcanicook/utils/feedback.dart';
import 'package:whatcanicook/widgets/app_logo.dart';
import 'package:whatcanicook/widgets/category_tile.dart';
import 'package:whatcanicook/widgets/food_image.dart';
import 'package:whatcanicook/widgets/recipe_card.dart';
import 'package:whatcanicook/widgets/section_header.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _scanning = false;
  final ScrollController _categoryScrollController = ScrollController();

  @override
  void dispose() {
    _categoryScrollController.dispose();
    super.dispose();
  }

  static const List<_Category> _categories = [
    _Category(
      label: 'Desayunos',
      tag: 'desayuno',
      icon: Icons.wb_sunny_outlined,
    ),
    _Category(
      label: 'Comidas',
      tag: 'comida',
      icon: Icons.lunch_dining_outlined,
    ),
    _Category(label: 'Cenas', tag: 'cena', icon: Icons.dinner_dining_outlined),
    _Category(label: 'Postres', tag: 'postres', icon: Icons.cake_outlined),
    _Category(label: 'Ensaladas', tag: 'ensaladas', icon: Icons.eco_outlined),
    _Category(
      label: 'Bebidas',
      tag: 'bebidas',
      icon: Icons.local_drink_outlined,
    ),
    _Category(
      label: 'Saludables',
      tag: 'saludable',
      icon: Icons.favorite_outline,
    ),
    _Category(label: 'Rápidas', tag: 'rapida', icon: Icons.bolt_outlined),
    _Category(
      label: 'Económicas',
      tag: 'economica',
      icon: Icons.savings_outlined,
    ),
    _Category(
      label: 'Alta proteína',
      tag: 'alta_en_proteinas',
      icon: Icons.fitness_center_outlined,
    ),
    _Category(
      label: 'Bajas calorías',
      tag: 'baja_en_calorias',
      icon: Icons.local_fire_department_outlined,
    ),
    _Category(
      label: 'Vegetariana',
      tag: 'vegetariana',
      icon: Icons.eco_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final recipesAsync = ref.watch(recipesProvider);
    final catalogAsync = ref.watch(ingredientCatalogProvider);
    final profileAsync = ref.watch(profileProvider);
    final favoritesAsync = ref.watch(favoritesProvider);
    final hiddenIds =
        ref
            .watch(hiddenRecipesProvider)
            .valueOrNull
            ?.map((h) => h.recipeId)
            .toSet() ??
        <String>{};

    final name = profileAsync.valueOrNull?.name.trim() ?? '';
    final greeting = name.isEmpty ? '¡Hola, cocinero!' : '¡Hola, $name!';

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AppLogo(height: 44),
                  _CircleAction(
                    icon: Icons.settings_outlined,
                    tooltip: 'Configuración',
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.settings),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                greeting,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tu cocina, tus ingredientes, tus próximas recetas.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              _FeaturedHero(
                onDiscover: () => ref
                    .read(navigationIndexProvider.notifier)
                    .select(AppShell.explore),
                onScan: () => ref
                    .read(navigationIndexProvider.notifier)
                    .select(AppShell.create),
              ),
              const SizedBox(height: 22),

              const SectionHeader(
                title: 'Reconoce tus ingredientes',
                subtitle: 'Toma una foto o elige una imagen de tu galería.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ScanAction(
                      icon: Icons.photo_camera_rounded,
                      label: 'Cámara',
                      subtitle: 'Tomar foto',
                      onTap: () => _openImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ScanAction(
                      icon: Icons.photo_library_outlined,
                      label: 'Galería',
                      subtitle: 'Elegir foto',
                      onTap: () => _openImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () =>
                    Navigator.of(context)
                        .pushNamed(AppRoutes.manualIngredients),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Prefiero ingresarlos manualmente'),
              ),
              const SizedBox(height: 22),

              const SectionHeader(
                title: 'Categorías',
                subtitle:
                    'Desliza horizontalmente para ver todas las categorías.',
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  SizedBox(
                    height: 104,
                    child: ListView.separated(
                      controller: _categoryScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 44),
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return CategoryTile(
                          icon: category.icon,
                          label: category.label,
                          onTap: () {
                            ref
                                .read(exploreCategoryProvider.notifier)
                                .set(category.tag);
                            ref
                                .read(navigationIndexProvider.notifier)
                                .select(AppShell.explore);
                          },
                        );
                      },
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        width: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0x00161618), AppColors.background],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 3,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _CircleAction(
                        icon: Icons.arrow_forward_ios_rounded,
                        tooltip: 'Ver más categorías',
                        onTap: _scrollCategories,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ingredientsAsync.when(
                data: (items) {
                  final preview = items.take(5).toList();
                  final remaining = items.length - preview.length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeader(
                        title: 'Mis ingredientes',
                        subtitle: items.isEmpty
                            ? 'Aún no tienes ingredientes guardados.'
                            : '${items.length} ingrediente${items.length == 1 ? '' : 's'} en tu lista.',
                        action: TextButton(
                          onPressed: () => items.isEmpty
                              ? Navigator.of(context)
                                    .pushNamed(AppRoutes.manualIngredients)
                              : _showIngredientsSheet(items),
                          child: Text(items.isEmpty ? 'Agregar' : 'Ver todos'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              'Agrega ingredientes con cámara, galería o manualmente para ver recetas personalizadas.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        )
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < preview.length;
                                        i++
                                      ) ...[
                                        InputChip(
                                          label: Text(preview[i].name),
                                          onDeleted: preview[i].id == null
                                              ? null
                                              : () => ref
                                                    .read(
                                                      ingredientsProvider
                                                          .notifier,
                                                    )
                                                    .remove(preview[i].id!),
                                          deleteIcon: const Icon(
                                            Icons.close_rounded,
                                            size: 16,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        if (i != preview.length - 1 ||
                                            remaining > 0)
                                          const SizedBox(width: 8),
                                      ],
                                      if (remaining > 0)
                                        ActionChip(
                                          label: Text('+$remaining más'),
                                          onPressed: () =>
                                              _showIngredientsSheet(items),
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.touch_app_outlined,
                                      size: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Desliza para verlos, toca "+ más" para ver todos o editar.',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const SectionHeader(
                  title: 'Mis ingredientes',
                  subtitle: 'Cargando ingredientes...',
                ),
                error: (_, _) => const SectionHeader(
                  title: 'Mis ingredientes',
                  subtitle: 'No se pudieron cargar los ingredientes.',
                ),
              ),
              const SizedBox(height: 24),

              ingredientsAsync.when(
                data: (items) => SectionHeader(
                  title: items.isEmpty
                      ? 'Recetas destacadas'
                      : 'Recomendadas para ti',
                  subtitle: items.isEmpty
                      ? 'Fuentes oficiales verificadas. Agrega ingredientes para ver coincidencias.'
                      : 'Con base en ${items.length} ingredientes de tu lista.',
                  action: TextButton(
                    onPressed: () => ref
                        .read(navigationIndexProvider.notifier)
                        .select(AppShell.explore),
                    child: const Text('Ver todas'),
                  ),
                ),
                loading: () => const SectionHeader(
                  title: 'Recetas destacadas',
                  subtitle: 'Cargando tus ingredientes...',
                ),
                error: (_, _) => const SectionHeader(
                  title: 'Recetas destacadas',
                  subtitle: 'No se pudo leer la lista de ingredientes.',
                ),
              ),
              const SizedBox(height: 14),

              recipesAsync.when(
                data: (recipes) => ingredientsAsync.when(
                  data: (ingredients) {
                    final catalog = catalogAsync.valueOrNull;
                    final available = <String>{
                      for (final ingredient in ingredients)
                        _keyFor(ingredient, catalog),
                    }..removeWhere((key) => key.isEmpty);

                    final visibleRecipes = recipes
                        .where((recipe) => !hiddenIds.contains(recipe.id))
                        .toList();
                    final matches = const RecipeMatcher()
                        .match(
                          recipes: visibleRecipes,
                          availableKeys: available,
                        )
                        .take(4)
                        .toList();
                    final favoriteIds =
                        favoritesAsync.valueOrNull
                            ?.map((item) => item.recipeId)
                            .toSet() ??
                        <String>{};

                    return Column(
                      children: [
                        for (final match in matches) ...[
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
                    'No se pudo cargar la recomendación.',
                    style: TextStyle(color: AppColors.textSecondary),
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
        ),
        if (_scanning)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0xB3161618),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Analizando ingredientes con IA...',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _scrollCategories() {
    final controller = _categoryScrollController;
    if (!controller.hasClients) return;
    final target = (controller.offset + 342).clamp(
      0.0,
      controller.position.maxScrollExtent,
    );
    controller.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
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

  void _showIngredientsSheet(List<Ingredient> items) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final current =
                    ref.watch(ingredientsProvider).valueOrNull ?? items;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Mis ingredientes (${current.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.of(context)
                                  .pushNamed(AppRoutes.manualIngredients);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Administrar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: current.isEmpty
                            ? const Center(
                                child: Text(
                                  'No tienes ingredientes guardados.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: current.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = current[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.kitchen_outlined,
                                        color: AppColors.gold,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                      item.name,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle:
                                        item.quantity == null ||
                                            item.quantity!.isEmpty
                                        ? null
                                        : Text(
                                            item.quantity!,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                    trailing: IconButton(
                                      tooltip: 'Eliminar',
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: item.id == null
                                          ? null
                                          : () => ref
                                                .read(
                                                  ingredientsProvider.notifier,
                                                )
                                                .remove(item.id!),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openImage(ImageSource source) async {
    if (_scanning) return;
    if (!AppConfig.visionConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El análisis de fotos no está disponible en este momento. '
            'Puedes agregar ingredientes manualmente.',
          ),
        ),
      );
      return;
    }

    setState(() => _scanning = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked == null) {
        if (mounted) setState(() => _scanning = false);
        return;
      }
      final result = await ref
          .read(visionServiceProvider)
          .analyze(File(picked.path));
      if (!mounted) return;

      switch (result) {
        case AppSuccess(:final value):
          ref.read(scanDraftProvider.notifier).set(value.ingredients);
          ref
              .read(lastAnalysisInfoProvider.notifier)
              .set(
                'Modelo: ${value.model}${value.warning != null ? ' · ${value.warning}' : ''}',
              );
          setState(() => _scanning = false);
          Navigator.of(context).pushNamed(AppRoutes.scanResult);

        case AppFailure(:final message):
          setState(() => _scanning = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la imagen.')),
      );
    }
  }

  String _keyFor(Ingredient ingredient, IngredientCatalog? catalog) {
    if (ingredient.key != null && ingredient.key!.isNotEmpty) {
      return ingredient.key!;
    }
    return catalog?.resolveKey(ingredient.name) ?? '';
  }
}

class _Category {
  const _Category({required this.label, required this.tag, required this.icon});

  final String label;
  final String tag;
  final IconData icon;
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.gold, size: 21),
          ),
        ),
      ),
    );
  }
}

class _FeaturedHero extends StatelessWidget {
  const _FeaturedHero({required this.onDiscover, required this.onScan});

  final VoidCallback onDiscover;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FoodImage(
          imagePath: 'assets/images/recipes/myplate-frittata-jardin.jpg',
          height: 244,
          borderRadius: BorderRadius.circular(26),
          shade: BoxGradient.heroShade,
          semanticLabel: 'Fotografía de una frittata de verduras',
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.55),
                  ),
                ),
                child: const Text(
                  'IA + RECETAS VERIFICADAS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.goldBright,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '¿Qué cocinamos hoy?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.15,
                  shadows: [
                    Shadow(
                      color: Color(0xE6000000),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Descubre recetas increíbles con los ingredientes que tienes en casa.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFFF2EDE5),
                  shadows: [
                    Shadow(
                      color: Color(0xD9000000),
                      blurRadius: 8,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onDiscover,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Descubrir recetas'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.photo_camera_outlined, size: 17),
                label: const Text('Escanear ingredientes'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanAction extends StatelessWidget {
  const _ScanAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

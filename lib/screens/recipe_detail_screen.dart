import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whatcanicook/core/async_value_ext.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/services/recipe_matcher.dart';
import 'package:whatcanicook/utils/normalization.dart';

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesProvider);
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final favoritesAsync = ref.watch(favoritesProvider);
    final catalogAsync = ref.watch(ingredientCatalogProvider);

    return Scaffold(
      body: recipesAsync.when(
        data: (recipes) {
          final recipe = recipes
              .where((item) => item.id == recipeId)
              .firstOrNull;
          if (recipe == null) {
            return const Center(child: Text('No se encontró la receta.'));
          }
          final isFavorite =
              favoritesAsync.valueOrNull?.any((f) => f.recipeId == recipe.id) ??
              false;

          final availableKeys =
              ingredientsAsync.valueOrNull
                  ?.map((ingredient) => ingredient.key ?? '')
                  .toSet() ??
              <String>{};
          final match = const RecipeMatcher()
              .match(recipes: [recipe], availableKeys: availableKeys)
              .first;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 230,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: recipe.imageUrl == null
                      ? Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.orange, AppColors.orangeDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.restaurant_menu_rounded,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: recipe.imageUrl!,
                          fit: BoxFit.cover,
                        ),
                ),
                actions: [
                  IconButton(
                    tooltip: isFavorite
                        ? 'Quitar de favoritos'
                        : 'Guardar en favoritos',
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? AppColors.error : Colors.white,
                    ),
                    onPressed: () =>
                        ref.read(favoritesProvider.notifier).toggle(recipe.id),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.verified,
                            size: 18,
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Fuente verificada: ${recipe.sourceName}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recipe.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.charcoal,
                            ),
                      ),
                      if (recipe.originalTitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Título original: ${recipe.originalTitle}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.gray,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        recipe.description,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.gray,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _InfoRow(
                        prep: formatMinutes(recipe.prepMinutes),
                        cook: formatMinutes(recipe.cookMinutes),
                        difficulty: recipe.difficulty,
                        servings: '${recipe.servings} porciones',
                      ),
                      if (recipe.difficultyIsEstimated) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'La dificultad es una estimación de la app; la fuente no la publica.',
                          style: TextStyle(fontSize: 11, color: AppColors.gray),
                        ),
                      ],
                      const SizedBox(height: 24),

                      _SectionTitle(title: 'Ingredientes'),
                      const SizedBox(height: 10),
                      for (final ingredient in recipe.ingredients) ...[
                        _IngredientLine(
                          name:
                              catalogAsync.valueOrNull?.labelForKey(
                                ingredient.key,
                              ) ??
                              ingredient.key,
                          quantity: ingredient.quantityText,
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 20),

                      _SectionTitle(title: 'Ingredientes que te faltan'),
                      const SizedBox(height: 10),
                      if (match.missing.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.greenSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: AppColors.green),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '¡Tienes todos los ingredientes de esta receta!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final missing in match.missing) ...[
                          _IngredientLine(
                            name:
                                catalogAsync.valueOrNull?.labelForKey(
                                  missing.key,
                                ) ??
                                missing.key,
                            quantity: missing.quantityText,
                            isMissing: true,
                          ),
                          const SizedBox(height: 8),
                        ],
                      const SizedBox(height: 24),

                      _SectionTitle(title: 'Preparación'),
                      const SizedBox(height: 10),
                      for (var i = 0; i < recipe.steps.length; i++) ...[
                        _Step(number: i + 1, text: recipe.steps[i]),
                        const SizedBox(height: 10),
                      ],

                      if (recipe.nutrition.hasAny) ...[
                        const SizedBox(height: 24),
                        _SectionTitle(title: 'Información nutricional'),
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(
                              spacing: 20,
                              runSpacing: 12,
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
                          style: TextStyle(fontSize: 11, color: AppColors.gray),
                        ),
                      ],

                      const SizedBox(height: 26),
                      _SectionTitle(title: 'Fuente original'),
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
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.charcoal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                recipe.originalSource,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _openSource(recipe.sourceUrl),
                                icon: const Icon(Icons.open_in_new),
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
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: AppColors.orangeDark,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.prep,
    required this.cook,
    required this.difficulty,
    required this.servings,
  });

  final String prep;
  final String cook;
  final String difficulty;
  final String servings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Info(icon: Icons.timer_outlined, label: 'Prep', value: prep),
        ),
        Expanded(
          child: _Info(
            icon: Icons.local_fire_department_outlined,
            label: 'Cocción',
            value: cook,
          ),
        ),
        Expanded(
          child: _Info(
            icon: Icons.signal_cellular_alt,
            label: 'Nivel',
            value: difficulty,
          ),
        ),
        Expanded(
          child: _Info(
            icon: Icons.people_outline,
            label: 'Porciones',
            value: servings,
          ),
        ),
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
      children: [
        Icon(icon, size: 20, color: AppColors.orange),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.gray),
        ),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.charcoal,
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
          size: 18,
          color: isMissing ? AppColors.orange : AppColors.green,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            quantity.isEmpty ? name : '$name — $quantity',
            style: const TextStyle(fontSize: 14, color: AppColors.charcoal),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.orange,
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.charcoal,
            ),
          ),
        ),
      ],
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
          style: const TextStyle(fontSize: 11, color: AppColors.gray),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.charcoal,
          ),
        ),
      ],
    );
  }
}

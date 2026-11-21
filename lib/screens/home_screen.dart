import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/async_value_ext.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/ingredient.dart';
import 'package:whatcanicook/models/ingredient_catalog.dart';
import 'package:whatcanicook/navigation/app_shell.dart';
import 'package:whatcanicook/core/routes.dart';
import 'package:whatcanicook/services/recipe_matcher.dart';
import 'package:whatcanicook/widgets/app_logo.dart';
import 'package:whatcanicook/widgets/recipe_card.dart';
import 'package:whatcanicook/widgets/section_header.dart';
import 'package:whatcanicook/providers/app_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final recipesAsync = ref.watch(recipesProvider);
    final catalogAsync = ref.watch(ingredientCatalogProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppLogo(height: 54),
              IconButton(
                tooltip: 'Configuración',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '¡Hola! ¿Qué hay en tu cocina hoy?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toma una foto o escribe tus ingredientes y descubre recetas '
            'verificadas que puedes preparar.',
            style: TextStyle(fontSize: 15, color: AppColors.gray, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Botón principal.
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [AppColors.orange, AppColors.orangeDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () =>
                    ref.read(navigationIndexProvider.notifier).select(1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 26,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¿QU�? PUEDO COCINAR?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Escanea tu refrigerador con IA',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Accesos rápidos.
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.edit_note_rounded,
                  label: 'Ingredientes',
                  subtitle: 'Selección manual',
                  onTap: () =>
                      Navigator.of(context)
                          .pushNamed(AppRoutes.manualIngredients),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Recetas',
                  subtitle: 'Generador inteligente',
                  onTap: () =>
                      ref.read(navigationIndexProvider.notifier).select(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.favorite_rounded,
                  label: 'Favoritos',
                  subtitle: 'Tus recetas guardadas',
                  onTap: () =>
                      ref.read(navigationIndexProvider.notifier).select(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.history_rounded,
                  label: 'Historial',
                  subtitle: 'Búsquedas recientes',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.history),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          ingredientsAsync.when(
            data: (items) {
              final count = items.length;
              return SectionHeader(
                title: count == 0
                    ? 'Recetas destacadas'
                    : 'Recomendadas para ti',
                subtitle: count == 0
                    ? 'Fuente: MyPlate (USDA). Agrega ingredientes para ver coincidencias.'
                    : 'Con base en $count ingredientes de tu lista.',
                action: TextButton(
                  onPressed: () =>
                      ref.read(navigationIndexProvider.notifier).select(2),
                  child: const Text('Ver todas'),
                ),
              );
            },
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
            data: (recipes) {
              return ingredientsAsync.when(
                data: (ingredients) {
                  final catalog = catalogAsync.valueOrNull;
                  final available = <String>{
                    for (final ingredient in ingredients)
                      _keyFor(ingredient, catalog),
                  }..removeWhere((key) => key.isEmpty);

                  final matches = const RecipeMatcher().match(
                    recipes: recipes,
                    availableKeys: available,
                  );
                  final top = matches.take(4).toList();

                  return Column(
                    children: [
                      for (final match in top) ...[
                        RecipeCard(
                          match: match,
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    const Text('No se pudo cargar la recomendación.'),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Error al cargar recetas: $error'),
          ),
        ],
      ),
    );
  }

  String _keyFor(Ingredient ingredient, IngredientCatalog? catalog) {
    if (ingredient.key != null && ingredient.key!.isNotEmpty) {
      return ingredient.key!;
    }
    return catalog?.resolveKey(ingredient.name) ?? '';
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.orange, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.gray,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/async_value_ext.dart';
import 'package:whatcanicook/core/routes.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/user_profile.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/widgets/empty_state.dart';
import 'package:whatcanicook/widgets/food_image.dart';
import 'package:whatcanicook/widgets/section_header.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Favoritos',
            subtitle: 'Recetas guardadas, disponibles sin conexión.',
            action: favoritesAsync.valueOrNull?.isEmpty ?? true
                ? null
                : IconButton(
                    tooltip: 'Vaciar favoritos',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () => _confirmClear(context, ref),
                  ),
          ),
          const SizedBox(height: 16),
          favoritesAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'Aún no tienes favoritos',
                  message: 'Guarda recetas desde su detalle para verlas aquí.',
                );
              }
              return Column(
                children: [
                  for (final item in items) ...[
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: FoodImage(
                          imagePath: item.imageUrl,
                          width: 68,
                          height: 68,
                          borderRadius: BorderRadius.circular(12),
                          semanticLabel: 'Fotografía de ${item.title}',
                        ),
                        title: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          item.sourceName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Quitar de favoritos',
                          icon: const Icon(
                            Icons.favorite,
                            color: AppColors.danger,
                          ),
                          onPressed: () => _confirmRemove(context, ref, item),
                        ),
                        onTap: () => Navigator.of(context).pushNamed(
                          AppRoutes.recipeDetail,
                          arguments: item.recipeId,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
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
            error: (error, _) => Text(
              'Error: $error',
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    FavoriteRecipe item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Quitar de favoritos?'),
        content: Text('Se eliminará "${item.title}" de tu lista guardada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(favoritesProvider.notifier).remove(item.recipeId);
    }
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Vaciar favoritos?'),
        content: const Text(
          'Se eliminarán todas las recetas guardadas en este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final items = ref.read(favoritesProvider).valueOrNull ?? const [];
      for (final item in items) {
        await ref.read(favoritesProvider.notifier).remove(item.recipeId);
      }
    }
  }
}

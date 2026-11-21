import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/routes.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/widgets/empty_state.dart';
import 'package:whatcanicook/widgets/section_header.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Favoritos',
            subtitle: 'Recetas guardadas de fuentes oficiales.',
          ),
          const SizedBox(height: 16),
          favoritesAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'Aún no tienes favoritos',
                  message: 'Guarda recetas desde su pantalla de detalle para verlas aquí.',
                );
              }
              return Column(
                children: [
                  for (final item in items) ...[
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.cream,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.restaurant_menu,
                            color: AppColors.orange,
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          item.sourceName,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          tooltip: 'Eliminar de favoritos',
                          icon: const Icon(
                            Icons.favorite,
                            color: AppColors.error,
                          ),
                          onPressed: () => ref
                              .read(favoritesProvider.notifier)
                              .remove(item.recipeId),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          ),
        ],
      ),
    );
  }
}

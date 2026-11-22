import 'package:flutter/material.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/recipe_match.dart';
import 'package:whatcanicook/utils/normalization.dart';
import 'package:whatcanicook/widgets/food_image.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.match,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteTap,
  });

  final RecipeMatch match;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    final percent = (match.matchScore * 100).round();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                FoodImage(
                  imagePath: recipe.imageUrl,
                  height: 148,
                  borderRadius: BorderRadius.zero,
                  showBottomShade: true,
                  semanticLabel: 'Fotografía de ${recipe.title}',
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      '$percent% coincidencia',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.goldBright,
                      ),
                    ),
                  ),
                ),
                if (onFavoriteTap != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      tooltip: isFavorite
                          ? 'Quitar de favoritos'
                          : 'Guardar en favoritos',
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite
                            ? AppColors.danger
                            : AppColors.textPrimary,
                      ),
                      onPressed: onFavoriteTap,
                    ),
                  ),
                Positioned(
                  bottom: 10,
                  left: 14,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppColors.goldBright,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        formatMinutes(recipe.totalMinutes),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${match.missingCount} faltantes · ${recipe.sourceName}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardRaised,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          recipe.difficulty,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.goldBright,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

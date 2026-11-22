import 'package:flutter/material.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/recipe.dart';
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
    this.hasIngredients = false,
    this.onHideTap,
    this.isHidden = false,
  });

  final RecipeMatch match;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;

  /// Si el usuario tiene ingredientes activos se muestra la coincidencia;
  /// si no, se priorizan categoría, tiempo y dificultad.
  final bool hasIngredients;
  final VoidCallback? onHideTap;
  final bool isHidden;

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    final percent = (match.matchScore * 100).round();
    final showMatch = hasIngredients;
    final badgeLabel = showMatch
        ? '$percent% coincidencia'
        : _primaryCategory(recipe);

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
                  top: 10,
                  left: 12,
                  child: _CardBadge(label: badgeLabel, highlighted: showMatch),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onHideTap != null)
                        _OverlayIconButton(
                          icon: isHidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          tooltip: isHidden
                              ? 'Mostrar platillo'
                              : 'Ocultar platillo',
                          color: AppColors.textSecondary,
                          onTap: onHideTap,
                        ),
                      if (onHideTap != null && onFavoriteTap != null)
                        const SizedBox(width: 5),
                      if (onFavoriteTap != null)
                        _OverlayIconButton(
                          icon: isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          tooltip: isFavorite
                              ? 'Quitar de favoritos'
                              : 'Guardar en favoritos',
                          color: isFavorite
                              ? AppColors.danger
                              : AppColors.textPrimary,
                          onTap: onFavoriteTap,
                        ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 12,
                  child: _TimeChip(label: _shortTime(recipe)),
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MetaChip(
                        icon: Icons.signal_cellular_alt_rounded,
                        label: recipe.difficulty,
                      ),
                      if (showMatch)
                        _MetaChip(
                          icon: match.missingCount == 0
                              ? Icons.check_circle_outline
                              : Icons.shopping_basket_outlined,
                          label: match.missingCount == 0
                              ? 'Todo listo'
                              : '${match.missingCount} faltantes',
                          color: match.missingCount == 0
                              ? AppColors.success
                              : null,
                        ),
                      _MetaChip(
                        icon: Icons.verified_outlined,
                        label: recipe.sourceName,
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

  static String _shortTime(Recipe recipe) {
    final minutes = recipe.totalMinutes;
    if (minutes == null) return 'Sin tiempo';
    return formatMinutes(minutes);
  }

  static String _primaryCategory(Recipe recipe) {
    const labels = <String, String>{
      'desayuno': 'Desayuno',
      'comida': 'Comida',
      'cena': 'Cena',
      'postres': 'Postre',
      'ensaladas': 'Ensalada',
      'bebidas': 'Bebida',
      'saludable': 'Saludable',
      'rapida': 'Rápida',
    };
    for (final tag in recipe.tags) {
      final label = labels[tag];
      if (label != null) return label;
    }
    return 'Receta verificada';
  }
}

class _CardBadge extends StatelessWidget {
  const _CardBadge({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            highlighted
                ? Icons.auto_awesome_rounded
                : Icons.restaurant_menu_outlined,
            size: 12,
            color: AppColors.goldBright,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.goldBright,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 13,
            color: AppColors.goldBright,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textSecondary;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: AppColors.cardRaised,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color ?? AppColors.gold),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.background.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

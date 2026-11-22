import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:whatcanicook/core/theme.dart';

/// Imagen de comida con fallback elegante.
///
/// Usa assets locales cuando la ruta es relativa y una URL remota solo si el
/// backend llegara a devolverla. Nunca deja un espacio vacío.
class FoodImage extends StatelessWidget {
  const FoodImage({
    super.key,
    required this.imagePath,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showBottomShade = false,
    this.shade,
    this.semanticLabel,
  });

  final String? imagePath;
  final double? height;
  final double? width;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showBottomShade;

  /// Degradado personalizado (por ejemplo, más oscuro para texto sobre foto).
  final BoxDecoration? shade;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    final path = imagePath?.trim() ?? '';

    Widget image;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      image = CachedNetworkImage(
        imageUrl: path,
        fit: fit,
        width: width,
        height: height,
        placeholder: (_, _) => const ShimmerPlaceholder(),
        errorWidget: (_, _, _) => const ElegantFoodFallback(),
      );
    } else if (path.isNotEmpty) {
      image = Image.asset(
        path,
        fit: fit,
        width: width,
        height: height,
        semanticLabel: semanticLabel,
        errorBuilder: (_, _, _) => const ElegantFoodFallback(),
      );
    } else {
      image = const ElegantFoodFallback();
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (shade != null) DecoratedBox(decoration: shade!),
            if (shade == null && showBottomShade)
              const DecoratedBox(decoration: BoxGradient.bottomShade),
          ],
        ),
      ),
    );
  }
}

class ShimmerPlaceholder extends StatelessWidget {
  const ShimmerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.card, AppColors.cardRaised, AppColors.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class ElegantFoodFallback extends StatelessWidget {
  const ElegantFoodFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.cardRaised, AppColors.card, AppColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.45),
                ),
              ),
              child: const Icon(
                Icons.restaurant_rounded,
                color: AppColors.gold,
                size: 30,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Imagen no disponible',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

abstract final class BoxGradient {
  static const bottomShade = BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.transparent, Color(0xB3161618)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  /// Degradado intenso para la tarjeta destacada: mantiene legibles el título
  /// y la descripción incluso sobre zonas claras de la fotografía.
  static const heroShade = BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Color(0x80161618),
        Color(0xD9161618),
        Color(0xF2161618),
        Color(0xFA161618),
      ],
      stops: [0.0, 0.42, 0.72, 1.0],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );
}

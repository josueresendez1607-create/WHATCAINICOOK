import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/routes.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/widgets/app_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Precarga catálogo, recetas verificadas y base de datos local.
    await Future.wait([
      ref.read(ingredientCatalogProvider.future).then((_) {}),
      ref.read(recipesProvider.future).then((_) {}),
      ref.read(ingredientsProvider.future).then((_) {}),
    ]);

    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(height: 92),
              SizedBox(height: 18),
              Text(
                'Descubre qué puedes cocinar hoy',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 0.4,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 34),
              SizedBox(
                width: 180,
                child: LinearProgressIndicator(minHeight: 4),
              ),
              SizedBox(height: 14),
              Text(
                'Preparando tu cocina...',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

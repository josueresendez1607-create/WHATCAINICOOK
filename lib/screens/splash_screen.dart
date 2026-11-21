import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/routes.dart';
import 'package:whatcanicook/providers/app_providers.dart';

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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              image: AssetImage('assets/images/splash.png'),
              width: 280,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 28),
            SizedBox(width: 180, child: LinearProgressIndicator(minHeight: 4)),
            SizedBox(height: 14),
            Text(
              'Preparando tu cocina...',
              style: TextStyle(color: Color(0xFF6F6560)),
            ),
          ],
        ),
      ),
    );
  }
}

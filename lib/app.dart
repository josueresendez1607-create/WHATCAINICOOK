import 'package:flutter/material.dart';
import 'package:whatcanicook/core/config.dart';
import 'package:whatcanicook/core/routes.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/navigation/app_shell.dart';
import 'package:whatcanicook/screens/favorites_screen.dart';
import 'package:whatcanicook/screens/history_screen.dart';
import 'package:whatcanicook/screens/manual_ingredients_screen.dart';
import 'package:whatcanicook/screens/recipe_detail_screen.dart';
import 'package:whatcanicook/screens/scan_result_screen.dart';
import 'package:whatcanicook/screens/settings_screen.dart';
import 'package:whatcanicook/screens/splash_screen.dart';

class WhatCanICookApp extends StatelessWidget {
  const WhatCanICookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.home: (_) => const AppShell(),
        AppRoutes.manualIngredients: (_) => const ManualIngredientsScreen(),
        AppRoutes.history: (_) => const HistoryScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case AppRoutes.scanResult:
            return MaterialPageRoute(
              builder: (_) => const ScanResultScreen(),
              settings: settings,
            );
          case AppRoutes.recipeDetail:
            final recipeId = settings.arguments as String? ?? '';
            return MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipeId: recipeId),
              settings: settings,
            );
          case AppRoutes.favorites:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Favoritos')),
                body: const SafeArea(child: FavoritesScreen()),
              ),
              settings: settings,
            );
          default:
            return null;
        }
      },
    );
  }
}

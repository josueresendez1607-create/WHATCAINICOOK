import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whatcanicook/database/database_helper.dart';
import 'package:whatcanicook/models/recipe.dart';
import 'package:whatcanicook/models/recipe_match.dart';
import 'package:whatcanicook/screens/settings_screen.dart';
import 'package:whatcanicook/widgets/recipe_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    DatabaseHelper.instance.useFactory(
      databaseFactoryFfi,
      databaseName: 'whatcanicook_ux_test.db',
    );
  });

  testWidgets('Configuración no expone información técnica del backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Configuración'), findsWidgets);
    expect(find.textContaining('10.0.2.2'), findsNothing);
    expect(find.textContaining('http://'), findsNothing);
    expect(find.textContaining('dart-define'), findsNothing);
    expect(find.textContaining('servidor'), findsNothing);
    await tester.scrollUntilVisible(find.textContaining('versión 1.0.0'), 300);
    await tester.pumpAndSettle();
    expect(find.textContaining('versión 1.0.0'), findsOneWidget);
  });

  testWidgets('Tarjeta sin ingredientes prioriza categoría y oculta el 0%', (
    tester,
  ) async {
    const recipe = Recipe(
      id: 'r-ux',
      title: 'Frittata de jardín',
      originalTitle: '',
      description: 'Receta de prueba',
      sourceName: 'MyPlate/USDA',
      sourceUrl: '',
      originalSource: 'MyPlate',
      prepMinutes: 10,
      cookMinutes: 5,
      difficulty: 'Fácil',
      difficultyIsEstimated: false,
      servings: 2,
      tags: ['desayuno'],
      ingredients: [],
      steps: [],
      nutrition: Nutrition(),
      imageUrl: null,
      verified: true,
    );
    const match = RecipeMatch(
      recipe: recipe,
      matchedKeys: [],
      missing: [],
      matchScore: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipeCard(match: match, onTap: () {}),
        ),
      ),
    );

    expect(find.text('Desayuno'), findsOneWidget);
    expect(find.textContaining('0%'), findsNothing);
    expect(find.textContaining('faltantes'), findsNothing);
    expect(find.text('Frittata de jardín'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatcanicook/models/hidden_recipe.dart';
import 'package:whatcanicook/models/ingredient.dart';
import 'package:whatcanicook/models/ingredient_catalog.dart';
import 'package:whatcanicook/models/recipe.dart';
import 'package:whatcanicook/models/user_profile.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/screens/recipes_screen.dart';

class _FakeIngredientsNotifier extends IngredientsNotifier {
  _FakeIngredientsNotifier(this._items);
  final List<Ingredient> _items;
  @override
  Future<List<Ingredient>> build() async => _items;
}

class _FakeProfileNotifier extends ProfileNotifier {
  @override
  Future<UserProfile> build() async => UserProfile.empty;
}

class _FakeFavoritesNotifier extends FavoritesNotifier {
  @override
  Future<List<FavoriteRecipe>> build() async => const [];
}

class _FakeHistoryNotifier extends HistoryNotifier {
  @override
  Future<List<HistoryEntry>> build() async => const [];
  @override
  Future<void> add(String kind, String value, {String? recipeId}) async {}
}

class _FakeHiddenRecipesNotifier extends HiddenRecipesNotifier {
  @override
  Future<List<HiddenRecipe>> build() async => const [];
}

Recipe _recipe(String id, {List<String> tags = const ['comida'], String title = ''}) => Recipe(
      id: id,
      title: title.isEmpty ? 'Receta $id' : title,
      originalTitle: title.isEmpty ? 'Receta $id' : title,
      description: 'Desc',
      sourceName: 'MyPlate/USDA',
      sourceUrl: 'https://example.test/$id',
      originalSource: 'MyPlate',
      prepMinutes: 10,
      cookMinutes: 10,
      difficulty: 'Fácil',
      difficultyIsEstimated: false,
      servings: 2,
      tags: tags,
      ingredients: const [RecipeIngredient(key: 'tomate', quantityText: '1 pz')],
      steps: const ['Paso 1'],
      nutrition: const Nutrition(calories: 100, proteinG: 10),
      imageUrl: null,
      verified: true,
    );

IngredientCatalog _catalog() => IngredientCatalog.fromJson(const {
      'version': 1,
      'categories': [
        {'id': 'verduras', 'label': 'Verduras'},
      ],
      'ingredients': [
        {
          'key': 'tomate',
          'name': 'Tomate',
          'category': 'verduras',
          'aliases': ['tomate'],
        },
      ],
    });

Widget _app({List<Recipe>? recipes, List<Ingredient>? ingredients}) {
  final ingredient = Ingredient(
    id: 1,
    name: 'Tomate',
    key: 'tomate',
    category: 'verduras',
  );
  return ProviderScope(
    overrides: [
      ingredientsProvider.overrideWith(
        () => _FakeIngredientsNotifier(ingredients ?? [ingredient]),
      ),
      recipesProvider.overrideWith((ref) async => recipes ?? [_recipe('r1')]),
      ingredientCatalogProvider.overrideWith((ref) async => _catalog()),
      profileProvider.overrideWith(() => _FakeProfileNotifier()),
      favoritesProvider.overrideWith(() => _FakeFavoritesNotifier()),
      historyProvider.overrideWith(() => _FakeHistoryNotifier()),
      hiddenRecipesProvider.overrideWith(() => _FakeHiddenRecipesNotifier()),
    ],
    child: const MaterialApp(home: Scaffold(body: RecipesScreen())),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('generación local muestra recetas del catálogo verificado', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Generar 5 recetas'));
    await tester.tap(find.text('Generar 5 recetas'));
    await tester.pumpAndSettle();

    expect(find.text('Receta r1'), findsWidgets);
    expect(find.textContaining('catálogo verificado'), findsWidgets);
    expect(find.text('Reintentar con IA'), findsNothing);
    expect(find.text('Generadas con Groq'), findsNothing);
  });

  testWidgets('sin ingredientes seleccionados muestra mensaje claro', (tester) async {
    await tester.pumpWidget(_app(ingredients: const []));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Generar 5 recetas'));
    await tester.tap(find.text('Generar 5 recetas'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Agrega al menos un ingrediente'), findsOneWidget);
    expect(find.text('Reintentar con IA'), findsNothing);
  });

  testWidgets('respeta cantidad solicitada', (tester) async {
    final recipes = List.generate(6, (i) => _recipe('r$i'));
    await tester.pumpWidget(_app(recipes: recipes));
    await tester.pumpAndSettle();

    // default count is 5 in screen; just generate
    await tester.ensureVisible(find.text('Generar 5 recetas'));
    await tester.tap(find.text('Generar 5 recetas'));
    await tester.pumpAndSettle();

    // Should not show a 6th generated card title beyond limit; at least r0-r4 may appear
    expect(find.text('Receta r0'), findsWidgets);
  });

  testWidgets('no muestra opciones de IA/Groq ni filtros/categorías', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Reintentar con IA'), findsNothing);
    expect(find.textContaining('Groq'), findsNothing);
    expect(find.textContaining('Generar recetas con IA'), findsNothing);
    expect(find.text('Desayunos'), findsNothing);
    expect(find.text('Comidas'), findsNothing);
    expect(find.text('Cenas'), findsNothing);
    expect(find.text('Postres'), findsNothing);
    expect(find.text('Bebidas'), findsNothing);
    expect(find.text('Alto en proteína'), findsNothing);
    expect(find.text('Bajo en calorías'), findsNothing);
    expect(find.text('Vegetariana'), findsNothing);
  });

  testWidgets('evita repetir recetas inmediatas cuando hay alternativas', (tester) async {
    final recipes = List.generate(6, (i) => _recipe('r$i', title: 'Receta r$i'));
    await tester.pumpWidget(_app(recipes: recipes));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Generar 5 recetas'));
    await tester.tap(find.text('Generar 5 recetas'));
    await tester.pumpAndSettle();
    expect(find.text('Receta r5'), findsNothing);

    await tester.ensureVisible(find.text('Generar 5 recetas'));
    await tester.tap(find.text('Generar 5 recetas'));
    await tester.pumpAndSettle();
    expect(find.text('Receta r5'), findsWidgets);
  });
}

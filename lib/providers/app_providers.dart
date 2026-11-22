import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/models/hidden_recipe.dart';
import 'package:whatcanicook/models/ingredient.dart';
import 'package:whatcanicook/models/user_profile.dart';
import 'package:whatcanicook/repositories/favorite_repository.dart';
import 'package:whatcanicook/repositories/hidden_recipe_repository.dart';
import 'package:whatcanicook/repositories/history_repository.dart';
import 'package:whatcanicook/repositories/ingredient_repository.dart';
import 'package:whatcanicook/repositories/profile_repository.dart';
import 'package:whatcanicook/services/catalog_service.dart';
import 'package:whatcanicook/services/recipe_generation_service.dart';
import 'package:whatcanicook/services/vision_service.dart';

final catalogServiceProvider = Provider((ref) => CatalogService());
final ingredientRepositoryProvider = Provider((ref) => IngredientRepository());
final favoriteRepositoryProvider = Provider((ref) => FavoriteRepository());
final historyRepositoryProvider = Provider((ref) => HistoryRepository());
final hiddenRecipeRepositoryProvider = Provider(
  (ref) => HiddenRecipeRepository(),
);
final profileRepositoryProvider = Provider((ref) => ProfileRepository());
final visionServiceProvider = Provider((ref) => VisionService());
final recipeGenerationServiceProvider = Provider(
  (ref) => RecipeGenerationService(),
);

/// Categoría solicitada desde Home. RecipesScreen la consume y la limpia.
final exploreCategoryProvider =
    NotifierProvider<ExploreCategoryNotifier, String?>(
      ExploreCategoryNotifier.new,
    );

class ExploreCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? category) => state = category;
  void clear() => state = null;
}

final ingredientCatalogProvider = FutureProvider((ref) {
  return ref.watch(catalogServiceProvider).loadCatalog();
});

final recipesProvider = FutureProvider((ref) {
  return ref.watch(catalogServiceProvider).loadRecipes();
});

final ingredientsProvider =
    AsyncNotifierProvider<IngredientsNotifier, List<Ingredient>>(
      IngredientsNotifier.new,
    );

class IngredientsNotifier extends AsyncNotifier<List<Ingredient>> {
  @override
  Future<List<Ingredient>> build() =>
      ref.read(ingredientRepositoryProvider).all();

  Future<void> add(Ingredient ingredient) async {
    await _update(() async {
      await ref.read(ingredientRepositoryProvider).add(ingredient);
    });
  }

  Future<void> addMany(List<Ingredient> items) async {
    await _update(() async {
      await ref.read(ingredientRepositoryProvider).addMany(items);
    });
  }

  Future<void> updateItem(Ingredient ingredient) async {
    await _update(() async {
      await ref.read(ingredientRepositoryProvider).update(ingredient);
    });
  }

  Future<void> remove(int id) async {
    await _update(() async {
      await ref.read(ingredientRepositoryProvider).delete(id);
    });
  }

  Future<void> clear() async {
    await _update(() async {
      await ref.read(ingredientRepositoryProvider).clear();
    });
  }

  Future<void> _update(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await action();
      return ref.read(ingredientRepositoryProvider).all();
    });
  }
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<FavoriteRecipe>>(
      FavoritesNotifier.new,
    );

class FavoritesNotifier extends AsyncNotifier<List<FavoriteRecipe>> {
  @override
  Future<List<FavoriteRecipe>> build() =>
      ref.read(favoriteRepositoryProvider).all();

  Future<bool> isFavorite(String recipeId) =>
      ref.read(favoriteRepositoryProvider).isFavorite(recipeId);

  Future<void> toggle(String recipeId) async {
    final repo = ref.read(favoriteRepositoryProvider);
    if (await repo.isFavorite(recipeId)) {
      await repo.remove(recipeId);
    } else {
      final recipes = await ref.read(recipesProvider.future);
      final recipe = recipes.where((item) => item.id == recipeId).firstOrNull;
      if (recipe == null) return;
      await repo.save(recipe);
    }
    ref.invalidateSelf();
  }

  Future<void> remove(String recipeId) async {
    await ref.read(favoriteRepositoryProvider).remove(recipeId);
    ref.invalidateSelf();
  }

  Future<void> restore(FavoriteRecipe item) async {
    await ref.read(favoriteRepositoryProvider).restore(item);
    ref.invalidateSelf();
  }
}

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<HistoryEntry>>(
      HistoryNotifier.new,
    );

class HistoryNotifier extends AsyncNotifier<List<HistoryEntry>> {
  @override
  Future<List<HistoryEntry>> build() =>
      ref.read(historyRepositoryProvider).recent();

  Future<void> add(String kind, String value, {String? recipeId}) async {
    await ref
        .read(historyRepositoryProvider)
        .add(kind, value, recipeId: recipeId);
    ref.invalidateSelf();
  }

  Future<void> remove(int id) async {
    await ref.read(historyRepositoryProvider).remove(id);
    ref.invalidateSelf();
  }

  Future<void> restore(HistoryEntry entry) async {
    await ref.read(historyRepositoryProvider).restore(entry);
    ref.invalidateSelf();
  }

  Future<void> clear() async {
    await ref.read(historyRepositoryProvider).clear();
    ref.invalidateSelf();
  }
}

/// Platillos que el usuario ocultó de todos los listados.
final hiddenRecipesProvider =
    AsyncNotifierProvider<HiddenRecipesNotifier, List<HiddenRecipe>>(
      HiddenRecipesNotifier.new,
    );

class HiddenRecipesNotifier extends AsyncNotifier<List<HiddenRecipe>> {
  @override
  Future<List<HiddenRecipe>> build() =>
      ref.read(hiddenRecipeRepositoryProvider).all();

  Future<void> hide(String recipeId, String title) => _update(
    () => ref.read(hiddenRecipeRepositoryProvider).hide(recipeId, title),
  );

  Future<void> unhide(String recipeId) =>
      _update(() => ref.read(hiddenRecipeRepositoryProvider).unhide(recipeId));

  Future<void> clear() =>
      _update(() => ref.read(hiddenRecipeRepositoryProvider).clear());

  Future<void> _update(Future<Object?> Function() action) async {
    state = await AsyncValue.guard(() async {
      await action();
      return ref.read(hiddenRecipeRepositoryProvider).all();
    });
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, UserProfile>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() => ref.read(profileRepositoryProvider).load();

  Future<void> save(UserProfile profile) async {
    await ref.read(profileRepositoryProvider).save(profile);
    state = AsyncData(profile);
  }
}

/// Borrador de ingredientes detectados por la IA, editable por el usuario.
final scanDraftProvider =
    NotifierProvider<ScanDraftNotifier, List<DetectedIngredient>>(
      ScanDraftNotifier.new,
    );

class ScanDraftNotifier extends Notifier<List<DetectedIngredient>> {
  @override
  List<DetectedIngredient> build() => const [];

  void set(List<DetectedIngredient> items) => state = List.unmodifiable(items);
  void add(DetectedIngredient item) => state = [...state, item];

  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    state = [...state.sublist(0, index), ...state.sublist(index + 1)];
  }

  void updateName(int index, String name) {
    if (index < 0 || index >= state.length) return;
    final item = state[index];
    state = [
      ...state.sublist(0, index),
      DetectedIngredient(
        name: name,
        key: item.key,
        confidence: item.confidence,
        quantity: item.quantity,
        unit: item.unit,
        category: item.category,
      ),
      ...state.sublist(index + 1),
    ];
  }

  void updateQuantity(int index, String quantity) {
    if (index < 0 || index >= state.length) return;
    final item = state[index];
    state = [
      ...state.sublist(0, index),
      DetectedIngredient(
        name: item.name,
        key: item.key,
        confidence: item.confidence,
        quantity: quantity.isEmpty ? null : quantity,
        unit: item.unit,
        category: item.category,
      ),
      ...state.sublist(index + 1),
    ];
  }

  void clear() => state = const [];
}

final lastAnalysisInfoProvider =
    NotifierProvider<LastAnalysisInfoNotifier, String?>(
      LastAnalysisInfoNotifier.new,
    );

class LastAnalysisInfoNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? info) => state = info;
}

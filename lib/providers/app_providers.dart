import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:whatcanicook/core/async_value_ext.dart';
import 'package:whatcanicook/models/hidden_recipe.dart';
import 'package:whatcanicook/models/ingredient.dart';
import 'package:whatcanicook/models/shopping_item.dart';
import 'package:whatcanicook/models/user_profile.dart';
import 'package:whatcanicook/repositories/ai_cache_repository.dart';
import 'package:whatcanicook/repositories/backend_config_repository.dart';
import 'package:whatcanicook/repositories/cooking_session_repository.dart';
import 'package:whatcanicook/repositories/favorite_repository.dart';
import 'package:whatcanicook/repositories/hidden_recipe_repository.dart';
import 'package:whatcanicook/repositories/history_repository.dart';
import 'package:whatcanicook/repositories/ingredient_repository.dart';
import 'package:whatcanicook/repositories/profile_repository.dart';
import 'package:whatcanicook/repositories/shopping_list_repository.dart';
import 'package:whatcanicook/services/ai_connection_service.dart';
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
final aiCacheRepositoryProvider = Provider((ref) => AiCacheRepository());
final shoppingListRepositoryProvider = Provider(
  (ref) => ShoppingListRepository(),
);
final cookingSessionRepositoryProvider = Provider(
  (ref) => CookingSessionRepository(),
);
final backendConfigRepositoryProvider = Provider(
  (ref) => BackendConfigRepository(),
);

final backendBaseUrlProvider =
    AsyncNotifierProvider<BackendBaseUrlNotifier, String>(
      BackendBaseUrlNotifier.new,
    );

class BackendBaseUrlNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() =>
      ref.read(backendConfigRepositoryProvider).getBaseUrl();

  Future<void> set(String value) async {
    await ref.read(backendConfigRepositoryProvider).setBaseUrl(value);
    state = AsyncData(
      await ref.read(backendConfigRepositoryProvider).getBaseUrl(),
    );
  }

  /// Actualiza el estado tras descubrimiento automático (ya persistido).
  void setDiscovered(String normalizedUrl) {
    state = AsyncData(normalizedUrl);
  }
}

final aiConnectionServiceProvider = ChangeNotifierProvider<AiConnectionService>(
  (ref) {
    final repo = ref.read(backendConfigRepositoryProvider);
    final service = AiConnectionService(
      configRepository: repo,
      onBaseUrlChanged: (url) async {
        ref.read(backendBaseUrlProvider.notifier).setDiscovered(url);
      },
    );
    // Inicia descubrimiento en segundo plano; no bloquea UI.
    unawaited(service.start());
    return service;
  },
);

final aiConnectionSnapshotProvider = Provider<AiConnectionSnapshot>((ref) {
  return ref.watch(aiConnectionServiceProvider).snapshot;
});

final visionServiceProvider = Provider((ref) {
  final baseUrl = ref.watch(backendBaseUrlProvider).valueOrNull ?? '';
  return VisionService(
    baseUrl: baseUrl,
    cache: ref.read(aiCacheRepositoryProvider),
  );
});

final recipeGenerationServiceProvider = Provider((ref) {
  final baseUrl = ref.watch(backendBaseUrlProvider).valueOrNull ?? '';
  return RecipeGenerationService(
    baseUrl: baseUrl,
    cache: ref.read(aiCacheRepositoryProvider),
  );
});

/// IDs de recetas mostradas en la última generación (en memoria) para evitar
/// repeticiones inmediatas cuando existan otras coincidencias.
final lastGeneratedRecipeIdsProvider =
    NotifierProvider<LastGeneratedRecipeIdsNotifier, List<String>>(
      LastGeneratedRecipeIdsNotifier.new,
    );

class LastGeneratedRecipeIdsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void setIds(List<String> ids) => state = List.unmodifiable(ids);
  void clear() => state = const [];
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

  String _norm(String v) => v
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[áàäâã]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöôõ]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll(RegExp(r'ñ'), 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  bool _isDuplicate(List<Ingredient> current, Ingredient ingredient) {
    final key = (ingredient.key ?? '').trim().toLowerCase();
    final name = _norm(ingredient.name);
    for (final existing in current) {
      final eKey = (existing.key ?? '').trim().toLowerCase();
      if (key.isNotEmpty && eKey.isNotEmpty && key == eKey) return true;
      if (name.isNotEmpty && _norm(existing.name) == name) return true;
    }
    return false;
  }

  Future<bool> add(Ingredient ingredient) async {
    final current = state.valueOrNull ?? await ref.read(ingredientRepositoryProvider).all();
    if (_isDuplicate(current, ingredient)) return false;
    await _update(() async {
      await ref.read(ingredientRepositoryProvider).add(ingredient);
    });
    return true;
  }

  Future<void> addMany(List<Ingredient> items) async {
    await _update(() async {
      final current = await ref.read(ingredientRepositoryProvider).all();
      final merged = <Ingredient>[...current];
      for (final item in items) {
        if (_isDuplicate(merged, item)) continue;
        final added = await ref.read(ingredientRepositoryProvider).add(item);
        merged.add(added);
      }
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
        uncertain: item.uncertain,
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
        uncertain: item.uncertain,
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

final shoppingListProvider =
    AsyncNotifierProvider<ShoppingListNotifier, List<ShoppingItem>>(
      ShoppingListNotifier.new,
    );

class ShoppingListNotifier extends AsyncNotifier<List<ShoppingItem>> {
  @override
  Future<List<ShoppingItem>> build() =>
      ref.read(shoppingListRepositoryProvider).all();

  Future<void> add(ShoppingItem item) async {
    await _update(() => ref.read(shoppingListRepositoryProvider).add(item));
  }

  Future<void> addMissing({required List<ShoppingItem> items}) async {
    if (items.isEmpty) return;
    await _update(
      () => ref.read(shoppingListRepositoryProvider).addMany(items),
    );
  }

  Future<void> toggle(int id, bool checked) async {
    await _update(
      () => ref.read(shoppingListRepositoryProvider).toggleChecked(id, checked),
    );
  }

  Future<void> remove(int id) async {
    await _update(() => ref.read(shoppingListRepositoryProvider).remove(id));
  }

  Future<void> clearChecked() async {
    await _update(
      () => ref.read(shoppingListRepositoryProvider).clearChecked(),
    );
  }

  Future<void> clearAll() async {
    await _update(() => ref.read(shoppingListRepositoryProvider).clearAll());
  }

  Future<void> _update(Future<void> Function() action) async {
    state = await AsyncValue.guard(() async {
      await action();
      return ref.read(shoppingListRepositoryProvider).all();
    });
  }
}

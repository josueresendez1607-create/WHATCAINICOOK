import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whatcanicook/database/database_helper.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/repositories/hidden_recipe_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    DatabaseHelper.instance.useFactory(
      databaseFactoryFfi,
      databaseName: 'whatcanicook_hidden_test.db',
    );
  });

  test('ocultar, consultar, restaurar y limpiar persisten en SQLite', () async {
    final repo = HiddenRecipeRepository();
    await repo.clear();

    expect(await repo.isHidden('receta-1'), isFalse);

    await repo.hide('receta-1', 'Frittata de jardín');
    expect(await repo.isHidden('receta-1'), isTrue);

    var items = await repo.all();
    expect(items, hasLength(1));
    expect(items.first.recipeId, 'receta-1');
    expect(items.first.title, 'Frittata de jardín');

    await repo.hide('receta-2', 'Ensalada de garbanzos');
    expect(await repo.all(), hasLength(2));

    expect(await repo.unhide('receta-1'), 1);
    expect(await repo.isHidden('receta-1'), isFalse);
    expect(await repo.all(), hasLength(1));

    expect(await repo.clear(), 1);
    expect(await repo.all(), isEmpty);
  });

  test('hiddenRecipesProvider expone los cambios realizados', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(hiddenRecipesProvider.notifier);
    await notifier.clear();
    await notifier.hide('receta-3', 'Tostadas de aguacate');

    final items = await container.read(hiddenRecipesProvider.future);
    expect(items, hasLength(1));
    expect(items.first.recipeId, 'receta-3');

    await notifier.unhide('receta-3');
    final after = await container.read(hiddenRecipesProvider.future);
    expect(after, isEmpty);
  });
}

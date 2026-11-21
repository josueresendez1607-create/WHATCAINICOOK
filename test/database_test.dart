import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whatcanicook/database/database_helper.dart';
import 'package:whatcanicook/models/ingredient.dart';
import 'package:whatcanicook/models/user_profile.dart';
import 'package:whatcanicook/repositories/ingredient_repository.dart';
import 'package:whatcanicook/repositories/profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    DatabaseHelper.instance.useFactory(databaseFactoryFfi);
  });

  test('CRUD de ingredientes y persistencia local', () async {
    final repo = IngredientRepository();
    await repo.clear();

    final added = await repo.add(
      const Ingredient(
        name: 'Tomate',
        category: 'verduras',
        quantity: '2',
        key: 'tomate',
        source: 'manual',
      ),
    );
    expect(added.id, isNotNull);

    var items = await repo.all();
    expect(items.length, 1);
    expect(items.first.name, 'Tomate');

    await repo.update(added.copyWith(quantity: '3'));
    items = await repo.all();
    expect(items.first.quantity, '3');

    await repo.delete(added.id!);
    items = await repo.all();
    expect(items, isEmpty);
  });

  test('perfil y preferencias se conservan', () async {
    final profileRepo = ProfileRepository();

    await profileRepo.save(const UserProfile(name: 'Josué', vegetarian: true));
    final profile = await profileRepo.load();
    expect(profile.name, 'Josué');
    expect(profile.vegetarian, isTrue);

    await profileRepo.writePreference('tema', 'claro');
    expect(await profileRepo.readPreference('tema'), 'claro');
  });
}

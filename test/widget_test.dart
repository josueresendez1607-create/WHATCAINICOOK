import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:whatcanicook/app.dart';
import 'package:whatcanicook/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    DatabaseHelper.instance.useFactory(databaseFactoryFfi);
  });

  testWidgets('la app inicia y muestra la pantalla de carga', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WhatCanICookApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Preparando tu cocina...'), findsOneWidget);
  });
}

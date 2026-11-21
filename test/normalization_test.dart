import 'package:flutter_test/flutter_test.dart';
import 'package:whatcanicook/utils/normalization.dart';

void main() {
  group('normalizeIngredient', () {
    test('quita acentos, mayúsculas y espacios extra', () {
      expect(normalizeIngredient('  Tomátes  CHERRY '), 'tomates cherry');
      expect(normalizeIngredient('AJO'), 'ajo');
      expect(normalizeIngredient('pimiento\nrojo'), 'pimiento rojo');
    });

    test('singulariza formas simples', () {
      expect(singularize('tomates'), 'tomate');
      expect(singularize('papas'), 'papa');
      expect(singularize('ajo'), 'ajo');
    });

    test('formatea minutos', () {
      expect(formatMinutes(20), '20 min');
      expect(formatMinutes(120), '2 h');
      expect(formatMinutes(90), '1 h 30 min');
      expect(formatMinutes(null), 'No indicado por la fuente');
    });
  });
}

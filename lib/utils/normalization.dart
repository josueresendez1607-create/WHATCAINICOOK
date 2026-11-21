const Map<String, String> _diacritics = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'ã': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
  'ý': 'y',
  'ÿ': 'y',
};

/// Normaliza un nombre de ingrediente para poder compararlo de forma estable.
String normalizeIngredient(String value) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacritics[char] ?? char);
  }

  return buffer
      .toString()
      .replaceAll(RegExp(r'[\s_\-]+'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Quita plurales simples en español/inglés para mejorar la coincidencia.
String singularize(String normalized) {
  if (normalized.length <= 4) return normalized;
  if (normalized.endsWith('es')) {
    final withoutS = normalized.substring(0, normalized.length - 1);
    // "tomates" -> "tomate", pero "limones" -> "limon".
    if (withoutS.endsWith('e')) return withoutS;
    return normalized.substring(0, normalized.length - 2);
  }
  if (normalized.endsWith('s')) {
    return normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

String titleCase(String value) {
  if (value.isEmpty) return value;
  return value
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String formatMinutes(int? minutes) {
  if (minutes == null) return 'No indicado por la fuente';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours h';
  return '$hours h $rest min';
}

import 'package:whatcanicook/utils/normalization.dart';

class Ingredient {
  const Ingredient({
    this.id,
    required this.name,
    this.category = 'otros',
    this.quantity,
    this.unit,
    this.key,
    this.source,
    this.createdAt,
  });

  final int? id;
  final String name;

  final String category;
  final String? quantity;
  final String? unit;
  final String? key;
  final String? source;
  final DateTime? createdAt;

  String get normalizedName => normalizeIngredient(name);

  Ingredient copyWith({
    int? id,
    String? name,
    String? category,
    String? quantity,
    String? unit,
    String? key,
    String? source,
    DateTime? createdAt,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      key: key ?? this.key,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'quantity': quantity,
    'unit': unit,
    'key': key,
    'source': source,
    'created_at': createdAt?.millisecondsSinceEpoch,
  };

  factory Ingredient.fromMap(Map<String, Object?> map) {
    final created = map['created_at'];
    return Ingredient(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'otros',
      quantity: map['quantity'] as String?,
      unit: map['unit'] as String?,
      key: map['key'] as String?,
      source: map['source'] as String?,
      createdAt: created is int
          ? DateTime.fromMillisecondsSinceEpoch(created)
          : null,
    );
  }
}

class DetectedIngredient {
  const DetectedIngredient({
    required this.name,
    this.key,
    this.confidence,
    this.quantity,
    this.unit,
    this.category,
  });

  final String name;
  final String? key;
  final double? confidence;
  final String? quantity;
  final String? unit;
  final String? category;

  factory DetectedIngredient.fromJson(Map<String, dynamic> json) {
    final rawConfidence = json['confidence'];
    return DetectedIngredient(
      name: json['name'] as String? ?? '',
      key: json['key'] as String?,
      confidence: rawConfidence is num ? rawConfidence.toDouble() : null,
      quantity: json['quantity'] as String?,
      unit: json['unit'] as String?,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'key': key,
    'confidence': confidence,
    'quantity': quantity,
    'unit': unit,
    'category': category,
  };

  Ingredient toIngredient() => Ingredient(
    name: name,
    category: category ?? 'otros',
    quantity: quantity,
    unit: unit,
    key: key,
    source: 'ia',
  );
}

class ShoppingItem {
  const ShoppingItem({
    this.id,
    required this.name,
    this.key,
    this.quantity,
    this.checked = false,
    this.recipeId,
    this.recipeTitle,
    this.createdAt,
  });

  final int? id;
  final String name;
  final String? key;
  final String? quantity;
  final bool checked;
  final String? recipeId;
  final String? recipeTitle;
  final int? createdAt;

  ShoppingItem copyWith({
    int? id,
    String? name,
    String? key,
    String? quantity,
    bool? checked,
    String? recipeId,
    String? recipeTitle,
    int? createdAt,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      key: key ?? this.key,
      quantity: quantity ?? this.quantity,
      checked: checked ?? this.checked,
      recipeId: recipeId ?? this.recipeId,
      recipeTitle: recipeTitle ?? this.recipeTitle,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'key': key,
    'quantity': quantity,
    'checked': checked ? 1 : 0,
    'recipe_id': recipeId,
    'recipe_title': recipeTitle,
    'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch,
  };

  factory ShoppingItem.fromMap(Map<String, Object?> map) => ShoppingItem(
    id: map['id'] as int?,
    name: (map['name'] as String?) ?? '',
    key: map['key'] as String?,
    quantity: map['quantity'] as String?,
    checked: (map['checked'] as int? ?? 0) == 1,
    recipeId: map['recipe_id'] as String?,
    recipeTitle: map['recipe_title'] as String?,
    createdAt: map['created_at'] as int?,
  );
}

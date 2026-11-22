import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/async_value_ext.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/ingredient.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/widgets/empty_state.dart';
import 'package:whatcanicook/widgets/section_header.dart';

class ManualIngredientsScreen extends ConsumerStatefulWidget {
  const ManualIngredientsScreen({super.key});

  @override
  ConsumerState<ManualIngredientsScreen> createState() =>
      _ManualIngredientsScreenState();
}

class _ManualIngredientsScreenState
    extends ConsumerState<ManualIngredientsScreen> {
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController();
  String _category = 'todos';

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _add(String name, String? key, String category) async {
    final quantity = _quantityController.text.trim();
    await ref
        .read(ingredientsProvider.notifier)
        .add(
          Ingredient(
            name: name,
            key: key,
            category: category,
            quantity: quantity.isEmpty ? null : quantity,
            unit: 'pz',
            source: 'manual',
          ),
        );
    _quantityController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$name agregado a tu lista.')));
    }
  }

  Future<void> _remove(Ingredient item) async {
    if (item.id == null) return;
    await ref.read(ingredientsProvider.notifier).remove(item.id!);
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Vaciar lista?'),
        content: const Text(
          'Se eliminarán todos los ingredientes guardados en este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(ingredientsProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(ingredientCatalogProvider);
    final selectedAsync = ref.watch(ingredientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis ingredientes'),
        actions: [
          selectedAsync.valueOrNull?.isEmpty ?? true
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Vaciar lista',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: _confirmClear,
                ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: SectionHeader(
                title: 'Agrega ingredientes',
                subtitle: 'Busca en el catálogo o escribe una cantidad.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Buscar ingrediente...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  hintText: 'Cantidad (opcional, se aplica al agregar)',
                  prefixIcon: Icon(Icons.numbers_outlined),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: catalogAsync.when(
                data: (catalog) => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: catalog.categories.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ChoiceChip(
                        label: const Text('Todos'),
                        selected: _category == 'todos',
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _category = 'todos'),
                      );
                    }
                    final category = catalog.categories[index - 1];
                    return ChoiceChip(
                      label: Text(category.label),
                      selected: _category == category.id,
                      showCheckmark: false,
                      onSelected: (_) =>
                          setState(() => _category = category.id),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(
                  child: Text(
                    'No se pudo cargar el catálogo.',
                    style: TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: catalogAsync.when(
                data: (catalog) {
                  final results = catalog.search(
                    _searchController.text,
                    categoryId: _category,
                  );
                  if (results.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Sin resultados',
                      message: 'Prueba con otro nombre o categoría.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.gold.withValues(
                              alpha: 0.13,
                            ),
                            child: Icon(
                              _iconFor(item.category),
                              color: AppColors.gold,
                              size: 19,
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            catalog.categoryLabel(item.category),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.add_circle_outline,
                            color: AppColors.goldBright,
                          ),
                          onTap: () => _add(item.name, item.key, item.category),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 18,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'En tu lista',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      selectedAsync.when(
                        data: (items) => Text(
                          '${items.length} ingredientes',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  selectedAsync.when(
                    data: (items) => items.isEmpty
                        ? const Text(
                            'Aún no agregas ingredientes.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : SizedBox(
                            height: 92,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Chip(
                                    avatar: const Icon(
                                      Icons.restaurant_outlined,
                                      size: 15,
                                      color: AppColors.gold,
                                    ),
                                    label: Text(
                                      item.quantity == null
                                          ? item.name
                                          : '${item.name} (${item.quantity})',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onDeleted: () => _remove(item),
                                    deleteIcon: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const Text(
                      'No se pudo cargar tu lista.',
                      style: TextStyle(color: AppColors.danger, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'carnes':
        return Icons.set_meal_outlined;
      case 'verduras':
        return Icons.eco_outlined;
      case 'frutas':
        return Icons.apple_outlined;
      case 'lacteos':
        return Icons.local_drink_outlined;
      case 'cereales':
        return Icons.grain_outlined;
      case 'legumbres':
        return Icons.eco_outlined;
      case 'condimentos':
        return Icons.spa_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }
}

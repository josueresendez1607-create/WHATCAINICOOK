import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/ingredient.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/widgets/empty_state.dart';

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

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(ingredientCatalogProvider);
    final selectedAsync = ref.watch(ingredientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis ingredientes'),
        actions: [
          selectedAsync.when(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Vaciar lista',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () async {
                      await ref.read(ingredientsProvider.notifier).clear();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lista vaciada.')),
                        );
                      }
                    },
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Buscar ingrediente...',
                  prefixIcon: Icon(Icons.search),
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
                data: (catalog) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _CategoryChip(
                      label: 'Todos',
                      selected: _category == 'todos',
                      onTap: () => setState(() => _category = 'todos'),
                    ),
                    for (final category in catalog.categories) ...[
                      const SizedBox(width: 8),
                      _CategoryChip(
                        label: category.label,
                        selected: _category == category.id,
                        onTap: () => setState(() => _category = category.id),
                      ),
                    ],
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Text('No se pudo cargar el catálogo.'),
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
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppColors.divider),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.cream,
                          child: Icon(
                            _iconFor(item.category),
                            color: AppColors.orange,
                            size: 20,
                          ),
                        ),
                        title: Text(item.name),
                        subtitle: Text(
                          catalog.categoryLabel(item.category),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(
                          Icons.add_circle,
                          color: AppColors.orange,
                        ),
                        onTap: () => _add(item.name, item.key, item.category),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const Spacer(),
                      selectedAsync.when(
                        data: (items) => Text(
                          '${items.length} ingredientes',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.gray,
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
                              fontSize: 13,
                              color: AppColors.gray,
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
                                    label: Text(
                                      item.quantity == null
                                          ? item.name
                                          : '${item.name} (${item.quantity})',
                                    ),
                                    onDeleted: () => ref
                                        .read(ingredientsProvider.notifier)
                                        .remove(item.id!),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 16,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const Text('No se pudo cargar tu lista.'),
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.orange.withValues(alpha: 0.18),
      showCheckmark: false,
    );
  }
}

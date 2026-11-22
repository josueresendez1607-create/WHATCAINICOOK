import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/shopping_item.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/utils/feedback.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(shoppingListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de compras'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              final notifier = ref.read(shoppingListProvider.notifier);
              if (value == 'checked') {
                await notifier.clearChecked();
                if (context.mounted) {
                  showAppSnackBar(context, 'Comprados eliminados.');
                }
              } else if (value == 'all') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Vaciar lista'),
                    content: const Text(
                      'Se eliminarán todos los artículos de la lista de compras.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Vaciar'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await notifier.clearAll();
                  if (context.mounted) {
                    showAppSnackBar(context, 'Lista de compras vaciada.');
                  }
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'checked',
                child: Text('Eliminar comprados'),
              ),
              PopupMenuItem(value: 'all', child: Text('Vaciar lista')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: 'Agregar artículo...',
                        prefixIcon: Icon(Icons.add_shopping_cart_outlined),
                      ),
                      onSubmitted: (_) => _addManual(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _addManual,
                    child: const Text('Agregar'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: itemsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Tu lista de compras está vacía.\nAgrega ingredientes faltantes desde una receta o escríbelos aquí.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  }
                  final pending = items.where((e) => !e.checked).toList();
                  final done = items.where((e) => e.checked).toList();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (pending.isNotEmpty) ...[
                        _SectionLabel(
                          title: 'Pendientes',
                          count: pending.length,
                        ),
                        const SizedBox(height: 8),
                        ...pending.map((item) => _ShoppingTile(item: item)),
                        const SizedBox(height: 16),
                      ],
                      if (done.isNotEmpty) ...[
                        _SectionLabel(title: 'Comprados', count: done.length),
                        const SizedBox(height: 8),
                        ...done.map((item) => _ShoppingTile(item: item)),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addManual() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await ref.read(shoppingListProvider.notifier).add(ShoppingItem(name: name));
    _controller.clear();
    if (mounted) showAppSnackBar(context, '$name agregado a la lista.');
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShoppingTile extends ConsumerWidget {
  const _ShoppingTile({required this.item});
  final ShoppingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = item.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: Checkbox(
          value: item.checked,
          onChanged: id == null
              ? null
              : (v) => ref
                    .read(shoppingListProvider.notifier)
                    .toggle(id, v ?? false),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            color: item.checked
                ? AppColors.textSecondary
                : AppColors.textPrimary,
            decoration: item.checked ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: item.recipeTitle == null || item.recipeTitle!.isEmpty
            ? null
            : Text(
                'Para: ${item.recipeTitle}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
        trailing: IconButton(
          tooltip: 'Eliminar',
          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          onPressed: id == null
              ? null
              : () => ref.read(shoppingListProvider.notifier).remove(id),
        ),
      ),
    );
  }
}

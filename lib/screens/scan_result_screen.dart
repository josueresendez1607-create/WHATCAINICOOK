import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/ingredient.dart';
import 'package:whatcanicook/navigation/app_shell.dart';
import 'package:whatcanicook/providers/app_providers.dart';

class ScanResultScreen extends ConsumerStatefulWidget {
  const ScanResultScreen({super.key});

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _showAddDialog() {
    _nameController.clear();
    _quantityController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar ingrediente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Cantidad (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;
              ref
                  .read(scanDraftProvider.notifier)
                  .add(
                    DetectedIngredient(
                      name: name,
                      quantity: _quantityController.text.trim().isEmpty
                          ? null
                          : _quantityController.text.trim(),
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    final items = ref.read(scanDraftProvider);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un ingrediente para continuar.'),
        ),
      );
      return;
    }

    final catalog = await ref.read(ingredientCatalogProvider.future);
    final ingredients = items.map((item) {
      final key = catalog.resolveKey(item.name);
      return Ingredient(
        name: item.name,
        key: key,
        category:
            catalog.itemForKey(key ?? '')?.category ?? item.category ?? 'otros',
        quantity: item.quantity,
        unit: item.unit,
        source: 'ia',
      );
    }).toList();

    await ref.read(ingredientsProvider.notifier).addMany(ingredients);
    await ref
        .read(historyProvider.notifier)
        .add('escaneo', '${items.length} ingredientes detectados');
    if (!mounted) return;

    ref.read(scanDraftProvider.notifier).clear();
    ref.read(navigationIndexProvider.notifier).select(2);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(scanDraftProvider);
    final info = ref.watch(lastAnalysisInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisa los ingredientes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8D6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  info ?? 'Revisa la lista: la IA puede confundir alimentos similares.',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay ingredientes detectados. Agrega uno manualmente.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      TextField(
                                        decoration: const InputDecoration(
                                          labelText: 'Ingrediente',
                                          isDense: true,
                                        ),
                                        controller: TextEditingController(
                                          text: item.name,
                                        ),
                                        onChanged: (value) => ref
                                            .read(scanDraftProvider.notifier)
                                            .updateName(index, value),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        decoration: InputDecoration(
                                          labelText:
                                              item.quantity ??
                                              'Cantidad (opcional)',
                                          isDense: true,
                                        ),
                                        controller: TextEditingController(
                                          text: item.quantity ?? '',
                                        ),
                                        onChanged: (value) => ref
                                            .read(scanDraftProvider.notifier)
                                            .updateQuantity(index, value),
                                      ),
                                      if (item.confidence != null) ...[
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.greenSoft,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Confianza: ${(item.confidence! * 100).round()}%',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.green,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () => ref
                                      .read(scanDraftProvider.notifier)
                                      .removeAt(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar ingrediente'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Confirmar y buscar recetas'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

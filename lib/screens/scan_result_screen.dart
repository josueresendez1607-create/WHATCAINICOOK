import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/ingredient.dart';
import 'package:whatcanicook/navigation/app_shell.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/widgets/empty_state.dart';
import 'package:whatcanicook/widgets/section_header.dart';

class ScanResultScreen extends ConsumerStatefulWidget {
  const ScanResultScreen({super.key});

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  bool _saving = false;

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
              decoration: const InputDecoration(
                labelText: 'Nombre del ingrediente',
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
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
    if (_saving) return;
    final items = ref.read(scanDraftProvider);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un ingrediente para continuar.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
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
    ref.read(navigationIndexProvider.notifier).select(AppShell.explore);
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
          icon: const Icon(Icons.arrow_back_rounded),
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
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.gold,
                      size: 19,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        info ?? 'Revisa la lista: la IA puede confundir alimentos similares.',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const EmptyState(
                      icon: Icons.restaurant_outlined,
                      title: 'Sin ingredientes',
                      message: 'Agrega uno manualmente para continuar.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _EditableIngredientCard(
                          key: ValueKey<int>(index),
                          item: item,
                          onNameChanged: (value) => ref
                              .read(scanDraftProvider.notifier)
                              .updateName(index, value),
                          onQuantityChanged: (value) => ref
                              .read(scanDraftProvider.notifier)
                              .updateQuantity(index, value),
                          onRemove: () => ref
                              .read(scanDraftProvider.notifier)
                              .removeAt(index),
                        );
                      },
                    ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SectionHeader(
                    title: 'Lista revisada',
                    subtitle:
                        'Puedes corregir cualquier nombre antes de continuar.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar ingrediente'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _confirm,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _saving ? 'Guardando...' : 'Confirmar y buscar recetas',
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
}

class _EditableIngredientCard extends StatefulWidget {
  const _EditableIngredientCard({
    super.key,
    required this.item,
    required this.onNameChanged,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final DetectedIngredient item;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  State<_EditableIngredientCard> createState() =>
      _EditableIngredientCardState();
}

class _EditableIngredientCardState extends State<_EditableIngredientCard> {
  late final TextEditingController _name;
  late final TextEditingController _quantity;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item.name);
    _quantity = TextEditingController(text: widget.item.quantity ?? '');
  }

  @override
  void didUpdateWidget(covariant _EditableIngredientCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_name.text != widget.item.name) {
      _name.text = widget.item.name;
    }
    final quantity = widget.item.quantity ?? '';
    if (_quantity.text != quantity) {
      _quantity.text = quantity;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confidence = widget.item.confidence;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  TextField(
                    controller: _name,
                    onChanged: widget.onNameChanged,
                    decoration: const InputDecoration(
                      labelText: 'Ingrediente',
                      isDense: true,
                      prefixIcon: Icon(Icons.label_outline, size: 18),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _quantity,
                    onChanged: widget.onQuantityChanged,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad (opcional)',
                      isDense: true,
                      prefixIcon: Icon(Icons.numbers_outlined, size: 18),
                    ),
                  ),
                  if (confidence != null || widget.item.uncertain) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (confidence != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cardRaised,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Confianza IA: ${(confidence * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.goldBright,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (widget.item.uncertain)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Text(
                              'Incierto: confirma o edita',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: widget.onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

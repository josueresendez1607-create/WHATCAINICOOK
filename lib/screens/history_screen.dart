import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/async_value_ext.dart';
import 'package:whatcanicook/core/routes.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/user_profile.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/utils/feedback.dart';
import 'package:whatcanicook/widgets/empty_state.dart';
import 'package:whatcanicook/widgets/section_header.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          historyAsync.valueOrNull?.isEmpty ?? true
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Borrar historial',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => _confirmClear(context, ref),
                ),
        ],
      ),
      body: SafeArea(
        child: historyAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.history_rounded,
                title: 'Sin actividad reciente',
                message:
                    'Tus búsquedas, escaneos y recetas vistas aparecerán aquí.',
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: SectionHeader(
                    title: 'Actividad reciente',
                    subtitle:
                        '${items.length} eventos guardados en este dispositivo.',
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isScan = item.kind == 'escaneo';
                      final isRecipe = item.kind == 'receta';

                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.gold.withValues(
                              alpha: 0.14,
                            ),
                            child: Icon(
                              isScan
                                  ? Icons.photo_camera_outlined
                                  : isRecipe
                                  ? Icons.restaurant_menu_outlined
                                  : Icons.auto_awesome_rounded,
                              color: AppColors.gold,
                              size: 19,
                            ),
                          ),
                          title: Text(
                            item.value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '${_kindLabel(item.kind)} · ${_dateLabel(item.createdAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Eliminar entrada',
                            icon: const Icon(
                              Icons.close_outlined,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                            onPressed: () =>
                                _removeWithUndo(context, ref, item),
                          ),
                          onTap: item.recipeId == null
                              ? null
                              : () => Navigator.of(context).pushNamed(
                                  AppRoutes.recipeDetail,
                                  arguments: item.recipeId,
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ],
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
    );
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'escaneo':
        return 'Escaneo';
      case 'receta':
        return 'Receta vista';
      case 'recetas':
        return 'Generación';
      default:
        return 'Búsqueda';
    }
  }

  String _dateLabel(DateTime date) {
    return '${date.day}/${date.month}/${date.year} · '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _removeWithUndo(
    BuildContext context,
    WidgetRef ref,
    HistoryEntry item,
  ) async {
    if (item.id == null) return;
    final id = item.id!;
    final notifier = ref.read(historyProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    await notifier.remove(id);
    showUndoSnackBar(
      null,
      messenger: messenger,
      message: 'Entrada eliminada del historial.',
      actionLabel: 'Deshacer',
      onUndo: () => notifier.restore(item),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Borrar historial?'),
        content: const Text(
          'Se eliminarán todos los eventos guardados en este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(historyProvider.notifier).clear();
    }
  }
}

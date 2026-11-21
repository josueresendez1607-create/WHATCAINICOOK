import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/widgets/empty_state.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            tooltip: 'Borrar historial',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => ref.read(historyProvider.notifier).clear(),
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
                message: 'Tus búsquedas y escaneos aparecerán aquí.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.cream,
                      child: Icon(
                        item.kind == 'escaneo'
                            ? Icons.photo_camera_outlined
                            : Icons.search,
                        color: AppColors.orange,
                        size: 20,
                      ),
                    ),
                    title: Text(item.value),
                    subtitle: Text(
                      '${item.kind == 'escaneo' ? 'Escaneo' : 'Búsqueda'} · '
                      '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}

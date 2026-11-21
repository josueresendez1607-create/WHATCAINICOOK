import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatcanicook/core/config.dart';
import 'package:whatcanicook/core/result.dart';
import 'package:whatcanicook/core/routes.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/providers/app_providers.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  File? _image;
  bool _loading = false;
  String? _message;

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      setState(() => _image = File(picked.path));
      await _analyze(File(picked.path));
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = 'No se pudo abrir la cámara o la galería: $error';
        });
      }
    }
  }

  Future<void> _analyze(File file) async {
    if (!AppConfig.visionConfigured) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message =
              'Análisis de IA no configurado. Puedes usar la selección manual.';
        });
      }
      return;
    }

    final result = await ref.read(visionServiceProvider).analyze(file);
    if (!mounted) return;

    switch (result) {
      case AppSuccess(:final value):
        ref.read(scanDraftProvider.notifier).set(value.ingredients);
        ref
            .read(lastAnalysisInfoProvider.notifier)
            .set(
              'Modelo: ${value.model}${value.warning != null ? ' · ${value.warning}' : ''}',
            );
        setState(() => _loading = false);
        Navigator.of(context).pushNamed(AppRoutes.scanResult);

      case AppFailure(:final message):
        setState(() {
          _loading = false;
          _message = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Escanea tus ingredientes',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toma una foto de tu refrigerador o selecciona una imagen de tu galería.',
            style: TextStyle(color: AppColors.gray, height: 1.4),
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppConfig.visionConfigured
                  ? AppColors.greenSoft
                  : const Color(0xFFFFE8D6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  AppConfig.visionConfigured
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  color: AppConfig.visionConfigured
                      ? AppColors.green
                      : AppColors.orangeDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppConfig.visionConfigured
                        ? 'Servicio de IA conectado. La clave permanece en el backend.'
                        : 'IA sin configurar. La selección manual funciona igual.',
                    style: const TextStyle(fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 230,
              color: AppColors.divider,
              child: _image == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 52,
                            color: AppColors.gray,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Aquí aparecerá tu foto',
                            style: TextStyle(color: AppColors.gray),
                          ),
                        ],
                      ),
                    )
                  : Image.file(
                      _image!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
            ),
          ),
          const SizedBox(height: 18),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Analizando imagen con IA...'),
                ],
              ),
            )
          else ...[
            ElevatedButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('Tomar foto'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Elegir de la galería'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.manualIngredients),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Ingresar ingredientes manualmente'),
            ),
          ],

          if (_message != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _message!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Nota: la IA puede cometer errores. Siempre podrás revisar, agregar '
            'o corregir los ingredientes antes de buscar recetas.',
            style: TextStyle(fontSize: 12, color: AppColors.gray, height: 1.4),
          ),
        ],
      ),
    );
  }
}

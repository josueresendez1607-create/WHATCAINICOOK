import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:whatcanicook/core/config.dart';
import 'package:whatcanicook/core/result.dart';
import 'package:whatcanicook/core/routes.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/widgets/section_header.dart';

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
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final file = File(picked.path);
      if (mounted) setState(() => _image = file);
      await _analyze(file);
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Crear con IA',
            subtitle:
                'Reconoce ingredientes desde una foto y revisa el resultado.',
          ),
          const SizedBox(height: 18),

          _StatusBanner(configured: AppConfig.visionConfigured),
          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 240,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: _image == null
                  ? const _EmptyPreview()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_image!, fit: BoxFit.cover),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Color(0xCC161618)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 16,
                          bottom: 14,
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: AppColors.goldBright,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Foto lista para analizar',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 18),

          if (_loading)
            const Card(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text(
                      'Analizando imagen con Gemini...',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Revisa, corrige y confirma los ingredientes.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            FilledButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('Tomar fotografía'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Elegir de la galería'),
            ),
            const SizedBox(height: 6),
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
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.cardRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _message!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),
          const SectionHeader(
            title: 'Cómo funciona',
            subtitle: 'Tu foto se procesa en el backend; la clave IA nunca viaja a la app.',
          ),
          const SizedBox(height: 10),
          const _InfoStep(
            number: '1',
            title: 'Elige una foto',
            body: 'Usa la cámara o la galería. La imagen se limita a 12 MB.',
          ),
          SizedBox(height: 8),
          const _InfoStep(
            number: '2',
            title: 'Revisa los ingredientes',
            body:
                'La IA puede equivocarse. Puedes corregir, agregar o eliminar.',
          ),
          SizedBox(height: 8),
          const _InfoStep(
            number: '3',
            title: 'Genera recetas',
            body:
                'Solo se seleccionan recetas verificadas del catálogo oficial.',
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.configured});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: configured
              ? AppColors.success.withValues(alpha: 0.45)
              : AppColors.gold.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            configured ? Icons.verified_user_outlined : Icons.info_outline,
            color: configured ? AppColors.success : AppColors.gold,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              configured
                  ? 'Servicio de IA conectado. La clave permanece en el backend.'
                  : 'IA sin configurar. La selección manual funciona igual.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.3,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.card, AppColors.cardRaised, AppColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 48,
              color: AppColors.gold,
            ),
            SizedBox(height: 12),
            Text(
              'Aquí aparecerá tu foto',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Cámara o galería',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoStep extends StatelessWidget {
  const _InfoStep({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.gold.withValues(alpha: 0.18),
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.goldBright,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: AppColors.textSecondary,
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

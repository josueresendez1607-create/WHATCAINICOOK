import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/routes.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/user_profile.dart';
import 'package:whatcanicook/providers/app_providers.dart';
import 'package:whatcanicook/widgets/app_logo.dart';
import 'package:whatcanicook/widgets/preference_toggle.dart';
import 'package:whatcanicook/widgets/section_header.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save(UserProfile updated) async {
    await ref.read(profileProvider.notifier).save(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil guardado en este dispositivo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      child: profileAsync.when(
        data: (profile) {
          if (_nameController.text != profile.name) {
            _nameController.text = profile.name;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const AppLogo(height: 40, showText: false),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name.isEmpty ? 'Tu perfil' : profile.name,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Preferencias guardadas localmente',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Configuración',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.settings),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const SectionHeader(
                title: 'Datos personales',
                subtitle: 'Tu nombre se usa solo para saludarte en la app.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: '¿Cómo te llamas?',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                onSubmitted: (value) =>
                    _save(profile.copyWith(name: value.trim())),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () => _save(
                    profile.copyWith(name: _nameController.text.trim()),
                  ),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Guardar nombre'),
                ),
              ),
              const SizedBox(height: 24),

              const SectionHeader(
                title: 'Preferencias alimenticias',
                subtitle:
                    'Se aplican al ordenar y filtrar recetas verificadas.',
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    PreferenceToggle(
                      icon: Icons.eco_outlined,
                      title: 'Vegetariano',
                      subtitle: 'Prioriza recetas sin carne ni pescado.',
                      value: profile.vegetarian,
                      onChanged: (value) =>
                          _save(profile.copyWith(vegetarian: value)),
                    ),
                    const Divider(height: 1),
                    PreferenceToggle(
                      icon: Icons.grain_outlined,
                      title: 'Sin gluten',
                      subtitle: 'Evita ingredientes con gluten conocido.',
                      value: profile.glutenFree,
                      onChanged: (value) =>
                          _save(profile.copyWith(glutenFree: value)),
                    ),
                    const Divider(height: 1),
                    PreferenceToggle(
                      icon: Icons.fitness_center_outlined,
                      title: 'Alto en proteínas',
                      subtitle: 'Prefiere recetas con más proteína.',
                      value: profile.highProtein,
                      onChanged: (value) =>
                          _save(profile.copyWith(highProtein: value)),
                    ),
                    const Divider(height: 1),
                    PreferenceToggle(
                      icon: Icons.local_fire_department_outlined,
                      title: 'Bajo en calorías',
                      subtitle: 'Prioriza opciones ligeras.',
                      value: profile.lowCalorie,
                      onChanged: (value) =>
                          _save(profile.copyWith(lowCalorie: value)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Estas preferencias no son recomendaciones médicas.',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),

              const SectionHeader(
                title: 'Tu actividad',
                subtitle:
                    'Accesos rápidos a datos guardados en el dispositivo.',
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _ProfileLink(
                      icon: Icons.favorite_border_rounded,
                      title: 'Mis favoritos',
                      subtitle: 'Recetas guardadas para ver sin conexión.',
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRoutes.favorites),
                    ),
                    const Divider(height: 1),
                    _ProfileLink(
                      icon: Icons.history_rounded,
                      title: 'Historial',
                      subtitle: 'Búsquedas, escaneos y recetas vistas.',
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRoutes.history),
                    ),
                    const Divider(height: 1),
                    _ProfileLink(
                      icon: Icons.settings_outlined,
                      title: 'Configuración',
                      subtitle: 'Estado de IA y datos locales.',
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRoutes.settings),
                    ),
                  ],
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
    );
  }
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gold),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}

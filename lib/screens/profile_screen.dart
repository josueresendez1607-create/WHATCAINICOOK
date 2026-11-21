import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatcanicook/core/routes.dart';
import 'package:whatcanicook/core/theme.dart';
import 'package:whatcanicook/models/user_profile.dart';
import 'package:whatcanicook/providers/app_providers.dart';

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

  Future<void> _save(UserProfile profile, UserProfile updated) async {
    await ref.read(profileProvider.notifier).save(updated);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 38,
                      color: AppColors.orange,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      profile.name.isEmpty ? 'Tu perfil' : profile.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.charcoal,
                          ),
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
              const SizedBox(height: 22),
              const Text(
                'NOMBRE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orangeDark,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: '¿Cómo te llamas?',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                onSubmitted: (value) =>
                    _save(profile, profile.copyWith(name: value.trim())),
              ),
              const SizedBox(height: 20),
              const Text(
                'PREFERENCIAS ALIMENTICIAS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orangeDark,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    _PreferenceSwitch(
                      icon: Icons.eco_outlined,
                      title: 'Vegetariano',
                      value: profile.vegetarian,
                      onChanged: (value) =>
                          _save(profile, profile.copyWith(vegetarian: value)),
                    ),
                    const Divider(height: 1),
                    _PreferenceSwitch(
                      icon: Icons.grain_outlined,
                      title: 'Sin gluten',
                      value: profile.glutenFree,
                      onChanged: (value) =>
                          _save(profile, profile.copyWith(glutenFree: value)),
                    ),
                    const Divider(height: 1),
                    _PreferenceSwitch(
                      icon: Icons.fitness_center_outlined,
                      title: 'Alto en proteínas',
                      value: profile.highProtein,
                      onChanged: (value) =>
                          _save(profile, profile.copyWith(highProtein: value)),
                    ),
                    const Divider(height: 1),
                    _PreferenceSwitch(
                      icon: Icons.local_fire_department_outlined,
                      title: 'Bajo en calorías',
                      value: profile.lowCalorie,
                      onChanged: (value) =>
                          _save(profile, profile.copyWith(lowCalorie: value)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Estas preferencias filtran recetas; no son recomendaciones médicas.',
                style: TextStyle(fontSize: 11, color: AppColors.gray),
              ),
              const SizedBox(height: 22),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.favorite_border,
                        color: AppColors.orange,
                      ),
                      title: const Text('Mis favoritos'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRoutes.favorites),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.history,
                        color: AppColors.orange,
                      ),
                      title: const Text('Historial'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRoutes.history),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.orange),
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}

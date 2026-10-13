import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../theme/app_theme.dart';

/// Barra superior corporativa estandarizada para todos los módulos de SITRA-Luz
class SitraAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const SitraAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  Color _getRoleColor(UserRole? role) {
    if (role == null) return AppColors.primary;
    switch (role) {
      case UserRole.administrador:
        return const Color(0xFFC62828);
      case UserRole.jefaturaFarmacia:
        return AppColors.jefaturaColor;
      case UserRole.farmacia:
        return AppColors.farmaciaColor;
      case UserRole.almacen:
        return AppColors.almacenColor;
      case UserRole.enfermeria:
        return AppColors.enfermeriaColor;
    }
  }

  IconData _getRoleIcon(UserRole? role) {
    if (role == null) return Icons.person;
    switch (role) {
      case UserRole.administrador:
        return Icons.admin_panel_settings_rounded;
      case UserRole.jefaturaFarmacia:
        return Icons.medical_services_rounded;
      case UserRole.farmacia:
        return Icons.local_pharmacy_rounded;
      case UserRole.almacen:
        return Icons.inventory_2_rounded;
      case UserRole.enfermeria:
        return Icons.health_and_safety_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final user = authViewModel.currentUser;
    final roleColor = _getRoleColor(user?.rol);
    final showModuleMenu = user?.rol == UserRole.administrador &&
        GoRouterState.of(context).uri.path != '/admin';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: roleColor.withOpacity(0.3),
            width: 2.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Logo / Avatar con color del rol
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: roleColor.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _getRoleIcon(user?.rol),
                  color: roleColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Título y rol
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user?.rol == UserRole.administrador
                                ? 'ADMIN'
                                : user?.rol.displayName.toUpperCase() ?? 'SISTEMA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: roleColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle ??
                          (user != null
                              ? '${user.nombre} • ${user.areasAsignadas.isNotEmpty ? user.areasAsignadas.first : "Clínica La Luz"}'
                              : 'Clínica La Luz - Tacna'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Acciones extras si se proveen
              if (showModuleMenu)
                IconButton(
                  tooltip: 'Menú de módulos',
                  onPressed: () => context.go('/admin'),
                  icon: const Icon(Icons.grid_view_rounded,
                      color: Color(0xFFC62828), size: 22),
                ),
              if (actions != null) ...actions!,

              // Botón de Cerrar Sesión
              IconButton(
                tooltip: 'Cerrar Sesión',
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                ),
                onPressed: () => _showLogoutDialog(context, authViewModel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthViewModel authVm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('Cerrar Sesión'),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas salir de SITRA-Luz? Deberás ingresar tus credenciales nuevamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              authVm.logout();
            },
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
}

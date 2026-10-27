import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../theme/app_theme.dart';
import 'mensajes_app.dart';

/// Barra superior corporativa estandarizada para todos los módulos de SITRA-Luz
class SitraAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final double alto;
  final String? subtitle;
  final List<Widget>? actions;

  const SitraAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.alto = 72,
  });

  @override
  Size get preferredSize => Size.fromHeight(alto);

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
    final auth = context.watch<AuthViewModel>();
    final user = auth.currentUser;
    final roleColor = _getRoleColor(user?.rol);
    final showMenu =
        user?.rol == UserRole.administrador &&
        GoRouterState.of(context).uri.path != '/admin';
    final detalle =
        subtitle ??
        (user != null
            ? '${user.nombre} · ${user.areasAsignadas.isEmpty ? 'Clínica La Luz' : user.areasAsignadas.first}'
            : 'Clínica La Luz - Tacna');
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: alto,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: Border(
        bottom: BorderSide(color: roleColor.withValues(alpha: .3), width: 2.5),
      ),
      leadingWidth: 60,
      titleSpacing: 4,
      leading: Center(
        child: Tooltip(
          message: user?.rol.displayName ?? 'Sesión',
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: roleColor.withValues(alpha: .4)),
            ),
            child: Icon(_getRoleIcon(user?.rol), color: roleColor, size: 24),
          ),
        ),
      ),
      title: Tooltip(
        message: '$title\n$detalle',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detalle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (showMenu)
          IconButton(
            tooltip: 'Menú de módulos',
            onPressed: () => context.go('/admin'),
            icon: const Icon(
              Icons.grid_view_rounded,
              color: Color(0xFFC62828),
              size: 22,
            ),
          ),
        ...?actions,
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(
            Icons.logout_rounded,
            color: AppColors.error,
            size: 22,
          ),
          onPressed: () => _showLogoutDialog(context, auth),
        ),
      ],
    );
  }

  /// Conserva la confirmación de cierre con un diálogo que admite texto ampliado.
  Future<void> _showLogoutDialog(
    BuildContext context,
    AuthViewModel authVm,
  ) async {
    final confirmar = await MensajesApp.confirmar(
      context,
      titulo: 'Cerrar sesión',
      mensaje:
          '¿Deseas salir de SITRA-Luz? Deberás ingresar tus credenciales nuevamente.',
      accion: 'Cerrar sesión',
    );
    if (confirmar && context.mounted) await authVm.logout();
  }
}

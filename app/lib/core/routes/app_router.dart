import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/states/auth_state.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/dashboard_admin/presentation/views/admin_dashboard_view.dart';
import '../../features/administracion/presentation/views/catalogos_admin_view.dart';
import '../../features/administracion/presentation/views/usuarios_admin_view.dart';
import '../../features/kits/presentation/views/kits_admin_view.dart';
import '../../features/dashboard_almacen/presentation/views/almacen_dashboard_view.dart';
import '../../features/dashboard_enfermeria/presentation/views/enfermeria_dashboard_view.dart';
import '../../features/dashboard_farmacia/presentation/views/farmacia_dashboard_view.dart';
import '../../features/dashboard_jefatura/presentation/views/jefatura_dashboard_view.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String admin = '/admin';
  static const String catalogos = '/admin/catalogos';
  static const String usuarios = '/admin/usuarios';
  static const String kits = '/admin/kits';
  static const String jefatura = '/jefatura';
  static const String farmacia = '/farmacia';
  static const String almacen = '/almacen';
  static const String enfermeria = '/enfermeria';

  static UserRole? roleForPath(String path) {
    for (final entry in const {
      admin: UserRole.administrador,
      jefatura: UserRole.jefaturaFarmacia,
      farmacia: UserRole.farmacia,
      almacen: UserRole.almacen,
      enfermeria: UserRole.enfermeria,
    }.entries) {
      if (path == entry.key || path.startsWith('${entry.key}/')) return entry.value;
    }
    return null;
  }

  /// Determina la ruta correspondiente según el rol del usuario
  static String routeForRole(UserRole role) {
    switch (role) {
      case UserRole.administrador:
        return admin;
      case UserRole.jefaturaFarmacia:
        return jefatura;
      case UserRole.farmacia:
        return farmacia;
      case UserRole.almacen:
        return almacen;
      case UserRole.enfermeria:
        return enfermeria;
    }
  }
}

/// Crea y configura el enrutador GoRouter con protección de rutas y redirección por rol
GoRouter createRouter(AuthViewModel authViewModel) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: authViewModel,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminDashboardView(),
      ),
      GoRoute(
        path: AppRoutes.jefatura,
        builder: (context, state) => const JefaturaDashboardView(),
      ),
      GoRoute(
        path: AppRoutes.catalogos,
        builder: (context, state) => const CatalogosAdminView(),
      ),
      GoRoute(
        path: AppRoutes.usuarios,
        builder: (context, state) => const UsuariosAdminView(),
      ),
      GoRoute(
        path: AppRoutes.kits,
        builder: (context, state) => const KitsAdminView(),
      ),
      GoRoute(
        path: AppRoutes.farmacia,
        builder: (context, state) => const FarmaciaDashboardView(),
      ),
      GoRoute(
        path: AppRoutes.almacen,
        builder: (context, state) => const AlmacenDashboardView(),
      ),
      GoRoute(
        path: AppRoutes.enfermeria,
        builder: (context, state) => const EnfermeriaDashboardView(),
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final authState = authViewModel.state;
      final currentUser = authViewModel.currentUser;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;

      // Si no está autenticado, redirigir a login
      final isAuthenticated =
          authState is AuthStateAuthenticated && currentUser != null && currentUser.activo;

      if (!isAuthenticated) {
        return isLoggingIn ? null : AppRoutes.login;
      }

      // Si está autenticado y está intentando acceder a /login, llevarlo a su dashboard por rol
      if (isLoggingIn) {
        return AppRoutes.routeForRole(currentUser.rol);
      }

      final requiredRole = AppRoutes.roleForPath(state.uri.path);
      if (currentUser.rol != UserRole.administrador && requiredRole != currentUser.rol) {
        return AppRoutes.routeForRole(currentUser.rol);
      }

      return null;
    },
  );
}

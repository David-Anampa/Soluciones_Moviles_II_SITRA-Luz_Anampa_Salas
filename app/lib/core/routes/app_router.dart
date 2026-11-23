import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/notification_service.dart';
import '../../features/notificaciones/presentation/notificaciones_view.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/states/auth_state.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/dashboard_admin/presentation/views/admin_dashboard_view.dart';
import '../../features/administracion/presentation/views/catalogos_admin_view.dart';
import '../../features/administracion/presentation/views/usuarios_admin_view.dart';
import '../../features/administracion/presentation/views/claves_ia_admin_view.dart';
import '../../features/kits/presentation/views/kits_admin_view.dart';
import '../../features/dashboard_almacen/presentation/views/almacen_dashboard_view.dart';
import '../../features/dashboard_enfermeria/presentation/views/enfermeria_dashboard_view.dart';
import '../../features/dashboard_farmacia/presentation/views/farmacia_dashboard_view.dart';
import '../../features/dashboard_jefatura/presentation/views/jefatura_dashboard_view.dart';
import '../../features/fichas/presentation/views/ficha_detalle_atencion_view.dart';
import '../../features/fichas/presentation/views/fichas_listado_view.dart';
import '../../features/fichas/presentation/views/registro_ficha_view.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String notificaciones = '/notificaciones';
  static const String admin = '/admin';
  static const String catalogos = '/admin/catalogos';
  static const String usuarios = '/admin/usuarios';
  static const String clavesIa = '/admin/claves-ia';
  static const String kits = '/admin/kits';
  static const String kitsArea = '/kits';
  static const String fichas = '/fichas';
  static const String nuevaFicha = '/fichas/nueva';
  static const String detalleFicha = '/fichas/detalle';
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
      if (path == entry.key || path.startsWith('${entry.key}/')) {
        return entry.value;
      }
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
    refreshListenable: Listenable.merge([
      authViewModel,
      NotificationService.instance,
    ]),
    routes: [
      GoRoute(
        path: AppRoutes.notificaciones,
        builder: (context, state) =>
            NotificacionesView(avisoId: state.uri.queryParameters['aviso']),
      ),
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
        path: AppRoutes.clavesIa,
        builder: (context, state) => const ClavesIaAdminView(),
      ),
      GoRoute(
        path: AppRoutes.kits,
        builder: (context, state) => const KitsAdminView(),
      ),
      GoRoute(
        path: AppRoutes.kitsArea,
        builder: (context, state) => const KitsAdminView(),
      ),
      GoRoute(
        path: AppRoutes.fichas,
        builder: (context, state) => FichasListadoView(
          areaInicial: state.uri.queryParameters['area'],
          estadoInicial: state.uri.queryParameters['estado'],
        ),
      ),
      GoRoute(
        path: AppRoutes.nuevaFicha,
        builder: (context, state) =>
            RegistroFichaView(areaInicial: state.uri.queryParameters['area']),
      ),
      GoRoute(
        path: AppRoutes.detalleFicha,
        builder: (context, state) => FichaDetalleAtencionView(
          fichaId: state.uri.queryParameters['id'] ?? '',
        ),
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
          authState is AuthStateAuthenticated &&
          currentUser != null &&
          currentUser.activo;

      if (!isAuthenticated) {
        return isLoggingIn ? null : AppRoutes.login;
      }

      final pending = NotificationService.instance.takePendingRoute(
        currentUser.uid,
      );
      if (pending != null && pending != state.uri.toString()) return pending;
      if (state.uri.path == AppRoutes.notificaciones) return null;

      // Si está autenticado y está intentando acceder a /login, llevarlo a su dashboard por rol
      if (isLoggingIn) {
        return AppRoutes.routeForRole(currentUser.rol);
      }

      final requiredRole = AppRoutes.roleForPath(state.uri.path);
      // Acceso compartido de consulta y operación; las RPC comprueban área y permiso.
      if (state.uri.path == AppRoutes.kitsArea ||
          state.uri.path == AppRoutes.fichas ||
          state.uri.path == AppRoutes.detalleFicha) {
        return const {
              UserRole.administrador,
              UserRole.jefaturaFarmacia,
              UserRole.farmacia,
              UserRole.enfermeria,
            }.contains(currentUser.rol)
            ? null
            : AppRoutes.routeForRole(currentUser.rol);
      }
      if (state.uri.path == AppRoutes.nuevaFicha) {
        return const {
              UserRole.administrador,
              UserRole.farmacia,
              UserRole.enfermeria,
            }.contains(currentUser.rol)
            ? null
            : AppRoutes.routeForRole(currentUser.rol);
      }
      if (currentUser.rol != UserRole.administrador &&
          requiredRole != currentUser.rol) {
        return AppRoutes.routeForRole(currentUser.rol);
      }

      return null;
    },
  );
}

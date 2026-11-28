import '../../../../core/theme/paleta_administracion.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/menu_modulos.dart';
import '../../../../core/widgets/sitra_app_bar.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});
  static const _red = PaletaAdministracion.principal;
  static const _modules = [
    _Module(
      'Gestionar usuarios',
      Icons.manage_accounts_rounded,
      '/admin/usuarios',
    ),
    _Module(
      'Gestionar áreas y financiamientos',
      Icons.settings_applications_rounded,
      '/admin/catalogos',
    ),
    _Module(
      'Gestionar profesionales',
      Icons.badge_outlined,
      '/admin/profesionales',
    ),
    _Module('Gestionar kits', Icons.medical_services_rounded, '/admin/kits'),
    _Module('Registrar pedido', Icons.assignment_add, '/fichas/nueva'),
    _Module('Gestionar pedidos', Icons.fact_check_rounded, '/fichas'),
    _Module('Gestionar claves IA', Icons.key_rounded, '/admin/claves-ia'),
  ];

  static const _vistasPorRol = [
    _Module('Farmacia', Icons.local_pharmacy_rounded, '/farmacia'),
    _Module('Almacén', Icons.inventory_2_rounded, '/almacen'),
    _Module('Enfermería', Icons.health_and_safety_rounded, '/enfermeria'),
    _Module('Jefatura de Farmacia', Icons.analytics_rounded, '/jefatura'),
  ];

  Widget _seccion(
    BuildContext context,
    String titulo,
    IconData icono,
    List<_Module> modules,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CabeceraMenu(titulo: titulo, icono: icono, color: _red),
      const SizedBox(height: 16),
      CuadriculaPanel(
        children: [
          for (final module in modules)
            BotonModulo(
              color: _red,
              nombre: module.name,
              icono: module.icon,
              onTap: () => context.go(module.route),
            ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SitraAppBar(
        alto: DisenoAdaptable.altoCabecera(context),
        colorModulo: _red,
        title: 'Menú de administración',
        subtitle: 'Acceso a los módulos de SITRA-Luz',
      ),
      body: SafeArea(
        child: ContenidoAdaptable(
          anchoMaximo: 1000,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: PaletaAdministracion.degradado,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Bienvenido, ${user?.nombre ?? "Administrador"}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Elige el módulo en el que deseas trabajar.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _seccion(
                  context,
                  'Administración',
                  Icons.admin_panel_settings_outlined,
                  _modules,
                ),
                const SizedBox(height: 28),
                _seccion(
                  context,
                  'Vistas por rol',
                  Icons.badge_outlined,
                  _vistasPorRol,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Module {
  final String name;
  final IconData icon;
  final String route;
  const _Module(this.name, this.icon, this.route);
}

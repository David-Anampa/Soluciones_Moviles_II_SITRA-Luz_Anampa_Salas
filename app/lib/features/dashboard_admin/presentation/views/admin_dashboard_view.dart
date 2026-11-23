import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/sitra_app_bar.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});
  static const _red = Color(0xFFC62828);
  static const _modules = [
    _Module(
      'Gestión de usuarios',
      Icons.manage_accounts_rounded,
      '/admin/usuarios',
    ),
    _Module(
      'Financiamientos, seguros y áreas',
      Icons.settings_applications_rounded,
      '/admin/catalogos',
    ),
    _Module(
      'Plantillas de kits quirúrgicos',
      Icons.medical_services_rounded,
      '/admin/kits',
    ),
    _Module(
      'Registro de fichas de pedido',
      Icons.assignment_add,
      '/fichas/nueva',
    ),
    _Module(
      'Atención y trazabilidad de fichas',
      Icons.fact_check_rounded,
      '/fichas',
    ),
    _Module('Farmacia', Icons.local_pharmacy_rounded, '/farmacia'),
    _Module('Almacén', Icons.inventory_2_rounded, '/almacen'),
    _Module('Enfermería', Icons.health_and_safety_rounded, '/enfermeria'),
    _Module('Jefatura de Farmacia', Icons.analytics_rounded, '/jefatura'),
    _Module(
      'Claves de inteligencia artificial',
      Icons.key_rounded,
      '/admin/claves-ia',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SitraAppBar(
        alto: DisenoAdaptable.altoCabecera(context),
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
                      colors: [_red, Color(0xFFE05252)],
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
                const Text(
                  'Módulos del sistema',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, limits) {
                    final gap = limits.maxWidth < 360 ? 10.0 : 16.0;
                    return Column(
                      children: [
                        for (var i = 0; i < _modules.length; i += 2)
                          Padding(
                            padding: EdgeInsets.only(bottom: gap),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _ModuleCard(module: _modules[i]),
                                  ),
                                  SizedBox(width: gap),
                                  Expanded(
                                    child: i + 1 < _modules.length
                                        ? _ModuleCard(module: _modules[i + 1])
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
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

class _ModuleCard extends StatelessWidget {
  final _Module module;
  const _ModuleCard({required this.module});
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(module.route),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 154),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    module.icon,
                    size: 32,
                    color: AdminDashboardView._red,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  module.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.45,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

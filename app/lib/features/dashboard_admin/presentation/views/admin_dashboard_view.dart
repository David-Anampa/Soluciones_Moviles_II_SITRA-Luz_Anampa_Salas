import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sitra_app_bar.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});

  static const _red = Color(0xFFC62828);
  static const _modules = [
    _Module('Farmacia', 'Inventario, abastecimiento y recepción de medicamentos.',
        Icons.local_pharmacy_rounded, '/farmacia'),
    _Module('Almacén', 'Registro de medicamentos, entradas y atención de pedidos.',
        Icons.inventory_2_rounded, '/almacen'),
    _Module('Enfermería', 'Fichas y actividades de las áreas clínicas.',
        Icons.health_and_safety_rounded, '/enfermeria'),
    _Module('Jefatura de Farmacia', 'Consulta y supervisión de la operación.',
        Icons.analytics_rounded, '/jefatura'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SitraAppBar(
        title: 'Menú de administración',
        subtitle: 'Acceso a los módulos de SITRA-Luz',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_red, Color(0xFFE05252)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.admin_panel_settings_rounded,
                          color: Colors.white, size: 32),
                      const SizedBox(height: 12),
                      Text('Bienvenido, ${user?.nombre ?? "Administrador"}',
                          style: const TextStyle(fontSize: 20,
                              fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 8),
                      const Text(
                        'Elige el módulo en el que deseas trabajar. Mantendrás tu sesión de Administrador.',
                        style: TextStyle(fontSize: 13, height: 1.5,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Módulos del sistema',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                const Text('Selecciona una tarjeta para ingresar.',
                    style: TextStyle(fontSize: 13,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 600 ? 2 : 1;
                  final width = (constraints.maxWidth - (columns - 1) * 16) /
                      columns;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: _modules.map((module) => SizedBox(
                      width: width,
                      child: _ModuleCard(module: module),
                    )).toList(),
                  );
                }),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFDDDD)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.grid_view_rounded, size: 20, color: _red),
                      SizedBox(width: 12),
                      Expanded(child: Text(
                        'Para cambiar de módulo, utiliza el botón Menú de módulos de la barra superior.',
                        style: TextStyle(fontSize: 13, height: 1.5,
                            color: AppColors.textSecondary),
                      )),
                    ],
                  ),
                ),
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
  final String description;
  final IconData icon;
  final String route;
  const _Module(this.name, this.description, this.icon, this.route);
}

class _ModuleCard extends StatelessWidget {
  final _Module module;
  const _ModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFC62828);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(module.route),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: Icon(module.icon, size: 42, color: red),
                )),
              ),
              const SizedBox(height: 16),
              Text(module.name, style: const TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(module.description, style: const TextStyle(fontSize: 13,
                  height: 1.5, color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              const Row(children: [
                Text('Abrir módulo', style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w700, color: red)),
                Spacer(),
                Icon(Icons.arrow_forward_rounded, size: 20, color: red),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

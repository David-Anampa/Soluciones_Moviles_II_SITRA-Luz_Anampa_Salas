import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/menu_modulos.dart';
import '../../../../core/widgets/sitra_app_bar.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../almacen/presentation/views/diferencias_abastecimiento_view.dart';
import '../../../almacen/presentation/views/ingresos_correcciones_view.dart';
import '../../../almacen/presentation/views/stock_ubicaciones_view.dart';

class JefaturaDashboardView extends StatelessWidget {
  const JefaturaDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SitraAppBar(
        alto: DisenoAdaptable.altoCabecera(context),
        title: 'Jefatura de Farmacia',
        colorModulo: AppColors.jefaturaColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContenidoAdaptable(
            anchoMaximo: 1100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.jefaturaColor, Color(0xFF0F264A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'JEFATURA DE FARMACIA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Bienvenido, ${user?.nombre ?? "Jefatura"}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const CabeceraMenu(
                  titulo: 'Consultas de supervisión',
                  icono: Icons.manage_search_rounded,
                  color: AppColors.jefaturaColor,
                ),
                const SizedBox(height: 12),
                CuadriculaPanel(
                  children: [
                    BotonModulo(
                      color: AppColors.jefaturaColor,
                      nombre: 'Supervisar pedidos',
                      icono: Icons.fact_check_outlined,
                      onTap: () =>
                          context.push('/fichas?vista=JEFATURA_FARMACIA'),
                    ),
                    BotonModulo(
                      color: AppColors.jefaturaColor,
                      nombre: 'Consultar existencias',
                      icono: Icons.inventory_2_outlined,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StockUbicacionesView(),
                        ),
                      ),
                    ),
                    BotonModulo(
                      color: AppColors.jefaturaColor,
                      nombre: 'Consultar kits por área',
                      icono: Icons.medical_services_outlined,
                      onTap: () =>
                          context.push('/kits?vista=JEFATURA_FARMACIA'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const CabeceraMenu(
                  titulo: 'Historial y auditoría',
                  icono: Icons.policy_outlined,
                  color: AppColors.jefaturaColor,
                ),
                const SizedBox(height: 12),
                CuadriculaPanel(
                  children: [
                    BotonModulo(
                      color: AppColors.jefaturaColor,
                      nombre: 'Reportes y diferencias',
                      icono: Icons.rule_folder_outlined,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DiferenciasAbastecimientoView(
                            soloLectura: true,
                          ),
                        ),
                      ),
                    ),
                    BotonModulo(
                      color: AppColors.jefaturaColor,
                      nombre: 'Ingresos y correcciones',
                      icono: Icons.receipt_long_outlined,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const IngresosCorreccionesView(soloLectura: true),
                        ),
                      ),
                    ),
                  ],
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

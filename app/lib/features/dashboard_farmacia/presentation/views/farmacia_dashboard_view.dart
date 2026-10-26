import 'package:flutter/material.dart';
import '../../../almacen/presentation/views/diferencias_abastecimiento_view.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sitra_app_bar.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../almacen/presentation/states/almacen_state.dart';
import '../../../almacen/presentation/viewmodels/almacen_viewmodel.dart';
import '../../../almacen/presentation/views/crear_solicitud_abastecimiento_view.dart';
import '../../../almacen/presentation/views/solicitudes_abastecimiento_view.dart';
import '../../../almacen/presentation/views/stock_ubicaciones_view.dart';

class FarmaciaDashboardView extends StatefulWidget {
  const FarmaciaDashboardView({super.key});

  @override
  State<FarmaciaDashboardView> createState() => _FarmaciaDashboardViewState();
}

class _FarmaciaDashboardViewState extends State<FarmaciaDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlmacenViewModel>().cargarInventario();
    });
  }

  void _abrirCrearSolicitud() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CrearSolicitudAbastecimientoView(),
      ),
    );
  }

  void _abrirMisSolicitudes() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const SolicitudesAbastecimientoView(esModoFarmacia: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    final almacenVM = context.watch<AlmacenViewModel>();
    final state = almacenVM.state;

    // Calcular solicitudes activas y listas para recepción
    int transferenciasActivas = 0;
    int listasParaRecepcion = 0;

    if (state is AlmacenLoaded) {
      transferenciasActivas = state.solicitudes
          .where((s) => !s.esCompletado && !s.esRechazado && !s.esCancelado)
          .length;
      listasParaRecepcion = state.solicitudes
          .where((s) => s.esListo && !s.confirmadoFarmacia)
          .length;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SitraAppBar(
        title: 'Farmacia Clínica',
        subtitle: 'Dispensación y Reposición Inter-Áreas',
        actions: [
          IconButton(
            tooltip: 'Mis Solicitudes a Almacén',
            icon: Badge(
              isLabelVisible: listasParaRecepcion > 0,
              label: Text(
                '$listasParaRecepcion',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              backgroundColor: AppColors.primary,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  size: 18,
                  color: AppColors.farmaciaColor,
                ),
              ),
            ),
            onPressed: _abrirMisSolicitudes,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text(
          'Solicitar a Almacén',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: _abrirCrearSolicitud,
      ),
      body: RefreshIndicator(
        color: AppColors.farmaciaColor,
        onRefresh: () => almacenVM.cargarInventario(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Banner de Farmacia
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.farmaciaColor, Color(0xFF004D40)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.farmaciaColor.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.local_pharmacy_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'VENTANILLA & DISPENSACIÓN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '7 Pendientes',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Bienvenido, ${user?.nombre ?? "Químico Farmacéutico"}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gestión de pedidos de medicamentos e insumos y abastecimiento entre áreas.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Banner interactivo si hay medicamentos listos para recepción física
              if (listasParaRecepcion > 0) ...[
                const SizedBox(height: 14),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _abrirMisSolicitudes,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.blue.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.local_shipping_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$listasParaRecepcion pedido(s) listos desde Almacén',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Toca aquí para verificar y confirmar la recepción física.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Métricas de atención
              const Text(
                'Abastecimiento de Farmacia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Solicitudes activas',
                      value: '$transferenciasActivas',
                      subtitle: 'Pedidos a Almacén',
                      icon: Icons.move_to_inbox_rounded,
                      color: AppColors.farmaciaColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Listos para recibir',
                      value: '$listasParaRecepcion',
                      subtitle: 'Confirmar recepción física',
                      icon: Icons.local_shipping_outlined,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Acciones directas
              const Text(
                'Operaciones Farmacéuticas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // HU-029: Solicitar abastecimiento a Almacén.
              _buildModuleTile(
                icon: Icons.add_shopping_cart_rounded,
                title: 'Solicitar Abastecimiento a Almacén',
                subtitle:
                    'Crear solicitud de reposición por faltantes de guardia o stock crítico.',
                color: AppColors.primary,
                onTap: _abrirCrearSolicitud,
              ),
              const SizedBox(height: 10),

              // MIS SOLICITUDES Y RECEPCIÓN FÍSICA
              _buildModuleTile(
                icon: Icons.fact_check_outlined,
                title: 'Mis reportes e historial',
                subtitle: 'Sigue diferencias, revisa propuestas y consulta sus justificaciones.',
                color: AppColors.primary,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const DiferenciasAbastecimientoView(esFarmacia: true))),
              ),
              const SizedBox(height: 10),
              _buildModuleTile(
                icon: Icons.download_done_rounded,
                title: 'Mis Solicitudes y Recepción de Mercadería',
                subtitle:
                    'Monitorear estado de pedidos y confirmar recepción de lotes despachados.',
                color: AppColors.secondary,
                onTap: _abrirMisSolicitudes,
              ),
              const SizedBox(height: 10),

              _buildModuleTile(
                icon: Icons.inventory_rounded,
                title: 'Atender Pedidos de Reposición (Pisos)',
                subtitle:
                    'Preparar coches de paro y botiquines para enfermería.',
                color: AppColors.warning,
                onTap: () =>
                    _showActionSnackbar(context, 'Atención a Botiquines'),
              ),
              const SizedBox(height: 10),

              _buildModuleTile(
                icon: Icons.search_rounded,
                title: 'Stock de Farmacia y Almacén',
                subtitle:
                    'Consulta disponibilidad por ubicación y lo que aún está en tránsito.',
                color: AppColors.primary,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const StockUbicacionesView(puedeSolicitar: true),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceVariant, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.surfaceVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionSnackbar(BuildContext context, String module) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Accediendo a $module'),
        backgroundColor: AppColors.farmaciaColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

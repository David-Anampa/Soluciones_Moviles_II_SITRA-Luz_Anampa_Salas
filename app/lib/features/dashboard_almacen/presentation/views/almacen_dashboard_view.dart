import 'package:flutter/material.dart';
import '../../../../core/widgets/avisos_pendientes.dart';
import 'gestion_inventario_almacen_view.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/menu_modulos.dart';
import '../../../almacen/presentation/views/diferencias_abastecimiento_view.dart';
import '../../../almacen/presentation/views/ingresos_correcciones_view.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sitra_app_bar.dart';
import '../../../almacen/presentation/states/almacen_state.dart';
import '../../../almacen/presentation/viewmodels/almacen_viewmodel.dart';
import '../../../almacen/presentation/views/ingreso_lote_view.dart';
import '../../../almacen/presentation/views/escaner_gtin_view.dart';
import '../../../almacen/presentation/views/registro_medicamento_view.dart';
import '../../../almacen/presentation/views/solicitudes_abastecimiento_view.dart';
import '../../../almacen/presentation/views/crear_solicitud_abastecimiento_view.dart';
import '../../../almacen/presentation/views/stock_ubicaciones_view.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';

class AlmacenDashboardView extends StatefulWidget {
  const AlmacenDashboardView({super.key});

  @override
  State<AlmacenDashboardView> createState() => _AlmacenDashboardViewState();
}

class _AlmacenDashboardViewState extends State<AlmacenDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlmacenViewModel>().cargarInventario();
    });
  }

  Future<void> _abrirSolicitudesAbastecimiento() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SolicitudesAbastecimientoView()),
    );
  }

  void _abrirEscanerCamara() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EscanerGtinView()));
  }

  void _abrirRegistroMedicamento() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegistroMedicamentoView()));
  }

  void _abrirIngresoLote(AlmacenLoaded loaded) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IngresoLoteView(catalogo: loaded.catalogo),
      ),
    );
  }

  Future<void> _abrirEnvioFarmacia() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const CrearSolicitudAbastecimientoView(iniciadoPorAlmacen: true),
      ),
    );
    if (mounted) await context.read<AlmacenViewModel>().cargarInventario();
  }

  void _abrirStockUbicaciones() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const StockUbicacionesView(puedeEnviar: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    final almacenVM = context.watch<AlmacenViewModel>();
    final state = almacenVM.state;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SitraAppBar(
        colorModulo: AppColors.almacenColor,
        alto: DisenoAdaptable.altoCabecera(context),
        title: 'Almacén General',
        subtitle: 'Recepción, Lotes y Cadena de Frío',
      ),
      body: ContenidoAdaptable(
        anchoMaximo: 1100,
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.almacenColor,
            onRefresh: () => almacenVM.cargarInventario(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. BANNER DE BIENVENIDA Y ESTADO
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.almacenColor, Color(0xFFBF360C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.almacenColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Wrap(
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Icon(
                                    Icons.inventory_2_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  Text(
                                    'ALMACÉN DE LA CLÍNICA',
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
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Bienvenido, ${user?.nombre ?? "Responsable de Almacén"}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Recepción de guías, ingreso de lotes al sistema y despacho hacia Farmacia Central.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  AvisosPendientes(
                    ambito: 'ALMACEN',
                    color: AppColors.almacenColor,
                    revision: state,
                    onAbrir: (_) => _abrirSolicitudesAbastecimiento(),
                  ),

                  const SizedBox(height: 20),

                  // 2. MÉTRICAS OPERATIVAS REALES DE ALMACÉN
                  const CabeceraMenu(
                    color: AppColors.almacenColor,
                    titulo: 'Estado del Almacén General',
                    icono: Icons.warehouse_outlined,
                  ),
                  const SizedBox(height: 12),

                  if (state is AlmacenLoaded) ...[
                    CuadriculaPanel(
                      esResumen: true,
                      children: [
                        _buildMetricCard(
                          title: 'Total Unidades',
                          value: '${state.totalUnidades}',
                          subtitle: 'Físico en Almacén',
                          icon: Icons.inventory_rounded,
                          color: AppColors.almacenColor,
                        ),
                        _buildMetricCard(
                          title: 'Lotes Registrados',
                          value: '${state.inventario.length}',
                          subtitle: 'Lotes únicos',
                          icon: Icons.numbers_rounded,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CuadriculaPanel(
                      esResumen: true,
                      children: [
                        _buildMetricCard(
                          title: 'Alertas FEFO',
                          value: '${state.lotesCriticos}',
                          subtitle: 'Vence < 30 días',
                          icon: Icons.warning_amber_rounded,
                          color: state.lotesCriticos > 0
                              ? AppColors.error
                              : AppColors.success,
                        ),
                        _buildMetricCard(
                          title: 'Cadena de Frío',
                          value: '${state.articulosCadenaFrio}',
                          subtitle: '2.0 °C a 8.0 °C',
                          icon: Icons.ac_unit_rounded,
                          color: Colors.teal,
                        ),
                      ],
                    ),
                  ] else if (state is AlmacenLoading) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: AppColors.almacenColor,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text('Sin datos disponibles'),
                  ],

                  const SizedBox(height: 24),

                  // 3. ACCIONES RÁPIDAS
                  const CabeceraMenu(
                    color: AppColors.almacenColor,
                    titulo: 'Operaciones de Almacén',
                    icono: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(height: 12),

                  CuadriculaPanel(
                    children: [
                      BotonModulo(
                        color: AppColors.almacenColor,
                        nombre: 'Registrar medicamento',
                        icono: Icons.medication_outlined,
                        onTap: _abrirRegistroMedicamento,
                      ),
                      BotonModulo(
                        color: AppColors.almacenColor,
                        nombre: 'Escanear medicamento',
                        icono: Icons.qr_code_scanner_rounded,
                        onTap: _abrirEscanerCamara,
                      ),
                      BotonModulo(
                        color: AppColors.almacenColor,
                        nombre: 'Ingresar lote',
                        icono: Icons.playlist_add_rounded,
                        onTap: state is AlmacenLoaded
                            ? () => _abrirIngresoLote(state)
                            : null,
                      ),
                      BotonModulo(
                        color: AppColors.almacenColor,
                        nombre: 'Atender solicitudes de Farmacia',
                        icono: Icons.inventory_2_outlined,
                        onTap: _abrirSolicitudesAbastecimiento,
                      ),
                      BotonModulo(
                        color: AppColors.almacenColor,
                        nombre: 'Enviar a Farmacia',
                        icono: Icons.local_shipping_outlined,
                        onTap: _abrirEnvioFarmacia,
                      ),
                      BotonModulo(
                        color: AppColors.almacenColor,
                        nombre: 'Consultar existencias',
                        icono: Icons.warehouse_outlined,
                        onTap: _abrirStockUbicaciones,
                      ),
                      BotonModulo(
                        color: AppColors.almacenColor,
                        nombre: 'Ingresos y correcciones',
                        icono: Icons.receipt_long_outlined,
                        onTap: () async {
                          final vm = context.read<AlmacenViewModel>();
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const IngresosCorreccionesView(),
                            ),
                          );
                          if (mounted) await vm.cargarInventario();
                        },
                      ),
                      BotonModulo(
                        color: AppColors.almacenColor,
                        nombre: 'Resolver diferencias',
                        icono: Icons.fact_check_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const DiferenciasAbastecimientoView(),
                          ),
                        ),
                      ),
                      BotonModulo(
                        color: AppColors.almacenColor,
                        nombre: 'Gestionar inventario',
                        icono: Icons.inventory_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const GestionInventarioAlmacenView(),
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
}

import 'package:flutter/material.dart';
import 'gestion_inventario_almacen_view.dart';
import '../widgets/acciones_rapidas_almacen.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
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

  void _abrirSolicitudesAbastecimiento() {
    Navigator.of(context).push(
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

  void _mostrarOpcionesRegistro() {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return HojaAdaptable(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recepción e Ingreso de Medicamento',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Elige el método de captura para registrar el medicamento:',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.almacenColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.almacenColor,
                    ),
                  ),
                  title: const Text(
                    'Escanear con Cámara (ML Kit + IA)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Lectura instantánea de GTIN + foto opcional de caja para extracción asistida',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _abrirEscanerCamara();
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  title: const Text(
                    'Ingreso Manual',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Completar formulario técnico de medicamento y lote paso a paso',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _abrirRegistroMedicamento();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _abrirIngresoLote(AlmacenLoaded loaded) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IngresoLoteView(catalogo: loaded.catalogo),
      ),
    );
  }

  /// El traslado se atiende desde su solicitud y conserva el ciclo de recepción.
  void _abrirAbastecimiento() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const SolicitudesAbastecimientoView(esModoFarmacia: false),
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
        alto: DisenoAdaptable.altoCabecera(context),
        title: 'Almacén General',
        subtitle: 'Recepción, Lotes y Cadena de Frío',
        actions: [
          IconButton(
            tooltip: 'Solicitudes de Farmacia',
            icon: Badge(
              isLabelVisible:
                  state is AlmacenLoaded && state.solicitudesPendientes > 0,
              label: Text(
                '${state is AlmacenLoaded ? state.solicitudesPendientes : 0}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              backgroundColor: AppColors.error,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  size: 18,
                  color: AppColors.almacenColor,
                ),
              ),
            ),
            onPressed: _abrirSolicitudesAbastecimiento,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.almacenColor,
        foregroundColor: Colors.white,
        onPressed: _mostrarOpcionesRegistro,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text(
          'Ingresar Medicamento',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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

                  // HU-030: Solicitudes pendientes de Farmacia.
                  if (state is AlmacenLoaded &&
                      state.solicitudesPendientes > 0) ...[
                    const SizedBox(height: 14),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _abrirSolicitudesAbastecimiento,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.farmaciaColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.farmaciaColor.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.farmaciaColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.notifications_active_rounded,
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
                                      '${state.solicitudesPendientes} ${state.solicitudesPendientes == 1 ? "solicitud pendiente" : "solicitudes pendientes"} de reposición',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.farmaciaColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Farmacia Central requiere abastecimiento de stock. Toca para revisar y despachar.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppColors.farmaciaColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 2. MÉTRICAS OPERATIVAS REALES DE ALMACÉN
                  const Text(
                    'Estado del Almacén General',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (state is AlmacenLoaded) ...[
                    AccionesAdaptables(
                      anchoMinimo: 150,
                      acciones: [
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
                    AccionesAdaptables(
                      anchoMinimo: 150,
                      acciones: [
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
                  const Text(
                    'Acciones Rápidas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  AccionesRapidasAlmacen(
                    acciones: [
                      AccionRapidaAlmacen(
                        titulo: 'Nuevo medicamento',
                        descripcion: 'Registrar un producto y su primer lote.',
                        icono: Icons.medication_outlined,
                        onTap: _abrirRegistroMedicamento,
                      ),
                      AccionRapidaAlmacen(
                        titulo: 'Ingresar lote',
                        descripcion:
                            'Añadir existencias de un producto registrado.',
                        icono: Icons.playlist_add_rounded,
                        onTap: state is AlmacenLoaded
                            ? () => _abrirIngresoLote(state)
                            : null,
                      ),
                      AccionRapidaAlmacen(
                        titulo: 'Despachar pedidos',
                        descripcion: 'Atender las solicitudes de Farmacia.',
                        icono: Icons.inventory_2_outlined,
                        onTap: state is AlmacenLoaded
                            ? _abrirAbastecimiento
                            : null,
                      ),
                      AccionRapidaAlmacen(
                        titulo: 'Enviar a Farmacia',
                        descripcion: 'Iniciar un envío desde Almacén.',
                        icono: Icons.local_shipping_outlined,
                        onTap: _abrirEnvioFarmacia,
                      ),
                      AccionRapidaAlmacen(
                        titulo: 'Stock por ubicación',
                        descripcion: 'Consultar Almacén y Farmacia.',
                        icono: Icons.warehouse_outlined,
                        onTap: _abrirStockUbicaciones,
                      ),
                      AccionRapidaAlmacen(
                        titulo: 'Ingresos y correcciones',
                        descripcion:
                            'Revisar entradas y registrar correcciones.',
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
                      AccionRapidaAlmacen(
                        titulo: 'Diferencias e historial',
                        descripcion: 'Revisar discrepancias de abastecimiento.',
                        icono: Icons.fact_check_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const DiferenciasAbastecimientoView(),
                          ),
                        ),
                      ),
                      AccionRapidaAlmacen(
                        titulo: 'Gestión de inventario',
                        descripcion:
                            'Consultar lotes, buscar, filtrar y editar productos.',
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
                  const SizedBox(
                    height: 60,
                  ), // Espacio para el botón de registro
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

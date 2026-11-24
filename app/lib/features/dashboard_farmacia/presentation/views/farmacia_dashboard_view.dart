import 'package:flutter/material.dart';
import '../../../../core/widgets/avisos_pendientes.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/menu_modulos.dart';
import 'package:go_router/go_router.dart';
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
import '../../../fichas/data/repositories/fichas_repository.dart';
import '../../../fichas/presentation/views/fichas_listado_view.dart';

class FarmaciaDashboardView extends StatefulWidget {
  const FarmaciaDashboardView({super.key});

  @override
  State<FarmaciaDashboardView> createState() => _FarmaciaDashboardViewState();
}

class _FarmaciaDashboardViewState extends State<FarmaciaDashboardView> {
  final FichasRepository _fichasRepo = FichasRepository();
  int _revisionAvisos = 0;
  int _fichasPendientes = 0;
  int _fichasUrgentes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlmacenViewModel>().cargarInventario();
      _cargarResumenFichas();
    });
  }

  Future<void> _cargarResumenFichas() async {
    try {
      final fichas = await _fichasRepo.listarFichasConFiltros(limite: 120);
      if (!mounted) return;
      final activas = fichas.where(
        (f) =>
            f.estado == 'SOLICITADO' ||
            f.estado == 'EN_PREPARACION' ||
            f.estado == 'LISTO_PARA_RECOJO',
      );
      setState(() {
        _revisionAvisos++;
        _fichasPendientes = activas.length;
        _fichasUrgentes = activas.where((f) => f.esUrgente).length;
      });
    } catch (_) {}
  }

  Future<void> _abrirAtencionFichas({
    String? estadoInicial,
    String? areaInicial,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FichasListadoView(
          estadoInicial: estadoInicial,
          areaInicial: areaInicial,
        ),
      ),
    );
    if (!mounted) return;
    context.read<AlmacenViewModel>().cargarInventario();
    _cargarResumenFichas();
  }

  void _abrirCrearSolicitud() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CrearSolicitudAbastecimientoView(),
      ),
    );
  }

  Future<void> _abrirMisSolicitudes() async {
    await Navigator.of(context).push(
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
        alto: DisenoAdaptable.altoCabecera(context),
        title: 'Farmacia Clínica',
        subtitle: 'Dispensación y Reposición Inter-Áreas',
      ),
      body: ContenidoAdaptable(
        anchoMaximo: 1100,
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.farmaciaColor,
            onRefresh: () async {
              await Future.wait([
                almacenVM.cargarInventario(),
                _cargarResumenFichas(),
              ]);
            },
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
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
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
                              child: const Wrap(
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Icon(
                                    Icons.local_pharmacy_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
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
                              child: Text(
                                '$_fichasPendientes Pendiente(s)',
                                style: const TextStyle(
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

                  AvisosPendientes(
                    ambito: 'FARMACIA',
                    color: AppColors.farmaciaColor,
                    revision: _revisionAvisos,
                    onAbrir: (grupo) => grupo.tipo == 'RECEPCION_ALMACEN'
                        ? _abrirMisSolicitudes()
                        : _abrirAtencionFichas(
                            estadoInicial: 'SOLICITADO',
                            areaInicial: grupo.areaCodigo,
                          ),
                  ),

                  const SizedBox(height: 20),

                  // Métricas de atención
                  const CabeceraMenu(
                    color: AppColors.farmaciaColor,
                    titulo: 'Abastecimiento de Farmacia',
                    icono: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(height: 12),

                  CuadriculaPanel(
                    esResumen: true,
                    children: [
                      _buildMetricCard(
                        title: 'Fichas de pisos',
                        value: '$_fichasPendientes',
                        subtitle: _fichasUrgentes > 0
                            ? '$_fichasUrgentes urgente(s) por atender'
                            : 'Solicitadas / En preparación',
                        icon: Icons.assignment_ind_rounded,
                        color: const Color(0xFFC62828),
                      ),
                      _buildMetricCard(
                        title: 'Solicitudes activas',
                        value: '$transferenciasActivas',
                        subtitle: 'Pedidos a Almacén',
                        icon: Icons.move_to_inbox_rounded,
                        color: AppColors.farmaciaColor,
                      ),
                      _buildMetricCard(
                        title: 'Listos para recibir',
                        value: '$listasParaRecepcion',
                        subtitle: 'Confirmar recepción física',
                        icon: Icons.local_shipping_outlined,
                        color: AppColors.warning,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Acciones directas
                  const CabeceraMenu(
                    color: AppColors.farmaciaColor,
                    titulo: 'Operaciones de Farmacia',
                    icono: Icons.local_pharmacy_outlined,
                  ),
                  const SizedBox(height: 12),

                  CuadriculaPanel(
                    children: [
                      BotonModulo(
                        color: AppColors.farmaciaColor,
                        nombre: 'Solicitar a Almacén',
                        icono: Icons.add_shopping_cart_rounded,
                        onTap: _abrirCrearSolicitud,
                      ),
                      BotonModulo(
                        color: AppColors.farmaciaColor,
                        nombre: 'Solicitudes y recepción',
                        icono: Icons.download_done_rounded,
                        onTap: _abrirMisSolicitudes,
                      ),
                      BotonModulo(
                        color: AppColors.farmaciaColor,
                        nombre: 'Atender pedidos de áreas',
                        icono: Icons.fact_check_rounded,
                        onTap: () => _abrirAtencionFichas(),
                      ),
                      BotonModulo(
                        color: AppColors.farmaciaColor,
                        nombre: 'Consultar existencias',
                        icono: Icons.warehouse_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StockUbicacionesView(
                              puedeSolicitar: true,
                            ),
                          ),
                        ),
                      ),
                      BotonModulo(
                        color: AppColors.farmaciaColor,
                        nombre: 'Consultar kits por área',
                        icono: Icons.medical_services_outlined,
                        onTap: () => context.push('/kits'),
                      ),
                      BotonModulo(
                        color: AppColors.farmaciaColor,
                        nombre: 'Reportes y diferencias',
                        icono: Icons.rule_folder_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DiferenciasAbastecimientoView(
                              esFarmacia: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
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

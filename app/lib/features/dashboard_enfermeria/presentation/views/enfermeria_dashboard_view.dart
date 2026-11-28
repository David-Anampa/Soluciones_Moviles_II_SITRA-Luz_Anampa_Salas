import 'package:flutter/material.dart';
import '../../../../core/widgets/avisos_pendientes.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/menu_modulos.dart';
import '../../../../core/widgets/sitra_app_bar.dart';
import '../../../almacen/presentation/views/stock_ubicaciones_view.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../fichas/data/repositories/fichas_repository.dart';
import '../../../fichas/presentation/views/fichas_listado_view.dart';
import '../../../fichas/presentation/views/registro_ficha_view.dart';

class EnfermeriaDashboardView extends StatefulWidget {
  const EnfermeriaDashboardView({super.key});

  @override
  State<EnfermeriaDashboardView> createState() =>
      _EnfermeriaDashboardViewState();
}

class _EnfermeriaDashboardViewState extends State<EnfermeriaDashboardView> {
  final FichasRepository _fichasRepo = FichasRepository();

  int _revisionAvisos = 0;
  int _itemsDisponiblesFarmacia = 0;
  int _fichasEnProceso = 0;
  int _fichasListasRecojo = 0;
  int _fichasEntregadas = 0;
  String? _nombreAreaReal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarMetricasReales();
    });
  }

  Future<void> _cargarMetricasReales() async {
    try {
      final resultados = await Future.wait([
        _fichasRepo.obtenerContexto(),
        _fichasRepo.buscarCatalogoConStock(limite: 300),
        _fichasRepo.listarFichasConFiltros(limite: 120),
      ]);
      if (!mounted) return;
      final ctx = resultados[0] as dynamic;
      final stock = resultados[1] as List;
      final fichas = resultados[2] as List;

      setState(() {
        _revisionAvisos++;
        if (ctx.areas.isNotEmpty) {
          _nombreAreaReal = ctx.areas.first.nombre as String;
        }
        _itemsDisponiblesFarmacia = stock
            .where((m) => (m.farmaciaDisponible as int) > 0)
            .length;
        _fichasEnProceso = fichas
            .where(
              (f) => f.estado == 'SOLICITADO' || f.estado == 'EN_PREPARACION',
            )
            .length;
        _fichasListasRecojo = fichas
            .where((f) => f.estado == 'LISTO_PARA_RECOJO')
            .length;
        _fichasEntregadas = fichas.where((f) => f.estado == 'ENTREGADO').length;
      });
    } catch (_) {}
  }

  Future<void> _abrirNuevaFicha() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegistroFichaView()));
    if (mounted) {
      await _cargarMetricasReales();
    }
  }

  Future<void> _abrirListadoFichas({
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
    if (mounted) {
      await _cargarMetricasReales();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    final areaAsignada =
        _nombreAreaReal ??
        ((user?.areasAsignadas.isNotEmpty ?? false)
            ? user!.areasAsignadas.first
            : 'Servicio Clínico');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SitraAppBar(
        colorModulo: AppColors.enfermeriaColor,
        alto: DisenoAdaptable.altoCabecera(context),
        title: 'Enfermería & Pisos',
        subtitle: 'Pedidos y trazabilidad del servicio',
      ),
      body: ContenidoAdaptable(
        anchoMaximo: 1100,
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.enfermeriaColor,
            onRefresh: _cargarMetricasReales,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner de Enfermería
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.enfermeriaColor, Color(0xFF880E4F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.enfermeriaColor.withValues(
                            alpha: 0.3,
                          ),
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
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  const Icon(
                                    Icons.health_and_safety_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  Text(
                                    'SERVICIO: ${areaAsignada.toUpperCase()}',
                                    style: const TextStyle(
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
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$_fichasListasRecojo Lista(s) para recojo',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Lic. ${user?.nombre.replaceAll("Lic. ", "") ?? "Enfermera Asignada"}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Solicitud de medicamentos e insumos a Farmacia y seguimiento de fichas del área.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  AvisosPendientes(
                    ambito: 'ENFERMERIA',
                    color: AppColors.enfermeriaColor,
                    revision: _revisionAvisos,
                    onAbrir: (grupo) => _abrirListadoFichas(
                      estadoInicial: 'LISTO_PARA_RECOJO',
                      areaInicial: grupo.areaCodigo,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Métricas en tiempo real del servicio
                  const CabeceraMenu(
                    color: AppColors.enfermeriaColor,
                    titulo: 'Estado en Tiempo Real del Servicio',
                    icono: Icons.monitor_heart_outlined,
                  ),
                  const SizedBox(height: 12),

                  CuadriculaPanel(
                    esResumen: true,
                    children: [
                      _buildMetricCard(
                        title: 'En Farmacia',
                        value: '$_itemsDisponiblesFarmacia',
                        subtitle: 'Productos con stock vigente',
                        icon: Icons.medical_services_outlined,
                        color: AppColors.enfermeriaColor,
                      ),
                      _buildMetricCard(
                        title: 'En atención',
                        value: '$_fichasEnProceso',
                        subtitle: 'Solicitadas / En preparación',
                        icon: Icons.sync_rounded,
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CuadriculaPanel(
                    esResumen: true,
                    children: [
                      _buildMetricCard(
                        title: 'Listas para recojo',
                        value: '$_fichasListasRecojo',
                        subtitle: 'Confirmar recepción en Farmacia',
                        icon: Icons.fact_check_outlined,
                        color: const Color(0xFF4A148C),
                      ),
                      _buildMetricCard(
                        title: 'Fichas entregadas',
                        value: '$_fichasEntregadas',
                        subtitle: 'Atendidas con lote FEFO',
                        icon: Icons.verified_outlined,
                        color: AppColors.success,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Módulos operativos reales
                  const CabeceraMenu(
                    color: AppColors.enfermeriaColor,
                    titulo: 'Operaciones del área',
                    icono: Icons.medical_services_outlined,
                  ),
                  const SizedBox(height: 12),

                  CuadriculaPanel(
                    children: [
                      BotonModulo(
                        color: AppColors.enfermeriaColor,
                        nombre: 'Registrar pedido',
                        icono: Icons.assignment_add,
                        onTap: _abrirNuevaFicha,
                      ),
                      BotonModulo(
                        color: AppColors.enfermeriaColor,
                        nombre: 'Consultar y recibir pedidos',
                        icono: Icons.fact_check_rounded,
                        onTap: () => _abrirListadoFichas(),
                      ),
                      BotonModulo(
                        color: AppColors.enfermeriaColor,
                        nombre: 'Gestionar kits del área',
                        icono: Icons.medical_services_outlined,
                        onTap: () => context.push('/kits?vista=ENFERMERIA'),
                      ),
                      BotonModulo(
                        color: AppColors.enfermeriaColor,
                        nombre: 'Consultar existencias',
                        icono: Icons.warehouse_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StockUbicacionesView(
                              puedeSolicitar: false,
                            ),
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
            color: Colors.black.withValues(alpha: 0.03),
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
              color: color.withValues(alpha: 0.12),
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

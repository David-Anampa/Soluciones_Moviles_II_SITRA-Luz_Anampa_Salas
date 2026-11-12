import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
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
        if (ctx.areas.isNotEmpty) {
          _nombreAreaReal = ctx.areas.first.nombre as String;
        }
        _itemsDisponiblesFarmacia =
            stock.where((m) => (m.farmaciaDisponible as int) > 0).length;
        _fichasEnProceso = fichas
            .where(
              (f) =>
                  f.estado == 'SOLICITADO' || f.estado == 'EN_PREPARACION',
            )
            .length;
        _fichasListasRecojo =
            fichas.where((f) => f.estado == 'LISTO_PARA_RECOJO').length;
        _fichasEntregadas =
            fichas.where((f) => f.estado == 'ENTREGADO').length;
      });
    } catch (_) {}
  }

  Future<void> _abrirNuevaFicha() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegistroFichaView()),
    );
    if (mounted) {
      await _cargarMetricasReales();
    }
  }

  Future<void> _abrirListadoFichas({String? estadoInicial}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FichasListadoView(estadoInicial: estadoInicial),
      ),
    );
    if (mounted) {
      await _cargarMetricasReales();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    final areaAsignada = _nombreAreaReal ??
        ((user?.areasAsignadas.isNotEmpty ?? false)
            ? user!.areasAsignadas.first
            : 'Servicio Clínico');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SitraAppBar(
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
                  AccionesAdaptables(
                    anchoMinimo: 220,
                    acciones: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.enfermeriaColor,
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.assignment_add),
                        label: const Text(
                          'Registrar ficha de pedido (General / Neonatología)',
                        ),
                        onPressed: _abrirNuevaFicha,
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F4C81),
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.assignment_turned_in_outlined),
                        label: const Text(
                          'Mis fichas, estado y recojo (HU-006)',
                        ),
                        onPressed: () => _abrirListadoFichas(),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC62828),
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.medical_services_outlined),
                        label: const Text('Kits de mi área'),
                        onPressed: () => context.push('/kits'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                          color: AppColors.enfermeriaColor.withValues(alpha: 0.3),
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

                  const SizedBox(height: 20),

                  // Métricas en tiempo real del servicio
                  const Text(
                    'Estado en Tiempo Real del Servicio',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  AccionesAdaptables(
                    anchoMinimo: 150,
                    acciones: [
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
                  AccionesAdaptables(
                    anchoMinimo: 150,
                    acciones: [
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

                  // Botón de acción rápida: Solicitud urgente
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.enfermeriaColor,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(
                      Icons.emergency_rounded,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'NUEVO PEDIDO DE MEDICAMENTOS E INSUMOS A FARMACIA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: _abrirNuevaFicha,
                  ),

                  const SizedBox(height: 24),

                  // Módulos operativos reales
                  const Text(
                    'Operaciones del Servicio Clínico',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildModuleTile(
                    icon: Icons.assignment_add,
                    title: 'Registrar Ficha de Pedido (General / Neonatología)',
                    subtitle:
                        'HU-003 / HU-004 / HU-005: Paciente, área, médico, financiamiento, receptor, stock en tiempo real y aplicación de kits.',
                    color: AppColors.enfermeriaColor,
                    onTap: _abrirNuevaFicha,
                  ),
                  const SizedBox(height: 10),
                  _buildModuleTile(
                    icon: Icons.fact_check_rounded,
                    title:
                        'Seguimiento de Fichas, Confirmación de Recojo y Anulación',
                    subtitle:
                        'HU-006 / HU-007 / HU-010 / HU-011: Consultar estado de preparación en Farmacia, confirmar recepción por lote FEFO o anular con motivo.',
                    color: AppColors.primary,
                    onTap: () => _abrirListadoFichas(),
                  ),
                  const SizedBox(height: 10),
                  _buildModuleTile(
                    icon: Icons.medication_liquid_rounded,
                    title: 'Consultar Stock de Farmacia y Almacén (HU-023)',
                    subtitle:
                        'Verificación en tiempo real de medicamentos, dispositivos médicos y lotes vigentes.',
                    color: AppColors.secondary,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const StockUbicacionesView(puedeSolicitar: false),
                      ),
                    ),
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
                  color: color.withValues(alpha: 0.12),
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
}

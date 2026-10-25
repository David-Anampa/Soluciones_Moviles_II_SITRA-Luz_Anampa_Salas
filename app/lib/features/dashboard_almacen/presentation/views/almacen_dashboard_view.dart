import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sitra_app_bar.dart';
import '../../../almacen/domain/entities/lote_entity.dart';
import '../../../almacen/domain/entities/stock_almacen_entity.dart';
import '../../../almacen/presentation/states/almacen_state.dart';
import '../../../almacen/presentation/viewmodels/almacen_viewmodel.dart';
import '../../../almacen/domain/entities/medicamento_entity.dart';
import '../../../almacen/presentation/views/ingreso_lote_view.dart';
import '../../../almacen/presentation/views/editar_medicamento_view.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _filtroRapido = 'TODOS'; // 'TODOS', 'FRIO', 'FEFO', 'BAJO_STOCK'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlmacenViewModel>().cargarInventario();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirSolicitudesAbastecimiento() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SolicitudesAbastecimientoView()),
    );
  }

  void _abrirEdicionMedicamento(MedicamentoEntity medicamento) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditarMedicamentoView(medicamento: medicamento),
      ),
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
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
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
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
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
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _abrirRegistroMedicamento();
                },
              ),
              const SizedBox(height: 8),
            ],
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

    final List<StockAlmacenEntity> itemsFiltrados = state is AlmacenLoaded
        ? state.inventario.where((item) {
            final query = _searchController.text.trim().toLowerCase();
            if (query.isNotEmpty) {
              final coincideNombre = item.medicamento.nombreComercial
                  .toLowerCase()
                  .contains(query);
              final coincideDci = item.medicamento.principioActivo
                  .toLowerCase()
                  .contains(query);
              final coincideGtin = item.medicamento.gtin.toLowerCase().contains(
                query,
              );
              final coincideLote = item.lote.numeroLote.toLowerCase().contains(
                query,
              );
              if (!coincideNombre &&
                  !coincideDci &&
                  !coincideGtin &&
                  !coincideLote) {
                return false;
              }
            }

            switch (_filtroRapido) {
              case 'FRIO':
                return item.medicamento.requiereCadenaFrio;
              case 'FEFO':
                return item.lote.diasParaVencer <= 30;
              case 'BAJO_STOCK':
                return item.cantidad <= 20;
              case 'TODOS':
              default:
                return true;
            }
          }).toList()
        : [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SitraAppBar(
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
      body: RefreshIndicator(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          child: const Row(
                            children: [
                              Icon(
                                Icons.inventory_2_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
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
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Total Unidades',
                        value: '${state.totalUnidades}',
                        subtitle: 'Físico en Almacén',
                        icon: Icons.inventory_rounded,
                        color: AppColors.almacenColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Lotes Registrados',
                        value: '${state.inventario.length}',
                        subtitle: 'Lotes únicos',
                        icon: Icons.numbers_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Alertas FEFO',
                        value: '${state.lotesCriticos}',
                        subtitle: 'Vence < 30 días',
                        icon: Icons.warning_amber_rounded,
                        color: state.lotesCriticos > 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Cadena de Frío',
                        value: '${state.articulosCadenaFrio}',
                        subtitle: '2.0 °C a 8.0 °C',
                        icon: Icons.ac_unit_rounded,
                        color: Colors.teal,
                      ),
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

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.almacenColor,
                        fixedSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: AppColors.almacenColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onPressed: _abrirRegistroMedicamento,
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'Nuevo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.primary,
                        fixedSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onPressed: state is AlmacenLoaded
                          ? () => _abrirIngresoLote(state)
                          : null,
                      icon: const Icon(Icons.playlist_add_rounded, size: 18),
                      label: const Text(
                        'Ingreso',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.farmaciaColor,
                        fixedSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: AppColors.farmaciaColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onPressed: state is AlmacenLoaded
                          ? _abrirAbastecimiento
                          : null,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text(
                        'Despachar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _abrirEnvioFarmacia,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Enviar a Farmacia'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _abrirStockUbicaciones,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.warehouse_outlined),
                  label: const Text('Stock por ubicación'),
                ),
              ),
              const SizedBox(height: 24),
              // HU-013 / HU-023: Inventario físico con búsqueda y filtros.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Inventario en Almacén General',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (state is AlmacenLoaded)
                    Text(
                      _searchController.text.trim().isEmpty
                          ? 'Mostrando ${itemsFiltrados.length > 5 ? 5 : itemsFiltrados.length} de ${state.inventario.length} lotes'
                          : '${itemsFiltrados.length} resultados encontrados',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (state is AlmacenLoaded) ...[
                if (state.inventario.isNotEmpty) ...[
                  // Barra de Búsqueda Rápida en tiempo real
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, DCI, GTIN o lote...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.almacenColor,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Chips de Filtro Rápido
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFiltroChip(
                          label: 'Todos',
                          count: state.inventario.length,
                          isSelected: _filtroRapido == 'TODOS',
                          onTap: () => setState(() => _filtroRapido = 'TODOS'),
                        ),
                        const SizedBox(width: 8),
                        _buildFiltroChip(
                          label: 'Cadena de Frío',
                          icon: Icons.ac_unit_rounded,
                          iconColor: Colors.cyan,
                          count: state.articulosCadenaFrio,
                          isSelected: _filtroRapido == 'FRIO',
                          onTap: () => setState(() => _filtroRapido = 'FRIO'),
                        ),
                        const SizedBox(width: 8),
                        _buildFiltroChip(
                          label: 'FEFO Crítico',
                          icon: Icons.warning_amber_rounded,
                          iconColor: AppColors.error,
                          count: state.lotesCriticos,
                          isSelected: _filtroRapido == 'FEFO',
                          onTap: () => setState(() => _filtroRapido = 'FEFO'),
                        ),
                        const SizedBox(width: 8),
                        _buildFiltroChip(
                          label: 'Bajo Stock',
                          icon: Icons.inventory_2_outlined,
                          iconColor: AppColors.warning,
                          count: state.inventario
                              .where((i) => i.cantidad <= 20)
                              .length,
                          isSelected: _filtroRapido == 'BAJO_STOCK',
                          onTap: () =>
                              setState(() => _filtroRapido = 'BAJO_STOCK'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                if (state.inventario.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.inbox_rounded,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No hay medicamentos en Almacén',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Registra tu primer artículo con el botón inferior.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.almacenColor,
                          ),
                          onPressed: _abrirRegistroMedicamento,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Registrar Primer Medicamento'),
                        ),
                      ],
                    ),
                  )
                else if (itemsFiltrados.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.surfaceVariant),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 44,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No se encontraron medicamentos',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'No hay coincidencias para los filtros o término de búsqueda ingresado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _filtroRapido = 'TODOS';
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Limpiar filtros'),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchController.text.trim().isEmpty
                        ? (itemsFiltrados.length > 5
                              ? 5
                              : itemsFiltrados.length)
                        : itemsFiltrados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = itemsFiltrados[index];
                      return _buildStockItemCard(item, state);
                    },
                  ),
              ],
              const SizedBox(height: 60), // Margen para el FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockItemCard(StockAlmacenEntity item, AlmacenLoaded loaded) {
    final med = item.medicamento;
    final lote = item.lote;

    Color fefoColor;
    switch (lote.estadoFefo) {
      case EstadoFefo.vencido:
      case EstadoFefo.critico:
        fefoColor = AppColors.error;
        break;
      case EstadoFefo.preventivo:
        fefoColor = AppColors.warning;
        break;
      case EstadoFefo.seguro:
        fefoColor = AppColors.success;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila Superior: Nombre y Cantidad
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.nombreComercial,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (lote.laboratorio != null && lote.laboratorio!.isNotEmpty)
                          ? lote.laboratorio!
                          : (med.laboratorio != null &&
                                med.laboratorio!.isNotEmpty)
                          ? med.laboratorio!
                          : 'Laboratorio no especificado',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.almacenColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '${item.cantidad}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.almacenColor,
                      ),
                    ),
                    const Text(
                      'unid.',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.almacenColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Fila Inferior: Chips informativos
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Chip Lote
              _buildBadge(
                icon: Icons.numbers_rounded,
                text: 'Lote: ${lote.numeroLote}',
                color: Colors.indigo,
              ),

              // Chip Caducidad / FEFO
              _buildBadge(
                icon: Icons.calendar_month_rounded,
                text: 'FEFO: ${lote.etiquetaFefo}',
                color: fefoColor,
              ),

              // Chip Cadena de Frío (si aplica)
              if (med.requiereCadenaFrio)
                _buildBadge(
                  icon: Icons.ac_unit_rounded,
                  text: 'Cadena de Frío (2-8 °C)',
                  color: Colors.cyan.shade800,
                ),

              // Chip GTIN
              _buildBadge(
                icon: Icons.qr_code_rounded,
                text: med.gtin,
                color: AppColors.textSecondary,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // HU-016: Edición del ítem; acceso a transferencia física de stock.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(
                    color: AppColors.textSecondary.withOpacity(0.3),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                onPressed: () => _abrirEdicionMedicamento(med),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text(
                  'Editar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.almacenColor.withOpacity(0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.almacenColor
                : AppColors.surfaceVariant,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? AppColors.almacenColor
                    : (iconColor ?? AppColors.textSecondary),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppColors.almacenColor
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.almacenColor
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
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

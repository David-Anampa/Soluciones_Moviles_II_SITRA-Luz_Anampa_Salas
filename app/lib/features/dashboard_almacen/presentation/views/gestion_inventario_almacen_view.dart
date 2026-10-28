import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../almacen/domain/entities/lote_entity.dart';
import '../../../almacen/domain/entities/stock_almacen_entity.dart';
import '../../../almacen/domain/entities/medicamento_entity.dart';
import '../../../almacen/presentation/states/almacen_state.dart';
import '../../../almacen/presentation/viewmodels/almacen_viewmodel.dart';
import '../../../almacen/presentation/views/editar_medicamento_view.dart';
import '../../../almacen/presentation/views/registro_medicamento_view.dart';

/// Inventario operativo completo: conserva búsqueda, filtros, lotes y edición.
/// Comparte el ViewModel del módulo para reflejar ingresos y cambios de stock.
class GestionInventarioAlmacenView extends StatefulWidget {
  const GestionInventarioAlmacenView({super.key});
  @override
  State<GestionInventarioAlmacenView> createState() =>
      _GestionInventarioAlmacenViewState();
}

class _GestionInventarioAlmacenViewState
    extends State<GestionInventarioAlmacenView> {
  final _searchController = TextEditingController();
  String _filtroRapido = 'TODOS';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<AlmacenViewModel>();
      if (vm.state is AlmacenInitial) vm.cargarInventario();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirEdicionMedicamento(MedicamentoEntity medicamento) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditarMedicamentoView(medicamento: medicamento),
      ),
    );
  }

  void _abrirRegistroMedicamento() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const RegistroMedicamentoView()));

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(
        title: const Text(
          'Gestión de inventario',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFFC62828),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: DisenoAdaptable.altoCabecera(
          context,
          base: kToolbarHeight,
        ),
      ),
      body: SafeArea(
        child: ContenidoAdaptable(
          padding: EdgeInsets.zero,
          child: RefreshIndicator(
            color: const Color(0xFFC62828),
            onRefresh: almacenVM.cargarInventario,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state is AlmacenLoading || state is AlmacenInitial)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (state is AlmacenError) ...[
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: Color(0xFFC62828),
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(state.message),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: almacenVM.cargarInventario,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // HU-013 / HU-023: Inventario físico con búsqueda y filtros.
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
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
                              ? 'Mostrando ${itemsFiltrados.length} de ${state.inventario.length} lotes'
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
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                    ),
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
                        child: Wrap(
                          alignment: WrapAlignment.start,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFiltroChip(
                              label: 'Todos',
                              count: state.inventario.length,
                              isSelected: _filtroRapido == 'TODOS',
                              onTap: () =>
                                  setState(() => _filtroRapido = 'TODOS'),
                            ),
                            _buildFiltroChip(
                              label: 'Cadena de Frío',
                              icon: Icons.ac_unit_rounded,
                              iconColor: Colors.cyan,
                              count: state.articulosCadenaFrio,
                              isSelected: _filtroRapido == 'FRIO',
                              onTap: () =>
                                  setState(() => _filtroRapido = 'FRIO'),
                            ),
                            _buildFiltroChip(
                              label: 'FEFO Crítico',
                              icon: Icons.warning_amber_rounded,
                              iconColor: AppColors.error,
                              count: state.lotesCriticos,
                              isSelected: _filtroRapido == 'FEFO',
                              onTap: () =>
                                  setState(() => _filtroRapido = 'FEFO'),
                            ),
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
                        itemCount: itemsFiltrados.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = itemsFiltrados[index];
                          return _buildStockItemCard(item, state);
                        },
                      ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
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
          FilaDetalleAdaptable(
            principales: [
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
            ],
            detalle: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      child: Wrap(
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Icon(icon, size: 13, color: color),
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
}

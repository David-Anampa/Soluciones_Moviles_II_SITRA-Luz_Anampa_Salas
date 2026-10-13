import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/pedido_abastecimiento_entity.dart';
import '../states/almacen_state.dart';
import '../viewmodels/almacen_viewmodel.dart';
import 'crear_solicitud_abastecimiento_view.dart';

/// RF-029 / RF-030: Pantalla de visualización, despacho y seguimiento de solicitudes de abastecimiento.
/// Utilizable tanto por el personal de Almacén General (RF-030) como por Farmacia Central.
class SolicitudesAbastecimientoView extends StatefulWidget {
  final bool esModoFarmacia;

  const SolicitudesAbastecimientoView({super.key, this.esModoFarmacia = false});

  @override
  State<SolicitudesAbastecimientoView> createState() =>
      _SolicitudesAbastecimientoViewState();
}

class _SolicitudesAbastecimientoViewState
    extends State<SolicitudesAbastecimientoView> {
  static const _rojo = Color(0xFFC62828);
  static const _rojoSuave = Color(0xFFFFEBEE);
  static const _grisFondo = Color(0xFFF4F6FB);
  static const _grisBorde = Color(0xFFE5E7EB);
  static const _blanco = Colors.white;
  static const _texto = Color(0xFF27272A);
  static const _textoSecundario = Color(0xFF6B7280);

  // Estilo local: mantiene las demás pantallas y unifica las vistas de pedidos.
  ThemeData _temaPedidos(BuildContext context) {
    final base = Theme.of(context);
    final botones = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: _rojo, onPrimary: _blanco,
        secondary: _rojo, onSecondary: _blanco,
        surface: _blanco, surfaceTint: Colors.transparent,
        onSurface: _texto, error: _rojo,
      ),
      filledButtonTheme: FilledButtonThemeData(style: botones.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled) ? _grisBorde : _rojo),
        foregroundColor: const WidgetStatePropertyAll(_blanco),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: botones.copyWith(
        foregroundColor: const WidgetStatePropertyAll(_rojo),
        side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFFEF9A9A))),
      )),
      textButtonTheme: TextButtonThemeData(style: botones.copyWith(
        foregroundColor: const WidgetStatePropertyAll(_textoSecundario),
      )),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: _blanco, selectedColor: _rojoSuave,
        checkmarkColor: _rojo,
        side: const BorderSide(color: _grisBorde),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _texto),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true, fillColor: _grisFondo,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(fontSize: 13, color: _textoSecundario),
        hintStyle: const TextStyle(fontSize: 13, color: _textoSecundario),
        errorStyle: const TextStyle(fontSize: 12, color: _rojo),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _grisBorde)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _rojo, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _rojo)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _rojo, width: 1.5)),
      ),
    );
  }

  Future<T?> _mostrarModal<T>(Widget Function(BuildContext) contenido) => showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Theme(data: _temaPedidos(ctx), child: contenido(ctx)),
  );

  String _filtroEstado =
      'PENDIENTES'; // 'PENDIENTES', 'EN CURSO', 'COMPLETADOS', 'ARCHIVADOS'

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AlmacenViewModel>();
    final state = vm.state;

    const themeColor = _rojo;

    return Theme(data: _temaPedidos(context), child: Scaffold(
      backgroundColor: _grisFondo,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.esModoFarmacia
                  ? 'Mis Solicitudes a Almacén'
                  : 'Solicitudes de Farmacia',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.esModoFarmacia
                  ? 'Seguimiento de reposición y recepción física'
                  : 'Preparación, entrega y trazabilidad de pedidos',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: widget.esModoFarmacia
          ? FloatingActionButton.extended(
              backgroundColor: _rojo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text(
                'Nueva Solicitud',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CrearSolicitudAbastecimientoView(),
                  ),
                );
              },
            )
          : null,
      body: state is AlmacenLoaded
          ? _buildBody(context, state, vm.isSaving, themeColor)
          : state is AlmacenError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 40,
                      color: _textoSecundario,
                    ),
                    const SizedBox(height: 12),
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: vm.cargarInventario,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : Center(child: CircularProgressIndicator(color: themeColor)),
    ));
  }

  Widget _buildBody(
    BuildContext context,
    AlmacenLoaded loaded,
    bool isSaving,
    Color themeColor,
  ) {
    final solicitudes = loaded.solicitudes;

    final filtradas = solicitudes.where((s) {
      if (_filtroEstado == 'PENDIENTES') return s.esPendiente;
      if (_filtroEstado == 'EN CURSO') {
        return s.esEnPreparacion || (s.esListo && !s.confirmadoFarmacia);
      }
      if (_filtroEstado == 'COMPLETADOS') return s.esCompletado;
      if (_filtroEstado == 'ARCHIVADOS') return s.esCancelado || s.esRechazado;
      return true;
    }).toList();

    return RefreshIndicator(
      color: themeColor,
      onRefresh: () => context.read<AlmacenViewModel>().cargarInventario(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        children: [
          // 1. Selector de Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'PENDIENTES',
                  'Pendientes',
                  _rojo,
                ),
                const SizedBox(width: 8),
                _buildFilterChip('EN CURSO', 'En curso', _rojo),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'COMPLETADOS',
                  'Completados',
                  _rojo,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'ARCHIVADOS',
                  'Cancelados / Rechazados',
                  _textoSecundario,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Lista de Solicitudes
          if (filtradas.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _blanco,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _grisBorde),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No hay solicitudes en esta categoría',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtradas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = filtradas[index];
                return _buildSolicitudCard(context, item, loaded, isSaving);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String valor, String etiqueta, Color color) {
    final activo = _filtroEstado == valor;
    return ChoiceChip(
      label: Text(etiqueta),
      selected: activo,
      selectedColor: _rojoSuave,
      labelStyle: TextStyle(
        color: activo ? color : _textoSecundario,
        fontWeight: activo ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _filtroEstado = valor),
    );
  }

  Widget _buildSolicitudCard(
    BuildContext context,
    PedidoAbastecimientoEntity item,
    AlmacenLoaded loaded,
    bool isSaving,
  ) {
    final esPendiente = item.esPendiente;
    final esEnPreparacion = item.esEnPreparacion;
    final esListo = item.esListo;
    final esCompletado = item.esCompletado;
    final esCancelado = item.esCancelado;
    final esRechazado = item.esRechazado;

    Color estadoColor = _textoSecundario;
    IconData estadoIcon = Icons.info_outline;

    if (esPendiente) {
      estadoColor = _rojo;
      estadoIcon = Icons.new_releases_rounded;
    } else if (esEnPreparacion) {
      estadoColor = _rojo;
      estadoIcon = Icons.inventory_2_rounded;
    } else if (esListo) {
      estadoColor = _rojo;
      estadoIcon = Icons.local_shipping_rounded;
    } else if (esCompletado) {
      estadoColor = _rojo;
      estadoIcon = Icons.check_circle_rounded;
    } else if (esCancelado) {
      estadoColor = _textoSecundario;
      estadoIcon = Icons.cancel_outlined;
    } else if (esRechazado) {
      estadoColor = _rojo;
      estadoIcon = Icons.highlight_off_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blanco,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esPendiente
              ? _rojo.withValues(alpha: 0.2)
              : _grisBorde,
          width: esPendiente ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: Código, Estado y Turno
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(estadoIcon, color: estadoColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.codigo,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _texto,
                            ),
                          ),
                          Text(
                            'Turno: ${item.turno} • Justif: ${item.justificacion == "STOCK_CERO" ? "Rotura / Cero" : "Reposición"}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 112),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.esCompletado && item.observacionRecepcion != null
                      ? 'COMPLETADO CON OBSERVACIÓN'
                      : item.estado.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: estadoColor,
                  ),
                ),
              ),
            ],
          ),

          if (item.notas != null && item.notas!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _grisFondo,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Nota de Farmacia: ${item.notas}',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: _textoSecundario,
                ),
              ),
            ),
          ],

          if (item.motivoCancelacion != null &&
              item.motivoCancelacion!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _grisFondo,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _grisBorde),
              ),
              child: Text(
                'Cancelado por ${item.canceladoPorNombre ?? "Farmacia"}\n${item.motivoCancelacion}\n${_fechaHora(item.fechaCancelacion)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textoSecundario,
                ),
              ),
            ),
          ],

          if (item.motivoRechazo != null && item.motivoRechazo!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _rojoSuave,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Text(
                'Rechazado por ${item.rechazadoPorNombre ?? "Almacén"}\n${item.motivoRechazo}\n${_fechaHora(item.fechaRechazo)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _rojo,
                ),
              ),
            ),
          ],

          if (item.observacionRecepcion != null) ...[
            const SizedBox(height: 8),
            _aviso(
              Icons.assignment_return_rounded,
              'Recepción con observación',
              item.observacionRecepcion!,
              _rojo,
            ),
          ],
          if (item.modalidadEntrega != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  item.modalidadEntrega == 'ENTREGA'
                      ? Icons.local_shipping_rounded
                      : Icons.directions_walk_rounded,
                  size: 16,
                  color: _rojo,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.modalidadEntrega == 'ENTREGA'
                        ? 'Almacén entrega en Farmacia'
                        : 'Farmacia recoge en Almacén',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _rojo,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Lista de ítems solicitados
          const Text(
            'Medicamentos Solicitados:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _texto,
            ),
          ),
          const SizedBox(height: 6),

          ...item.items.map(
            (it) => Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _grisBorde.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.nombreMedicamento,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Solicitado: ${it.cantidadSolicitada}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (item.esListo || item.esCompletado)
                        Text(
                          'Despachado: ${it.cantidadDespachada}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (it.cantidadRecibida != null)
                        Text(
                          'Aceptado: ${it.cantidadRecibida}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (it.cantidadDevuelta > 0)
                        Text(
                          'Devuelto: ${it.cantidadDevuelta}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _rojo,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Acciones en modo Farmacia
          if (widget.esModoFarmacia) ...[
            if (esPendiente)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _aviso(
                    Icons.hourglass_top_rounded,
                    'En espera de atención',
                    'Si hay un error, cancele este pedido y cree una nueva solicitud.',
                    _rojo,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _rojo,
                      ),
                      onPressed: isSaving
                          ? null
                          : () => _mostrarDialogoCancelar(item),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancelar Solicitud'),
                    ),
                  ),
                ],
              )
            else if (esListo && !item.confirmadoFarmacia)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _rojo,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: isSaving
                      ? null
                      : () => _mostrarDialogoRecepcion(item),
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                  label: const Text('Confirmar recepción física'),
                ),
              )
            else if (esEnPreparacion)
              _aviso(
                Icons.inventory_2_outlined,
                'Almacén está preparando el pedido',
                'Si necesita cancelarlo, comuníquese físicamente con Almacén. Su personal puede rechazar la solicitud.',
                _rojo,
              )
            else if (esCompletado)
              Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: _rojo,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Recepción completada el ${item.fechaCompletado?.day ?? ""}/${item.fechaCompletado?.month ?? ""}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _rojo,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ] else ...[
            // Acciones en modo Almacén (RF-030)
            if (esPendiente || esEnPreparacion) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (esPendiente)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _rojo,
                      ),
                      onPressed: isSaving
                          ? null
                          : () =>
                                _cambiarEstadoPedido(item.id, 'EN_PREPARACION'),
                      icon: const Icon(Icons.back_hand_rounded, size: 18),
                      label: const Text('Tomar pedido'),
                    ),
                  if (esEnPreparacion)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _rojo,
                      ),
                      onPressed: isSaving
                          ? null
                          : () => _mostrarDialogoDespacho(item, loaded),
                      icon: const Icon(Icons.local_shipping_rounded, size: 18),
                      label: const Text('Atender y despachar'),
                    ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _rojo,
                    ),
                    onPressed: isSaving
                        ? null
                        : () => _mostrarDialogoRechazo(item),
                    icon: const Icon(Icons.highlight_off_rounded, size: 18),
                    label: const Text('Rechazar solicitud'),
                  ),
                ],
              ),
            ] else if (esListo && !item.confirmadoFarmacia)
              _aviso(
                Icons.hourglass_top_rounded,
                'Pedido despachado',
                'Esperando la confirmación de recepción física de Farmacia.',
                _rojo,
              )
            else if (esCompletado)
              Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: _rojo,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Completado bilateralmente el ${item.fechaCompletado?.day}/${item.fechaCompletado?.month}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _rojo,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  void _cambiarEstadoPedido(String pedidoId, String nuevoEstado) async {
    final vm = context.read<AlmacenViewModel>();
    if (nuevoEstado == 'EN_PREPARACION') {
      final exito = await vm.tomarPedidoAbastecimiento(pedidoId);
      if (exito && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido tomado en preparación.'),
            backgroundColor: _rojo,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.errorMessage ?? 'No se pudo tomar el pedido.'),
            backgroundColor: _rojo,
          ),
        );
      }
    }
  }

  String _fechaHora(DateTime? fecha) {
    if (fecha == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} • ${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  Widget _aviso(IconData icono, String titulo, String texto, Color color) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    texto,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Future<void> _mostrarDialogoCancelar(PedidoAbastecimientoEntity item) =>
      _mostrarDialogoMotivo(item, cancelar: true);

  Future<void> _mostrarDialogoRechazo(PedidoAbastecimientoEntity item) =>
      _mostrarDialogoMotivo(item, cancelar: false);

  Future<void> _mostrarDialogoMotivo(
    PedidoAbastecimientoEntity item, {
    required bool cancelar,
  }) async {
    final opciones = cancelar
        ? [
            'Error en cantidad digitada',
            'Ítem equivocado',
            'Duplicado de turno',
            'Otro motivo',
          ]
        : [
            'Ruptura total de stock',
            'Medicamento en cuarentena',
            'Cancelación coordinada con Farmacia',
            'Solicitud duplicada o errónea',
            'Otro motivo',
          ];
    String motivo = opciones.first;
    final detalle = TextEditingController();
    bool guardando = false;
    String? error;
    const color = _rojo;
    final vm = context.read<AlmacenViewModel>();
    final resultado = await _mostrarModal<bool>( (ctx) => StatefulBuilder(
        builder: (ctx, actualizar) => PopScope(
          canPop: !guardando,
          child: AlertDialog(
            backgroundColor: _blanco,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            actionsOverflowButtonSpacing: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  cancelar
                      ? Icons.cancel_outlined
                      : Icons.highlight_off_rounded,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cancelar ? 'Cancelar solicitud' : 'Rechazar solicitud',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.codigo,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      cancelar
                          ? 'La solicitud quedará archivada. Para corregir cantidades o medicamentos, cree una nueva solicitud.'
                          : 'Se informará a Farmacia y el pedido quedará archivado con su motivo.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: _textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Seleccione el motivo',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: opciones
                          .map(
                            (opcion) => ChoiceChip(
                              label: Text(opcion),
                              selected: motivo == opcion,
                              onSelected: guardando
                                  ? null
                                  : (_) => actualizar(() {
                                      motivo = opcion;
                                      error = null;
                                    }),
                            ),
                          )
                          .toList(),
                    ),
                    if (motivo == 'Otro motivo') ...[
                      const SizedBox(height: 12),
                      TextField(
                              style: const TextStyle(fontSize: 14, color: _texto),
                        controller: detalle,
                        enabled: !guardando,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Detalle del motivo',
                          border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _grisBorde),
                ),
                        ),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      _aviso(
                        Icons.info_outline,
                        'No se pudo completar la acción',
                        error!,
                        _rojo,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: guardando
                    ? null
                    : () => Navigator.of(ctx).pop(false),
                child: const Text('Volver'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: color),
                icon: guardando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        cancelar
                            ? Icons.cancel_outlined
                            : Icons.highlight_off_rounded,
                        size: 18,
                      ),
                label: Text(
                  cancelar ? 'Cancelar pedido' : 'Rechazar pedido',
                ),
                onPressed: guardando
                    ? null
                    : () async {
                        final finalMotivo = motivo == 'Otro motivo'
                            ? detalle.text.trim()
                            : motivo;
                        if (finalMotivo.isEmpty) {
                          actualizar(
                            () => error = 'Escriba el motivo para continuar.',
                          );
                          return;
                        }
                        actualizar(() {
                          guardando = true;
                          error = null;
                        });
                        final exito = cancelar
                            ? await vm.cancelarPedidoAbastecimiento(
                                pedidoId: item.id,
                                motivo: finalMotivo,
                              )
                            : await vm.rechazarPedidoAbastecimiento(
                                pedidoId: item.id,
                                motivo: finalMotivo,
                              );
                        if (!ctx.mounted) return;
                        if (exito) {
                          Navigator.of(ctx).pop(true);
                        } else {
                          actualizar(() {
                            guardando = false;
                            error = vm.errorMessage ?? 'Intente nuevamente.';
                          });
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
    // Los campos del diálogo terminan su animación antes de disponer controladores.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    detalle.dispose();
    if (resultado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cancelar
                ? 'Solicitud cancelada. Puede crear una nueva.'
                : 'Solicitud rechazada y archivada.',
          ),
          backgroundColor: _rojo,
          action: cancelar
              ? SnackBarAction(
                  label: 'Crear nueva',
                  textColor: Colors.white,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CrearSolicitudAbastecimientoView(),
                    ),
                  ),
                )
              : null,
        ),
      );
    }
  }

  Future<void> _mostrarDialogoRecepcion(PedidoAbastecimientoEntity item) async {
    final cantidades = {
      for (final it in item.items)
        it.id: TextEditingController(text: '${it.cantidadDespachada}'),
    };
    final motivo = TextEditingController();
    final vm = context.read<AlmacenViewModel>();
    final form = GlobalKey<FormState>();
    bool devolver = false;
    bool guardando = false;
    String? error;
    final resultado = await _mostrarModal<bool>( (ctx) => StatefulBuilder(
        builder: (ctx, actualizar) {
          final totalDevuelto = devolver
              ? item.items.fold<int>(
                  0,
                  (total, it) =>
                      total +
                      max(
                        0,
                        it.cantidadDespachada -
                            (int.tryParse(cantidades[it.id]!.text) ??
                                it.cantidadDespachada),
                      ),
                )
              : 0;
          return PopScope(
            canPop: !guardando,
            child: AlertDialog(
            backgroundColor: _blanco,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            actionsOverflowButtonSpacing: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    color: _rojo,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Confirmar recepción física',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.codigo,
                          style: const TextStyle(
                            color: _rojo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Verifique lo recibido y seleccione cómo cerrar el pedido.',
                          style: TextStyle(
                            fontSize: 13,
                            color: _textoSecundario,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Aceptar conforme'),
                              showCheckmark: false,
                            avatar: const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                              ),
                              selected: !devolver,
                              onSelected: guardando
                                  ? null
                                  : (_) => actualizar(() {
                                      devolver = false;
                                      error = null;
                                    }),
                            ),
                            ChoiceChip(
                              label: const Text('Devolver exceso'),
                              showCheckmark: false,
                            avatar: const Icon(
                                Icons.assignment_return_outlined,
                                size: 18,
                              ),
                              selected: devolver,
                              onSelected: guardando
                                  ? null
                                  : (_) => actualizar(() {
                                      devolver = true;
                                      error = null;
                                    }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...item.items.map((it) {
                          final aceptado = devolver
                              ? int.tryParse(cantidades[it.id]!.text)
                              : it.cantidadDespachada;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _grisBorde.withValues(
                                alpha: 0.4,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _grisBorde,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  it.nombreMedicamento,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 6,
                                  children: [
                                    Text(
                                      'Despachado: ${it.cantidadDespachada}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Aceptado: ${aceptado ?? "—"}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Devuelto: ${aceptado == null ? "—" : max(0, it.cantidadDespachada - aceptado)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: devolver
                                            ? _rojo
                                            : _textoSecundario,
                                      ),
                                    ),
                                  ],
                                ),
                                if (devolver) ...[
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    style: const TextStyle(fontSize: 14, color: _texto),
                                    controller: cantidades[it.id],
                                    enabled: !guardando,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Unidades aceptadas',
                                      isDense: false,
                                      border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _grisBorde),
                ),
                                    ),
                                    onChanged: (_) => actualizar(() {}),
                                    validator: (texto) {
                                      final valor = int.tryParse(texto ?? '');
                                      if (valor == null ||
                                          valor < 0 ||
                                          valor > it.cantidadDespachada) {
                                        return 'Ingrese de 0 a ${it.cantidadDespachada} unidades.';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        if (devolver) ...[
                          _aviso(
                            Icons.assignment_return_rounded,
                            '$totalDevuelto unidades a devolver',
                            'Entregue físicamente el exceso a Almacén. Se registrará el retorno al inventario al confirmar.',
                            _rojo,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                                    style: const TextStyle(fontSize: 14, color: _texto),
                            controller: motivo,
                            enabled: !guardando,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Motivo de devolución',
                              hintText:
                                  'Exceso solicitado por error de guardia',
                              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _grisBorde),
                ),
                            ),
                            validator: (texto) => (texto ?? '').trim().isEmpty
                                ? 'Indique el motivo de devolución.'
                                : null,
                          ),
                        ] else
                          _aviso(
                            Icons.verified_outlined,
                            'Recepción conforme',
                            'Se aceptarán todas las unidades despachadas y el pedido quedará completado.',
                            _rojo,
                          ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          _aviso(
                            Icons.info_outline,
                            'Revise antes de continuar',
                            error!,
                            _rojo,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: guardando
                      ? null
                      : () => Navigator.of(ctx).pop(false),
                  child: const Text('Volver'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _rojo,
                  ),
                  icon: guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          devolver
                              ? Icons.assignment_return_rounded
                              : Icons.check_circle_outline,
                          size: 18,
                        ),
                  label: Text(
                    devolver ? 'Confirmar devolución' : 'Aceptar conforme',
                  ),
                  onPressed: guardando
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) {
                            return;
                          }
                          if (devolver && totalDevuelto == 0) {
                            actualizar(
                              () => error =
                                  'Reduzca la cantidad aceptada o seleccione Aceptar conforme.',
                            );
                            return;
                          }
                          actualizar(() {
                            guardando = true;
                            error = null;
                          });
                          final exito = devolver
                              ? await vm.confirmarRecepcionConAjuste(
                                  pedidoId: item.id,
                                  cantidadesAceptadas: {
                                    for (final it in item.items)
                                      it.id: int.parse(cantidades[it.id]!.text),
                                  },
                                  motivoObservacion: motivo.text.trim(),
                                )
                              : await vm.marcarConfirmacionFarmacia(item.id);
                          if (!ctx.mounted) return;
                          if (exito) {
                            Navigator.of(ctx).pop(true);
                          } else {
                            actualizar(() {
                              guardando = false;
                              error =
                                  vm.errorMessage ??
                                  'No se pudo confirmar la recepción.';
                            });
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    motivo.dispose();
    for (final controller in cantidades.values) {
      controller.dispose();
    }
    if (resultado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            devolver
                ? 'Recepción completada con observación. Devolución registrada.'
                : 'Recepción conforme. Pedido completado.',
          ),
          backgroundColor: _rojo,
        ),
      );
    }
  }

  /// Almacén elige la modalidad y confirma el despacho real de stock.
  Future<void> _mostrarDialogoDespacho(
    PedidoAbastecimientoEntity item,
    AlmacenLoaded loaded,
  ) async {
    int disponible(String medicamentoId) => loaded.inventario
        .where(
          (s) =>
              s.medicamento.id == medicamentoId &&
              s.areaCodigo == 'ALMACEN' &&
              s.lote.activo &&
              s.lote.diasParaVencer > 0,
        )
        .fold(0, (total, s) => total + s.cantidad);
    final cantidades = {
      for (final it in item.items)
        it.id: TextEditingController(
          text: '${min(it.cantidadSolicitada, disponible(it.medicamentoId))}',
        ),
    };
    final notas = TextEditingController();
    final form = GlobalKey<FormState>();
    final vm = context.read<AlmacenViewModel>();
    String modalidad = 'RECOJO';
    bool guardando = false;
    String? error;
    final resultado = await _mostrarModal<bool>( (ctx) => StatefulBuilder(
        builder: (ctx, actualizar) => PopScope(
          canPop: !guardando,
          child: AlertDialog(
            backgroundColor: _blanco,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            actionsOverflowButtonSpacing: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: _rojo,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Preparar despacho',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.codigo,
                        style: const TextStyle(
                          color: _rojo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Indique las unidades alistadas y cómo llegarán a Farmacia.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _textoSecundario,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...item.items.map(
                        (it) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _grisBorde.withValues(
                              alpha: 0.4,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _grisBorde),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.nombreMedicamento,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Solicitado: ${it.cantidadSolicitada} • Disponible: ${disponible(it.medicamentoId)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textoSecundario,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                    style: const TextStyle(fontSize: 14, color: _texto),
                                controller: cantidades[it.id],
                                enabled: !guardando,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Unidades a despachar',
                                  border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _grisBorde),
                ),
                                  isDense: false,
                                ),
                                validator: (texto) {
                                  final valor = int.tryParse(texto ?? '');
                                  if (valor == null ||
                                      valor < 0 ||
                                      valor > disponible(it.medicamentoId)) {
                                    return 'Ingrese de 0 a ${disponible(it.medicamentoId)} unidades.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Modalidad de entrega',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Farmacia recoge'),
                            showCheckmark: false,
                            avatar: const Icon(
                              Icons.directions_walk_rounded,
                              size: 18,
                            ),
                            selected: modalidad == 'RECOJO',
                            onSelected: guardando
                                ? null
                                : (_) => actualizar(() => modalidad = 'RECOJO'),
                          ),
                          ChoiceChip(
                            label: const Text('Almacén entrega'),
                            showCheckmark: false,
                            avatar: const Icon(
                              Icons.local_shipping_outlined,
                              size: 18,
                            ),
                            selected: modalidad == 'ENTREGA',
                            onSelected: guardando
                                ? null
                                : (_) =>
                                      actualizar(() => modalidad = 'ENTREGA'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                              style: const TextStyle(fontSize: 14, color: _texto),
                        controller: notas,
                        enabled: !guardando,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Observaciones de despacho (opcional)',
                          border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _grisBorde),
                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _aviso(
                        Icons.inventory_2_outlined,
                        'Confirmación de Almacén',
                        'Al confirmar se transfiere el stock y el pedido queda listo. Farmacia confirmará la recepción física.',
                        _rojo,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        _aviso(
                          Icons.info_outline,
                          'No se pudo despachar',
                          error!,
                          _rojo,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: guardando
                    ? null
                    : () => Navigator.of(ctx).pop(false),
                child: const Text('Volver'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _rojo,
                ),
                icon: guardando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.local_shipping_outlined, size: 18),
                label: const Text('Confirmar despacho'),
                onPressed: guardando
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) {
                          return;
                        }
                        final valores = {
                          for (final it in item.items)
                            it.id: int.parse(cantidades[it.id]!.text),
                        };
                        if (valores.values.every((cantidad) => cantidad == 0)) {
                          actualizar(
                            () => error =
                                'No hay unidades a despachar. Si no puede atender el pedido, utilice Rechazar solicitud.',
                          );
                          return;
                        }
                        actualizar(() {
                          guardando = true;
                          error = null;
                        });
                        final exito = await vm.despacharPedidoAbastecimiento(
                          pedidoId: item.id,
                          cantidadesDespachadas: valores,
                          modalidadEntrega: modalidad,
                          notasDespacho: notas.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        if (exito) {
                          Navigator.of(ctx).pop(true);
                        } else {
                          actualizar(() {
                            guardando = false;
                            error =
                                vm.errorMessage ??
                                'Actualice el stock e intente nuevamente.';
                          });
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    notas.dispose();
    for (final controller in cantidades.values) {
      controller.dispose();
    }
    if (resultado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pedido listo. Stock transferido y modalidad informada a Farmacia.',
          ),
          backgroundColor: _rojo,
        ),
      );
    }
  }
}

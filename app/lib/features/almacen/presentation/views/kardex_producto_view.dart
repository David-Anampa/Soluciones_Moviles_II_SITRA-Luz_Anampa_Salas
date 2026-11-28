import '../../../../core/widgets/selector_catalogo.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../fichas/data/repositories/fichas_repository.dart';
import '../../../fichas/domain/entities/ficha_catalogo_entities.dart';
import '../../domain/entities/stock_ubicacion_entity.dart';
import '../widgets/stock_presentacion.dart';

/// Consulta de auditoría: no calcula saldos sumando transferencias internas.
class KardexProductoView extends StatefulWidget {
  final StockUbicacionEntity producto;
  const KardexProductoView({super.key, required this.producto});

  @override
  State<KardexProductoView> createState() => _KardexProductoViewState();
}

class _KardexProductoViewState extends State<KardexProductoView> {
  final _buscar = TextEditingController();
  final _repositorio = FichasRepository();
  List<MovimientoKardexContratoHu025> _movimientos = [];
  String? _error, _lote;
  String _naturaleza = 'Todos';
  bool _cargando = true;
  int _limite = 150;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _repositorio.consultarKardexMedicamentoHu025(
        widget.producto.id,
        limite: _limite,
      );
      if (!mounted) return;
      setState(() {
        _movimientos = datos;
        if (!datos.any((m) => _claveLote(m) == _lote)) _lote = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = FichasRepository.mensajeError(
            e,
            'No se pudieron consultar los movimientos. Revisa tu conexión e inténtalo de nuevo.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String? _claveLote(MovimientoKardexContratoHu025 m) =>
      m.loteId ?? m.numeroLote;

  String _fecha(BuildContext context, DateTime? fecha, {bool hora = false}) {
    if (fecha == null) return 'Sin fecha registrada';
    final local = MaterialLocalizations.of(context);
    final dia = local.formatMediumDate(fecha);
    return hora
        ? '$dia · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(fecha))}'
        : dia;
  }

  static const _tipos = {
    'ENTRADA': ('Entrada', Icons.south_west_rounded),
    'SALIDA': ('Salida', Icons.north_east_rounded),
    'TRANSFERENCIA': ('Traslado', Icons.local_shipping_outlined),
    'AJUSTE': ('Ajuste / auditoría', Icons.fact_check_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final lotes = <String, String>{};
    for (final m in _movimientos) {
      final clave = _claveLote(m);
      if (clave != null) lotes[clave] = m.numeroLote ?? 'Lote sin número';
    }
    final consulta = _buscar.text.trim().toLowerCase();
    final visibles = _movimientos.where((m) {
      return (_naturaleza == 'Todos' ||
              m.naturalezaMovimiento == _naturaleza) &&
          (_lote == null || _claveLote(m) == _lote) &&
          '${m.descripcion} ${m.numeroFicha ?? ''} ${m.usuarioNombre} '
                  '${m.numeroLote ?? ''} ${m.areaOrigen ?? ''} ${m.areaDestino ?? ''}'
              .toLowerCase()
              .contains(consulta);
    }).toList();
    return Theme(
      data: temaStock(context),
      child: Scaffold(
        backgroundColor: stockFondo,
        appBar: AppBar(
          toolbarHeight: DisenoAdaptable.altoCabecera(
            context,
            base: kToolbarHeight,
          ),
          title: const Text('Kardex del producto'),
          actions: [
            IconButton(
              tooltip: 'Actualizar movimientos',
              onPressed: _cargando ? null : _cargar,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ContenidoAdaptable(
          anchoMaximo: 1100,
          padding: EdgeInsets.zero,
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: _cargar,
              color: stockRojo,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  StockSeccion(
                    titulo: widget.producto.nombre,
                    icono: Icons.medication_outlined,
                    children: [
                      Text(
                        '${widget.producto.presentacion} · ${widget.producto.unidad}',
                      ),
                      StockContadores(item: widget.producto),
                      const Text(
                        'Existencias consultadas al abrir el detalle. El tránsito se muestra separado de la disponibilidad.',
                        style: TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                  StockSeccion(
                    titulo: 'Recorrido del producto',
                    icono: Icons.timeline_rounded,
                    children: [
                      TextField(
                        controller: _buscar,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Buscar ficha, lote, usuario o movimiento',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tipo in ['Todos', ..._tipos.keys])
                            ChoiceChip(
                              label: Text(_tipos[tipo]?.$1 ?? tipo),
                              selected: _naturaleza == tipo,
                              onSelected: (_) =>
                                  setState(() => _naturaleza = tipo),
                            ),
                        ],
                      ),
                      SelectorCatalogo(
                        key: ValueKey(_lote),
                        value: _lote,
                        decoration: const InputDecoration(
                          labelText: 'Filtrar por lote',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos los lotes'),
                          ),
                          for (final lote in lotes.entries)
                            DropdownMenuItem(
                              value: lote.key,
                              child: Text(lote.value),
                            ),
                        ],
                        onChanged: (valor) => setState(() => _lote = valor),
                      ),
                      Text(
                        '${visibles.length} de ${_movimientos.length} movimientos consultados. Más recientes primero.',
                        style: const TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                  if (_cargando)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    StockSeccion(
                      titulo: 'Consulta no disponible',
                      icono: Icons.cloud_off_outlined,
                      children: [
                        Text(_error!),
                        TextButton.icon(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    )
                  else ...[
                    if (visibles.isEmpty)
                      StockSeccion(
                        titulo: _movimientos.isEmpty
                            ? 'Sin movimientos registrados'
                            : 'Sin coincidencias',
                        icono: Icons.manage_search_rounded,
                        children: [
                          Text(
                            _movimientos.isEmpty
                                ? 'Todavía no se registran movimientos para este producto.'
                                : 'Prueba con otro texto, tipo de movimiento o lote.',
                          ),
                        ],
                      ),
                    for (final m in visibles) _movimiento(context, m),
                    if (_movimientos.length >= _limite)
                      StockSeccion(
                        titulo: 'Historial reciente',
                        icono: Icons.history_rounded,
                        children: [
                          Text(
                            'Se muestran hasta $_limite movimientos recientes. Los filtros se aplican a esta consulta, no al historial completo.',
                          ),
                          if (_limite < 500)
                            OutlinedButton.icon(
                              onPressed: () {
                                _limite = 500;
                                _cargar();
                              },
                              icon: const Icon(Icons.expand_more_rounded),
                              label: const Text(
                                'Consultar hasta 500 movimientos',
                              ),
                            ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _movimiento(BuildContext context, MovimientoKardexContratoHu025 m) {
    final tipo = _tipos[m.naturalezaMovimiento] ?? _tipos['AJUSTE']!;
    return StockSeccion(
      titulo: tipo.$1,
      icono: tipo.$2,
      compacta: true,
      children: [
        Text(_fecha(context, m.fechaEvento, hora: true)),
        Text(
          m.descripcion.isEmpty ? 'Movimiento registrado' : m.descripcion,
          style: const TextStyle(height: 1.5),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('${m.cantidad} ${widget.producto.unidad}')),
            if (m.numeroLote != null) Chip(label: Text('Lote ${m.numeroLote}')),
            if (m.numeroFicha != null)
              Chip(label: Text('Ficha ${m.numeroFicha}')),
          ],
        ),
        if (m.areaOrigen != null || m.areaDestino != null)
          Text(
            'Origen: ${m.areaOrigen ?? 'Sin registrar'} · Destino: ${m.areaDestino ?? 'Sin registrar'}',
          ),
        if (m.fechaVencimiento != null)
          Text('Vencimiento del lote: ${_fecha(context, m.fechaVencimiento)}'),
        Text(
          'Registrado por ${m.usuarioNombre}',
          style: const TextStyle(height: 1.5),
        ),
      ],
    );
  }
}

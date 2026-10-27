import 'package:flutter/material.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../data/repositories/stock_ubicaciones_repository.dart';
import '../../domain/entities/stock_ubicacion_entity.dart';
import '../widgets/stock_presentacion.dart';
import 'crear_solicitud_abastecimiento_view.dart';

/// HU-023: cantidades separadas; el tránsito no es disponibilidad en Farmacia.
class StockUbicacionesView extends StatefulWidget {
  final bool puedeSolicitar, puedeEnviar;
  final StockUbicacionesRepository repositorio;
  const StockUbicacionesView({
    super.key,
    this.puedeSolicitar = false,
    this.puedeEnviar = false,
    this.repositorio = const StockUbicacionesRepository(),
  });
  @override
  State<StockUbicacionesView> createState() => _StockUbicacionesViewState();
}

class _StockUbicacionesViewState extends State<StockUbicacionesView> {
  final _buscar = TextEditingController();
  List<StockUbicacionEntity> _items = [];
  bool _cargando = true;
  String? _error;
  String _filtro = 'Todos';
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
      final datos = await widget.repositorio.cargar();
      if (mounted) setState(() => _items = datos);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo consultar el stock real. Revisa la conexión y la migración.',
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrir(StockUbicacionEntity item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CrearSolicitudAbastecimientoView(
          iniciadoPorAlmacen: widget.puedeEnviar,
          productoInicial: item,
          repositorio: widget.repositorio,
        ),
      ),
    );
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final q = _buscar.text.trim().toLowerCase();
    final visibles = _items.where((p) {
      if (!('${p.nombre} ${p.principioActivo} ${p.gtin}'.toLowerCase().contains(
        q,
      ))) {
        return false;
      }
      if (_filtro == 'Falta en Farmacia') {
        return p.farmacia == 0 && p.almacen > 0;
      }
      if (_filtro == 'En tránsito') return p.transito > 0;
      return true;
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
          title: const Text(
            'Stock por ubicación',
            style: TextStyle(fontSize: 18),
          ),
        ),
        body: ContenidoAdaptable(
          anchoMaximo: 1100,
          padding: EdgeInsets.zero,
          child: SafeArea(
            child: _cargando
                ? const Center(
                    child: CircularProgressIndicator(color: stockRojo),
                  )
                : RefreshIndicator(
                    onRefresh: _cargar,
                    color: stockRojo,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        StockSeccion(
                          titulo: 'Disponibilidad real',
                          icono: Icons.inventory_2_outlined,
                          children: [
                            const Text(
                              'Farmacia muestra solo lo recibido y disponible. Almacén conserva lo que aún no ha enviado.',
                              style: TextStyle(height: 1.5),
                            ),
                            TextField(
                              controller: _buscar,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Buscar producto o código',
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: stockRojo,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final f in [
                                  'Todos',
                                  'Falta en Farmacia',
                                  'En tránsito',
                                ])
                                  ChoiceChip(
                                    label: Text(f),
                                    selected: _filtro == f,
                                    selectedColor: stockPastel,
                                    onSelected: (_) =>
                                        setState(() => _filtro = f),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        if (_error != null)
                          StockSeccion(
                            titulo: 'Consulta no disponible',
                            icono: Icons.error_outline,
                            children: [
                              Text(_error!),
                              TextButton.icon(
                                onPressed: _cargar,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        if (_error == null && visibles.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No hay productos para este filtro.'),
                          ),
                        if (_error == null)
                          for (final p in visibles)
                            StockSeccion(
                              titulo: p.nombre,
                              icono: Icons.medication_outlined,
                              children: [
                                Text(
                                  '${p.presentacion} · ${p.unidad}',
                                  style: const TextStyle(
                                    color: Color(0xFF64646D),
                                  ),
                                ),
                                StockContadores(item: p),
                                if (p.farmacia == 0 && p.almacen > 0)
                                  const Text(
                                    'Disponible en Almacén. Requiere traslado y recepción para utilizarse en Farmacia.',
                                    style: TextStyle(
                                      height: 1.5,
                                      color: stockRojo,
                                    ),
                                  ),
                                if (p.transito > 0)
                                  const Text(
                                    'Las unidades en tránsito aún no pueden dispensarse.',
                                    style: TextStyle(height: 1.5),
                                  ),
                                if (!p.activo)
                                  const Text(
                                    'Producto deshabilitado. Se conserva su existencia física.',
                                  ),
                                if (p.almacenFisico != p.almacen ||
                                    p.farmaciaFisico != p.farmacia)
                                  Text(
                                    'Físico: Almacén ${p.almacenFisico} · Farmacia ${p.farmaciaFisico}. La disponibilidad excluye lotes vencidos o deshabilitados.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                if (p.pendienteConciliacion)
                                  const Text(
                                    'Existe un despacho anterior pendiente de conciliación.',
                                    style: TextStyle(color: stockRojo),
                                  ),
                                if ((widget.puedeSolicitar ||
                                        widget.puedeEnviar) &&
                                    p.activo &&
                                    p.almacen > 0)
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () => _abrir(p),
                                      icon: Icon(
                                        widget.puedeEnviar
                                            ? Icons.local_shipping_outlined
                                            : Icons.add_shopping_cart_rounded,
                                      ),
                                      label: Text(
                                        widget.puedeEnviar
                                            ? 'Enviar a Farmacia'
                                            : 'Solicitar a Almacén',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

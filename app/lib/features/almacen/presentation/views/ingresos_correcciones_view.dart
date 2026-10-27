import 'package:flutter/material.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/ingresos_repository.dart';
import '../../domain/solicitud_id.dart';
import '../widgets/stock_presentacion.dart';

String _errorIngreso(Object e) => e is PostgrestException
    ? e.message
    : 'No se pudo completar la operación. Revisa la conexión.';

/// Distingue cantidad ingresada de existencias restantes y conserva el original.
class IngresosCorreccionesView extends StatefulWidget {
  final bool soloLectura;
  const IngresosCorreccionesView({super.key, this.soloLectura = false});
  @override
  State<IngresosCorreccionesView> createState() => _IngresosState();
}

class _IngresosState extends State<IngresosCorreccionesView> {
  final _repo = IngresosRepository();
  final _buscar = TextEditingController();
  List<Map<String, dynamic>> _ingresos = [];
  bool _cargando = true;
  String? _error;
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
      final datos = await _repo.listar();
      if (mounted) setState(() => _ingresos = datos);
    } catch (e) {
      if (mounted) setState(() => _error = _errorIngreso(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _buscar.text.trim().toLowerCase();
    final lista = _ingresos
        .where(
          (r) => '${r['nombre']} ${r['numero_lote']} ${r['num_boleta'] ?? ''}'
              .toLowerCase()
              .contains(q),
        )
        .toList();
    return Theme(
      data: temaStock(context),
      child: Scaffold(
        backgroundColor: stockFondo,
        appBar: AppBar(
          toolbarHeight: DisenoAdaptable.altoCabecera(
            context,
            base: kToolbarHeight,
          ),
          title: const Text('Ingresos y correcciones'),
          actions: [
            IconButton(
              onPressed: _cargando ? null : _cargar,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar',
            ),
          ],
        ),
        body: ContenidoAdaptable(
          anchoMaximo: 1100,
          padding: EdgeInsets.zero,
          child: SafeArea(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        StockSeccion(
                          titulo: 'El ingreso conserva su historia',
                          icono: Icons.receipt_long_outlined,
                          children: [
                            const Text(
                              'Una corrección ajusta la diferencia. El ingreso original, su documento y los movimientos posteriores se conservan.',
                              style: TextStyle(height: 1.5),
                            ),
                            TextField(
                              controller: _buscar,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Producto, lote o documento',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                            ),
                          ],
                        ),
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(color: stockRojo),
                          ),
                        if (lista.isEmpty && _error == null)
                          const StockSeccion(
                            titulo: 'Sin ingresos en esta vista',
                            icono: Icons.inventory_2_outlined,
                            children: [
                              Text(
                                'Prueba otra búsqueda o registra un ingreso desde Almacén.',
                              ),
                            ],
                          ),
                        for (final r in lista)
                          StockSeccion(
                            titulo: r['nombre'],
                            icono: Icons.medication_outlined,
                            children: [
                              Text(
                                'Lote ${r['numero_lote']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: stockRojo,
                                ),
                              ),
                              Text(
                                'Documento: ${r['num_boleta'] ?? 'Sin documento'}\nCosto unitario registrado: ${r['precio_compra'] ?? 'Sin costo'}',
                                style: const TextStyle(height: 1.6),
                              ),
                              if (r['cantidad_original'] != null)
                                Text(
                                  'Ingreso original: ${r['cantidad_original']}\nCantidad de ingreso vigente: ${r['cantidad_registrada']}',
                                  style: const TextStyle(height: 1.6),
                                )
                              else
                                const Text(
                                  'Ingreso histórico pendiente de conciliación: no existe una cantidad original inequívoca.',
                                  style: TextStyle(
                                    color: stockRojo,
                                    height: 1.5,
                                  ),
                                ),
                              Text(
                                'Existencias actuales · Almacén: ${r['almacen']} · Farmacia: ${r['farmacia']}',
                                style: const TextStyle(height: 1.5),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _historial(r),
                                icon: const Icon(Icons.history_rounded),
                                label: const Text('Ver historial'),
                              ),
                              if (!widget.soloLectura &&
                                  r['cantidad_registrada'] != null)
                                FilledButton.icon(
                                  onPressed: () => _corregir(r),
                                  icon: const Icon(Icons.edit_note_rounded),
                                  label: const Text('Corregir cantidad'),
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

  Future<void> _corregir(Map<String, dynamic> r) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CorreccionIngreso(r: r, repo: _repo),
      ),
    );
    if (cambio == true) await _cargar();
  }

  void _historial(Map<String, dynamic> r) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (ctx) => Theme(
        data: temaStock(ctx),
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: DisenoAdaptable.altoCabecera(
              context,
              base: kToolbarHeight,
            ),
            title: const Text('Historial del ingreso'),
          ),
          backgroundColor: stockFondo,
          body: ContenidoAdaptable(
            anchoMaximo: 1100,
            padding: EdgeInsets.zero,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  StockSeccion(
                    titulo: r['nombre'],
                    icono: Icons.inventory_2_outlined,
                    children: [
                      Text('Lote ${r['numero_lote']}'),
                      Text(
                        'Cantidad original: ${r['cantidad_original'] ?? 'Por conciliar'}',
                      ),
                    ],
                  ),
                  for (final h in r['historial'])
                    StockSeccion(
                      titulo: h['evento'] == 'INGRESO_ALMACEN'
                          ? 'Ingreso original'
                          : 'Corrección justificada',
                      icono: Icons.history_rounded,
                      children: [
                        Text(
                          '${h['usuario'] ?? 'Usuario histórico'} · ${_fechaIngreso(h['fecha'])}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        Text(
                          h['motivo'] ?? '',
                          style: const TextStyle(height: 1.5),
                        ),
                        Text('Unidades del movimiento: ${h['cantidad']}'),
                        if (h['evento'] == 'AJUSTE_INGRESO_LOTE')
                          Text(
                            'Ingreso: ${h['antes']['cantidad_registrada']} a ${h['despues']['cantidad_registrada']}\nUbicación: ${h['despues']['ubicacion']}',
                            style: const TextStyle(height: 1.5),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String _fechaIngreso(dynamic f) {
  final d = DateTime.tryParse('$f')?.toLocal();
  return d == null
      ? ''
      : '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

class _CorreccionIngreso extends StatefulWidget {
  final Map<String, dynamic> r;
  final IngresosRepository repo;
  const _CorreccionIngreso({required this.r, required this.repo});
  @override
  State<_CorreccionIngreso> createState() => _CorreccionState();
}

class _CorreccionState extends State<_CorreccionIngreso> {
  final _form = GlobalKey<FormState>();
  final _cantidad = TextEditingController(), _motivo = TextEditingController();
  String _ubicacion = 'ALMACEN', _operacion = generarSolicitudId();
  String? _firma, _error;
  bool _guardando = false;
  Map<String, dynamic> get r => widget.r;
  @override
  void initState() {
    super.initState();
    _cantidad.text = '${r['cantidad_registrada']}';
  }

  @override
  void dispose() {
    _cantidad.dispose();
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = int.tryParse(_cantidad.text);
    final delta = total == null ? 0 : total - (r['cantidad_registrada'] as int);
    return Theme(
      data: temaStock(context),
      child: PopScope(
        canPop: !_guardando,
        child: Scaffold(
          backgroundColor: stockFondo,
          appBar: AppBar(
            toolbarHeight: DisenoAdaptable.altoCabecera(
              context,
              base: kToolbarHeight,
            ),
            title: const Text('Corregir ingreso'),
          ),
          body: ContenidoAdaptable(
            anchoMaximo: 1100,
            padding: EdgeInsets.zero,
            child: SafeArea(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    StockSeccion(
                      titulo: r['nombre'],
                      icono: Icons.edit_note_rounded,
                      children: [
                        Text(
                          'Lote ${r['numero_lote']} · Ingreso original: ${r['cantidad_original']}',
                          style: const TextStyle(
                            color: stockRojo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          'Ingresa el total correcto del ingreso, no el stock que queda hoy. Se aplicará únicamente la diferencia.',
                          style: TextStyle(height: 1.5),
                        ),
                        TextFormField(
                          controller: _cantidad,
                          enabled: !_guardando,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Cantidad correcta del ingreso',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            return n == null || n < 0 || n > 2147483647
                                ? 'Ingresa una cantidad válida.'
                                : null;
                          },
                        ),
                        if (delta < 0)
                          DropdownButtonFormField<String>(
                            itemHeight: null,
                            isDense: false,
                            initialValue: _ubicacion,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Ubicación física que se corrige',
                              prefixIcon: Icon(Icons.place_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'ALMACEN',
                                child: Text('Almacén'),
                              ),
                              DropdownMenuItem(
                                value: 'FARMACIA',
                                child: Text('Farmacia'),
                              ),
                            ],
                            onChanged: _guardando
                                ? null
                                : (v) => setState(() => _ubicacion = v!),
                          ),
                        Text(
                          delta > 0
                              ? 'Las $delta unidades adicionales quedarán en Almacén.'
                              : delta < 0
                              ? 'Se descontarán ${-delta} unidades solo de la ubicación físicamente verificada. No se tocará el stock de las áreas ni el tránsito.'
                              : 'Modifica la cantidad para preparar un ajuste.',
                          style: const TextStyle(height: 1.5),
                        ),
                      ],
                    ),
                    StockSeccion(
                      titulo: 'Justificación de la corrección',
                      icono: Icons.description_outlined,
                      children: [
                        TextFormField(
                          controller: _motivo,
                          enabled: !_guardando,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 1000,
                          decoration: const InputDecoration(
                            labelText: 'Qué se verificó y por qué se corrige',
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'La justificación es obligatoria.'
                              : null,
                        ),
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: stockRojo,
                              height: 1.5,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: _guardando ? null : _preconfirmar,
                icon: const Icon(Icons.preview_outlined),
                label: Text(_guardando ? 'Guardando…' : 'Revisar corrección'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _preconfirmar() async {
    if (!_form.currentState!.validate()) return;
    final total = int.tryParse(_cantidad.text);
    if (total == null ||
        total < 0 ||
        total > 2147483647 ||
        _motivo.text.trim().isEmpty) {
      setState(() => _error = 'Revisa cantidad y justificación.');
      return;
    }
    final delta = total - (r['cantidad_registrada'] as int),
        ubicacion = total > (r['cantidad_registrada'] as int)
            ? 'ALMACEN'
            : _ubicacion;
    if (delta == 0) {
      setState(() => _error = 'La cantidad no cambió.');
      return;
    }
    if (delta < 0 &&
        (r[ubicacion == 'ALMACEN' ? 'almacen' : 'farmacia'] as int) < -delta) {
      setState(
        () => _error =
            'No hay stock suficiente en esa ubicación. Verifica la diferencia; no se descontarán unidades ya distribuidas o consumidas.',
      );
      return;
    }
    final filas = [
      ('Ingreso vigente', r['cantidad_registrada'] as int, total),
      (
        'Almacén',
        r['almacen'] as int,
        (r['almacen'] as int) + (ubicacion == 'ALMACEN' ? delta : 0),
      ),
      (
        'Farmacia',
        r['farmacia'] as int,
        (r['farmacia'] as int) + (ubicacion == 'FARMACIA' ? delta : 0),
      ),
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: temaStock(ctx),
        child: AlertaAdaptable(
          title: const Text('Preconfirmar corrección'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lote ${r['numero_lote']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TablaAdaptable(
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.5),
                      1: FlexColumnWidth(),
                      2: FlexColumnWidth(1.2),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: stockPastel),
                        children: [
                          for (final t in ['Nombre', 'Antes', 'Después'])
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                t,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: stockRojo,
                                ),
                              ),
                            ),
                        ],
                      ),
                      for (final f in filas)
                        TableRow(
                          children: [
                            for (final v in [f.$1, '${f.$2}', '${f.$3}'])
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(v),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Justificación: ${_motivo.text.trim()}',
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'El ingreso original y los despachos anteriores se conservan. Confirma que verificaste físicamente la ubicación seleccionada.',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver a revisar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aplicar corrección'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final firma = '$total|$ubicacion|${_motivo.text.trim()}';
    if (_firma != firma) {
      _firma = firma;
      _operacion = generarSolicitudId();
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repo.corregir(
        loteId: r['id'],
        total: total,
        ubicacion: ubicacion,
        motivo: _motivo.text.trim(),
        version: r['version'],
        operacion: _operacion,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = _errorIngreso(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

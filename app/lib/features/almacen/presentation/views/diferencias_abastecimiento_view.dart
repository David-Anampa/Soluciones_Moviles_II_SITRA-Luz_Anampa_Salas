import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/solicitud_id.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/diferencias_repository.dart';
import '../../domain/entities/pedido_abastecimiento_entity.dart';
import '../widgets/stock_presentacion.dart';

String _errorDiferencia(Object e) => e is PostgrestException
    ? e.message
    : 'No se pudo completar la operación. Revisa la conexión y vuelve a intentar.';

String _estado(String valor) => switch (valor) {
  'PROPUESTA' => 'Espera confirmación de Farmacia',
  'PENDIENTE' => 'Pendiente de revisión',
  'RESUELTO' => 'Resuelto',
  'CANCELADO' => 'Cancelado',
  'RECHAZADO' => 'Rechazado',
  _ => valor,
};
String _accion(String valor) => switch (valor) {
  'REPORTAR' => 'Farmacia reportó una diferencia',
  'RESOLVER' => 'Almacén revisó la solución',
  'CONFIRMAR' => 'Farmacia confirmó la propuesta',
  'DEVOLVER_PROPUESTA' => 'Farmacia pidió revisar la propuesta',
  'CANCELAR' => 'Reporte cancelado',
  'RECHAZAR' => 'Reporte rechazado',
  _ => valor,
};

/// Bandeja e historial compartidos. Los permisos efectivos se validan en el servidor.
class DiferenciasAbastecimientoView extends StatefulWidget {
  final bool esFarmacia;
  final bool soloLectura;
  final DiferenciasRepository repositorio;
  const DiferenciasAbastecimientoView({
    super.key,
    this.esFarmacia = false,
    this.soloLectura = false,
    this.repositorio = const DiferenciasRepository(),
  });
  @override
  State<DiferenciasAbastecimientoView> createState() => _DiferenciasState();
}

class _DiferenciasState extends State<DiferenciasAbastecimientoView> {
  List<Map<String, dynamic>> _reportes = [];
  bool _cargando = true, _historial = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await widget.repositorio.listar();
      if (mounted) setState(() => _reportes = datos);
    } catch (e) {
      if (mounted) setState(() => _error = _errorDiferencia(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = _reportes
        .where(
          (r) => _historial || ['PENDIENTE', 'PROPUESTA'].contains(r['estado']),
        )
        .toList();
    return Theme(
      data: temaStock(context),
      child: Scaffold(
        backgroundColor: stockFondo,
        appBar: AppBar(
          title: Text(
            widget.esFarmacia ? 'Mis reportes' : 'Diferencias e historial',
          ),
          actions: [
            IconButton(
              onPressed: _cargando ? null : _cargar,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar',
            ),
          ],
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    StockSeccion(
                      titulo: 'Cada diferencia tiene seguimiento',
                      icono: Icons.fact_check_outlined,
                      children: [
                        const Text(
                          'Revisa lo reportado, las respuestas y la solución. El historial conserva responsables, cantidades y justificaciones.',
                          style: TextStyle(height: 1.5),
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ChoiceChip(
                              label: const Text('Por resolver'),
                              avatar: const Icon(
                                Icons.pending_actions,
                                size: 18,
                              ),
                              selected: !_historial,
                              onSelected: (_) =>
                                  setState(() => _historial = false),
                            ),
                            ChoiceChip(
                              label: const Text('Todos e historial'),
                              avatar: const Icon(
                                Icons.history_rounded,
                                size: 18,
                              ),
                              selected: _historial,
                              onSelected: (_) =>
                                  setState(() => _historial = true),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_error != null) _aviso(_error!),
                    if (lista.isEmpty && _error == null)
                      const StockSeccion(
                        titulo: 'Todo al día',
                        icono: Icons.task_alt_rounded,
                        children: [Text('No hay reportes en esta vista.')],
                      ),
                    for (final r in lista)
                      StockSeccion(
                        titulo: r['codigo'] as String,
                        icono: Icons.assignment_outlined,
                        children: [
                          Text(
                            _estado(r['estado']),
                            style: const TextStyle(
                              color: stockRojo,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${r['reportante']} · ${_fecha(r['created_at'])}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          Text(
                            r['motivo'],
                            style: const TextStyle(height: 1.5),
                          ),
                          for (final i in (r['items'] as List))
                            Text(
                              '${i['nombre']}\nDespachado: ${i['despachado']} · Contado: ${i['contado']}',
                              style: const TextStyle(height: 1.6),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => _verHistorial(r),
                            icon: const Icon(Icons.history_rounded),
                            label: const Text('Ver detalle e historial'),
                          ),
                          if (!widget.soloLectura &&
                              [
                                'PENDIENTE',
                                'PROPUESTA',
                              ].contains(r['estado'])) ...[
                            if (widget.esFarmacia) ...[
                              if (r['estado'] == 'PROPUESTA')
                                FilledButton.icon(
                                  onPressed: () => _editar(r, 'CONFIRMAR'),
                                  icon: const Icon(Icons.fact_check_outlined),
                                  label: const Text('Revisar propuesta'),
                                ),
                              if (r['estado'] == 'PROPUESTA')
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _editar(r, 'DEVOLVER_PROPUESTA'),
                                  icon: const Icon(Icons.reply_rounded),
                                  label: const Text('Pedir otra revisión'),
                                ),
                              TextButton.icon(
                                onPressed: () => _editar(r, 'CANCELAR'),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancelar reporte'),
                              ),
                            ] else ...[
                              if (r['estado'] == 'PENDIENTE')
                                FilledButton.icon(
                                  onPressed: () => _editar(r, 'RESOLVER'),
                                  icon: const Icon(Icons.build_circle_outlined),
                                  label: const Text('Solucionar'),
                                ),
                              OutlinedButton.icon(
                                onPressed: () => _editar(r, 'RECHAZAR'),
                                icon: const Icon(Icons.block_rounded),
                                label: const Text('Rechazar con motivo'),
                              ),
                            ],
                          ],
                        ],
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _aviso(String mensaje) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Text(mensaje, style: const TextStyle(color: stockRojo, height: 1.5)),
  );
  Future<void> _editar(Map<String, dynamic> r, String accion) async {
    // Recupera la versión y el stock que se mostrarán en la preconfirmación.
    try {
      final datos = await widget.repositorio.listar();
      final actual = datos.firstWhere((e) => e['id'] == r['id']);
      if (!mounted) return;
      final cambio = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _SolucionView(
            reporte: actual,
            accion: accion,
            repo: widget.repositorio,
          ),
        ),
      );
      if (cambio == true) await _cargar();
    } catch (e) {
      if (mounted) setState(() => _error = _errorDiferencia(e));
    }
  }

  void _verHistorial(Map<String, dynamic> r) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Theme(
          data: temaStock(context),
          child: Scaffold(
            appBar: AppBar(title: const Text('Detalle e historial')),
            backgroundColor: stockFondo,
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StockSeccion(
                  titulo: r['codigo'],
                  icono: Icons.receipt_long_outlined,
                  children: [
                    Text(_estado(r['estado'])),
                    Text('Reporte original: ${r['motivo']}'),
                    for (final i in r['items'])
                      Text(
                        '${i['nombre']}\nDespachado: ${i['despachado']} · Conteo original: ${i['contado']}',
                        style: const TextStyle(height: 1.6),
                      ),
                  ],
                ),
                for (final h in r['historial'])
                  StockSeccion(
                    titulo: _accion(h['accion']),
                    icono: Icons.history_rounded,
                    children: [
                      Text(
                        '${h['usuario']} · ${_fecha(h['fecha'])}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      Text(h['motivo'], style: const TextStyle(height: 1.5)),
                      Text('Estado: ${_estado(h['resultado']['estado'])}'),
                      if (h['resultado']['propuesta'] != null)
                        for (final i in r['items'])
                          Text(
                            '${i['nombre']}: ${h['resultado']['propuesta'][i['id']]} unidades propuestas',
                          ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _fecha(dynamic fecha) {
  final d = DateTime.tryParse('$fecha')?.toLocal();
  return d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _SolucionView extends StatefulWidget {
  final Map<String, dynamic> reporte;
  final String accion;
  final DiferenciasRepository repo;
  const _SolucionView({
    required this.reporte,
    required this.accion,
    required this.repo,
  });
  @override
  State<_SolucionView> createState() => _SolucionState();
}

class _SolucionState extends State<_SolucionView> {
  final _form = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  final _cantidades = <String, TextEditingController>{};
  String _destino = 'ALMACEN';
  String? _error;
  bool _guardando = false;
  String? _firma;
  String _token = generarSolicitudId();
  Map<String, dynamic> get r => widget.reporte;
  bool get _resolver => widget.accion == 'RESOLVER';
  bool get _confirmar => widget.accion == 'CONFIRMAR';
  @override
  void initState() {
    super.initState();
    _destino = r['destino'] ?? 'ALMACEN';
    for (final i in r['items']) {
      _cantidades[i['id']] = TextEditingController(
        text: '${_confirmar ? r['propuesta'][i['id']] : i['contado']}',
      );
    }
  }

  @override
  void dispose() {
    _motivo.dispose();
    for (final c in _cantidades.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: temaStock(context),
    child: PopScope(
      canPop: !_guardando,
      child: Scaffold(
        backgroundColor: stockFondo,
        appBar: AppBar(
          title: Text(
            _resolver
                ? 'Solucionar diferencia'
                : _confirmar
                ? 'Revisar propuesta'
                : 'Justificar acción',
          ),
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StockSeccion(
                titulo: r['codigo'],
                icono: Icons.assignment_outlined,
                children: [
                  Text(
                    'Farmacia reportó: ${r['motivo']}',
                    style: const TextStyle(height: 1.5),
                  ),
                  if (_resolver)
                    DropdownButtonFormField<String>(
                      initialValue: _destino,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '¿Qué se comprobó?',
                        prefixIcon: Icon(Icons.rule_folder_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ALMACEN',
                          child: Text('Quedaron en Almacén'),
                        ),
                        DropdownMenuItem(
                          value: 'ENTREGA',
                          child: Text('Entrega pendiente realizada'),
                        ),
                        DropdownMenuItem(
                          value: 'PERDIDA',
                          child: Text('Pérdida comprobada'),
                        ),
                      ],
                      onChanged: _guardando
                          ? null
                          : (v) => setState(() {
                              _destino = v!;
                              if (v == 'ENTREGA') {
                                for (final i in r['items']) {
                                  _cantidades[i['id']]!.text =
                                      '${i['despachado']}';
                                }
                              }
                            }),
                    ),
                  if (_confirmar)
                    Text(
                      'Solución de Almacén: ${r['justificacion']}\n${_destinoTexto(_destino)}',
                      style: const TextStyle(
                        height: 1.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (_resolver || _confirmar)
                    const Text(
                      'El conteo original se conserva. Un cambio de conteo necesita la confirmación de Farmacia.',
                      style: TextStyle(height: 1.5, color: Colors.black54),
                    ),
                ],
              ),
              if (_resolver || _confirmar)
                for (final i in r['items'])
                  StockSeccion(
                    titulo: i['nombre'],
                    icono: Icons.medication_outlined,
                    children: [
                      Text(
                        'Despachado: ${i['despachado']} · Conteo original: ${i['contado']}',
                      ),
                      TextFormField(
                        controller: _cantidades[i['id']],
                        enabled:
                            _resolver && !_guardando && _destino != 'ENTREGA',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Cantidad que Farmacia recibió',
                          prefixIcon: Icon(Icons.fact_check_outlined),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          return n == null ||
                                  n < 0 ||
                                  n > (i['despachado'] as num)
                              ? 'Ingrese de 0 a ${i['despachado']}.'
                              : null;
                        },
                      ),
                    ],
                  ),
              StockSeccion(
                titulo: 'Justificación obligatoria',
                icono: Icons.edit_note_rounded,
                children: [
                  TextFormField(
                    controller: _motivo,
                    enabled: !_guardando,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Explica qué verificaste y por qué',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Escribe una justificación.'
                        : null,
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: stockRojo, height: 1.5),
                    ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _guardando ? null : _preconfirmar,
              icon: Icon(
                _guardando
                    ? Icons.hourglass_top_rounded
                    : Icons.preview_outlined,
              ),
              label: Text(
                _guardando ? 'Guardando…' : 'Revisar antes de confirmar',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Future<void> _preconfirmar() async {
    if (!_form.currentState!.validate()) return;
    if (_cantidades.entries.any((e) {
      final n = int.tryParse(e.value.text);
      final i = (r['items'] as List).firstWhere((i) => i['id'] == e.key);
      return n == null || n < 0 || n > (i['despachado'] as num);
    })) {
      setState(
        () => _error = 'Revisa todas las cantidades antes de continuar.',
      );
      return;
    }
    final cantidades = {
      for (final e in _cantidades.entries) e.key: int.parse(e.value.text),
    };
    final cambio =
        _resolver &&
        (r['conteo'] as Map).entries.any((e) => cantidades[e.key] != e.value);
    final aplica = (_resolver && !cambio) || _confirmar;
    final aprobado = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: temaStock(ctx),
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: stockRojo),
              SizedBox(width: 12),
              Expanded(child: Text('Revisa la operación')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aplica
                      ? 'Se aplicarán estos movimientos:'
                      : cambio
                      ? 'Se enviará una propuesta a Farmacia. El stock no cambiará hasta que confirme.'
                      : 'Se registrará la acción sin modificar stock.',
                  style: const TextStyle(height: 1.5),
                ),
                if (aplica)
                  for (final i in r['items']) ...[
                    const SizedBox(height: 16),
                    Text(
                      i['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Farmacia: antes ${i['farmacia']} / después ${(i['farmacia'] as num) + cantidades[i['id']]!}',
                    ),
                    Text(
                      'Almacén: antes ${i['almacen']} / después ${(i['almacen'] as num) + (_destino == 'ALMACEN' ? (i['despachado'] as num) - cantidades[i['id']]! : 0)}',
                    ),
                    Text(
                      'En tránsito del pedido: antes ${i['despachado']} / después 0',
                    ),
                    if (_destino == 'PERDIDA')
                      Text(
                        'Pérdida justificada: ${(i['despachado'] as num) - cantidades[i['id']]!}',
                        style: const TextStyle(color: stockRojo),
                      ),
                  ],
                if (cambio)
                  for (final i in r['items'])
                    Text(
                      '${i['nombre']}: de ${i['contado']} a ${cantidades[i['id']]} unidades recibidas',
                    ),
                const SizedBox(height: 16),
                Text(
                  'Justificación: ${_motivo.text.trim()}',
                  style: const TextStyle(height: 1.5),
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
              child: Text(cambio ? 'Enviar propuesta' : 'Confirmar operación'),
            ),
          ],
        ),
      ),
    );
    if (aprobado != true || !mounted) return;
    final firma =
        '${widget.accion}|$_destino|$cantidades|${_motivo.text.trim()}';
    if (_firma != firma) {
      _firma = firma;
      _token = generarSolicitudId();
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repo.gestionar(
        pedidoId: r['pedido_id'],
        accion: widget.accion,
        motivo: _motivo.text.trim(),
        operacionId: _token,
        cantidades: _resolver ? cantidades : const {},
        destino: _resolver ? _destino : null,
        version: r['version'],
        saldoVersion: r['saldo_version'],
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = _errorDiferencia(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

String _destinoTexto(String d) => switch (d) {
  'ALMACEN' => 'El faltante quedó físicamente en Almacén.',
  'PERDIDA' => 'Se registrará una pérdida justificada.',
  'ENTREGA' => 'Almacén indica que entregó las unidades pendientes.',
  _ => d,
};

/// Conteo reportado sin acreditar existencias hasta que se resuelva la diferencia.
Future<bool> reportarDiferencia(
  BuildContext context,
  PedidoAbastecimientoEntity pedido, {
  DiferenciasRepository repositorio = const DiferenciasRepository(),
}) async {
  return await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _ReporteView(pedido: pedido, repo: repositorio),
        ),
      ) ==
      true;
}

class _ReporteView extends StatefulWidget {
  final PedidoAbastecimientoEntity pedido;
  final DiferenciasRepository repo;
  const _ReporteView({required this.pedido, required this.repo});
  @override
  State<_ReporteView> createState() => _ReporteState();
}

class _ReporteState extends State<_ReporteView> {
  final _form = GlobalKey<FormState>();
  final _motivo = TextEditingController();
  final _cantidades = <String, TextEditingController>{};
  bool _guardando = false;
  String? _error;
  String? _firma;
  String _token = generarSolicitudId();
  @override
  void initState() {
    super.initState();
    for (final i in widget.pedido.items) {
      _cantidades[i.id] = TextEditingController(
        text: '${i.cantidadDespachada}',
      );
    }
  }

  @override
  void dispose() {
    _motivo.dispose();
    for (final c in _cantidades.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: temaStock(context),
    child: PopScope(
      canPop: !_guardando,
      child: Scaffold(
        appBar: AppBar(title: const Text('Reportar diferencia')),
        backgroundColor: stockFondo,
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StockSeccion(
                titulo: widget.pedido.codigo,
                icono: Icons.fact_check_outlined,
                children: const [
                  Text(
                    'Cuenta lo que llegó físicamente. Este reporte no devuelve unidades a Almacén ni acredita stock en Farmacia. El pedido quedará pendiente de revisión.',
                    style: TextStyle(height: 1.6),
                  ),
                ],
              ),
              for (final i in widget.pedido.items)
                StockSeccion(
                  titulo: i.nombreMedicamento,
                  icono: Icons.medication_outlined,
                  children: [
                    Text(
                      'Almacén declaró ${i.cantidadDespachada} unidades despachadas.',
                    ),
                    TextFormField(
                      controller: _cantidades[i.id],
                      enabled: !_guardando,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Unidades contadas',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n == null || n < 0 || n > i.cantidadDespachada
                            ? 'Ingrese de 0 a ${i.cantidadDespachada}.'
                            : null;
                      },
                    ),
                  ],
                ),
              StockSeccion(
                titulo: 'Describe la diferencia',
                icono: Icons.edit_note_rounded,
                children: [
                  TextFormField(
                    controller: _motivo,
                    enabled: !_guardando,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Justificación del reporte',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Escribe una justificación.'
                        : null,
                  ),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: stockRojo)),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: _guardando ? null : _enviar,
              icon: const Icon(Icons.preview_outlined),
              label: Text(_guardando ? 'Guardando…' : 'Revisar reporte'),
            ),
          ),
        ),
      ),
    ),
  );
  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    if (widget.pedido.items.any((i) {
      final n = int.tryParse(_cantidades[i.id]!.text);
      return n == null || n < 0 || n > i.cantidadDespachada;
    })) {
      setState(
        () => _error = 'Revisa todas las cantidades antes de continuar.',
      );
      return;
    }
    final cantidades = {
      for (final e in _cantidades.entries) e.key: int.parse(e.value.text),
    };
    if (!widget.pedido.items.any(
      (i) => cantidades[i.id]! < i.cantidadDespachada,
    )) {
      setState(() => _error = 'El conteo es conforme. Usa Aceptar conforme.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: temaStock(ctx),
        child: AlertDialog(
          title: const Text('Preconfirmación del reporte'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final i in widget.pedido.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '${i.nombreMedicamento}\nDespachado: ${i.cantidadDespachada} · Contado: ${cantidades[i.id]}\nFaltante: ${i.cantidadDespachada - cantidades[i.id]!}',
                      style: const TextStyle(height: 1.6),
                    ),
                  ),
                Text('Motivo: ${_motivo.text.trim()}'),
                const SizedBox(height: 16),
                const Text(
                  'El stock no cambiará. Podrás seguir o cancelar el reporte en Mis reportes.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Corregir'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar reporte'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final firma = '$cantidades|${_motivo.text.trim()}';
    if (_firma != firma) {
      _firma = firma;
      _token = generarSolicitudId();
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repo.gestionar(
        pedidoId: widget.pedido.id,
        accion: 'REPORTAR',
        motivo: _motivo.text.trim(),
        operacionId: _token,
        cantidades: cantidades,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = _errorDiferencia(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

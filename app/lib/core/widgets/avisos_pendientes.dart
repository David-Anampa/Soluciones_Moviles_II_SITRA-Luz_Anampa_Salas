import 'menu_modulos.dart';
import 'tarjeta_pendientes_area.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GrupoPendientes {
  final String tipo, areaCodigo, areaNombre, destinoNombre;
  final int cantidad, urgentes;
  GrupoPendientes({
    required this.tipo,
    required this.areaCodigo,
    required this.areaNombre,
    this.destinoNombre = '',
    this.cantidad = 0,
    this.urgentes = 0,
  });
  int get normales => cantidad > urgentes ? cantidad - urgentes : 0;
  GrupoPendientes.fromMap(Map<String, dynamic> m)
    : tipo = m['tipo'] as String,
      areaCodigo = m['area_codigo'] as String,
      areaNombre = m['area_nombre'] as String,
      destinoNombre = m['destino_nombre'] as String,
      cantidad = (m['cantidad'] as num).toInt(),
      urgentes = (m['urgentes'] as num).toInt();
  String get descripcion => switch (tipo) {
    'RECOJO' => 'Listas para recoger · $destinoNombre',
    'RECEPCION_ALMACEN' => 'Abastecimiento listo para recibir',
    'PEDIDO_CLINICO' => 'Pedidos por revisar',
    _ => 'Solicitudes de abastecimiento',
  };
}

/// Cantidades de trabajo pendiente, no contadores ficticios de avisos sin leer.
class AvisosPendientes extends StatefulWidget {
  final String ambito;
  final Color color;
  final Object? revision;
  final Future<void> Function(GrupoPendientes) onAbrir;
  const AvisosPendientes({
    super.key,
    required this.ambito,
    required this.color,
    this.revision,
    required this.onAbrir,
  });
  @override
  State<AvisosPendientes> createState() => _AvisosPendientesState();
}

class _AvisosPendientesState extends State<AvisosPendientes>
    with WidgetsBindingObserver {
  List<GrupoPendientes> _grupos = [];
  int _total = 0;
  bool _cargando = false, _error = false, _abriendo = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AvisosPendientes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.ambito != widget.ambito) {
      _cargar();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _cargar();
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    try {
      final farmacia = widget.ambito == 'FARMACIA';
      final consultas = await Future.wait<Object>([
        Supabase.instance.client.rpc(
          'resumen_avisos_home',
          params: {'p_ambito': widget.ambito},
        ),
        if (farmacia)
          Supabase.instance.client
              .from('areas')
              .select('codigo,nombre')
              .eq('activo', true)
              .neq('codigo', 'FARMACIA')
              .neq('codigo', 'ALMACEN')
              .order('nombre'),
      ]);
      final result = Map<String, dynamic>.from(consultas[0] as Map);
      final grupos = (result['grupos'] as List)
          .map(
            (m) => GrupoPendientes.fromMap(Map<String, dynamic>.from(m as Map)),
          )
          .toList();
      if (farmacia) {
        for (final area in consultas[1] as List) {
          if (!grupos.any(
            (g) => g.tipo == 'PEDIDO_CLINICO' && g.areaCodigo == area['codigo'],
          )) {
            grupos.add(
              GrupoPendientes(
                tipo: 'PEDIDO_CLINICO',
                areaCodigo: area['codigo'] as String,
                areaNombre: area['nombre'] as String,
              ),
            );
          }
        }
        grupos.sort((a, b) {
          final urgentes = b.urgentes.compareTo(a.urgentes);
          if (urgentes != 0) return urgentes;
          final cantidad = b.cantidad.compareTo(a.cantidad);
          return cantidad != 0
              ? cantidad
              : a.areaNombre.compareTo(b.areaNombre);
        });
      }
      if (!mounted) return;
      setState(() {
        _total = (result['total'] as num).toInt();
        _grupos = grupos;
        _error = false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrir(GrupoPendientes grupo) async {
    if (_abriendo) return;
    setState(() => _abriendo = true);
    try {
      await widget.onAbrir(grupo);
    } finally {
      if (mounted) {
        setState(() => _abriendo = false);
        await _cargar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmacia = widget.ambito == 'FARMACIA';
    if (_total == 0 && !_error && (!farmacia || _grupos.isEmpty)) {
      return const SizedBox.shrink();
    }
    final areas = _grupos.where((g) => g.tipo == 'PEDIDO_CLINICO').toList();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.color.withValues(alpha: .22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: widget.color,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.ambito == 'ENFERMERIA'
                        ? 'Pedidos listos para recoger'
                        : 'Solicitudes pendientes',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF262630),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar pendientes',
                  onPressed: _cargando ? null : _cargar,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            ),
            if (_total > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Text(
                  '$_total ${_total == 1 ? "solicitud en total" : "solicitudes en total"}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.color,
                  ),
                ),
              ),
            if (_error)
              TextButton.icon(
                onPressed: _cargando ? null : _cargar,
                icon: const Icon(Icons.sync_problem_rounded),
                label: Text(
                  _total > 0
                      ? 'Datos previos · Volver a actualizar'
                      : 'No se pudieron consultar pendientes. Reintentar',
                ),
              ),
            if (farmacia && areas.isNotEmpty) ...[
              const SizedBox(height: 12),
              CuadriculaPanel(
                esResumen: true,
                children: [
                  for (final grupo in areas)
                    TarjetaPendientesArea(
                      codigo: grupo.areaCodigo,
                      nombre: grupo.areaNombre,
                      urgentes: grupo.urgentes,
                      normales: grupo.normales,
                      color: widget.color,
                      onAbrir: _abriendo || grupo.cantidad == 0
                          ? null
                          : () => _abrir(grupo),
                    ),
                ],
              ),
            ],
            for (final grupo in _grupos.where(
              (g) => !farmacia || g.tipo != 'PEDIDO_CLINICO',
            ))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 1, color: Color(0xFFE8E9EF)),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            grupo.areaNombre,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: widget.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${grupo.cantidad}',
                            semanticsLabel: '${grupo.cantidad} solicitudes',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: widget.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      grupo.descripcion,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF626675),
                      ),
                    ),
                    if (grupo.urgentes > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${grupo.urgentes} ${grupo.urgentes == 1 ? "urgente" : "urgentes"}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB3261E),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _abriendo ? null : () => _abrir(grupo),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                        label: Text(
                          grupo.tipo == 'RECOJO' ||
                                  grupo.tipo == 'RECEPCION_ALMACEN'
                              ? 'Revisar recepción'
                              : 'Ver solicitudes',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: widget.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

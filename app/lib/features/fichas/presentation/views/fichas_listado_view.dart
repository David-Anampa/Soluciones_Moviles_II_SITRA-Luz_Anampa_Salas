import '../../../../core/theme/tema_pedidos.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/tema_area.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../data/repositories/fichas_repository.dart';
import '../../domain/entities/ficha_catalogo_entities.dart';
import 'ficha_detalle_atencion_view.dart';
import 'registro_ficha_view.dart';

/// Vista de listado de fichas de pedido con filtros dinámicos, contadores operativos
/// por estado y acceso directo al detalle/atención transaccional (HU-006 / HU-007).
class FichasListadoView extends StatefulWidget {
  final String? areaInicial;
  final String? estadoInicial;

  const FichasListadoView({super.key, this.areaInicial, this.estadoInicial});

  @override
  State<FichasListadoView> createState() => _FichasListadoViewState();
}

class _FichasListadoViewState extends State<FichasListadoView> {
  final FichasRepository _repository = FichasRepository();
  final TextEditingController _busquedaCtrl = TextEditingController();

  ContextoRegistroFicha? _contexto;
  List<FichaRegistrada> _todasDelContexto = const [];
  List<FichaRegistrada> _fichasFiltradas = const [];
  late FiltrosListadoFichas _filtros;

  bool _cargando = true;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _filtros = FiltrosListadoFichas(
      area:
          (widget.areaInicial != null && widget.areaInicial!.trim().isNotEmpty)
          ? widget.areaInicial!.trim().toUpperCase()
          : 'TODAS',
      estado:
          (widget.estadoInicial != null &&
              widget.estadoInicial!.trim().isNotEmpty)
          ? widget.estadoInicial!.trim().toUpperCase()
          : 'TODOS',
    );
    _cargarListadoInicial();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  String get _rolUsuario => (_contexto?.rol ?? '').toUpperCase();

  bool get _puedeRegistrarNuevaFicha =>
      _rolUsuario == 'ENFERMERIA' ||
      _rolUsuario == 'FARMACIA' ||
      _rolUsuario == 'ADMINISTRADOR';

  Future<void> _cargarListadoInicial() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final ctx = await _repository.obtenerContexto();
      String areaAjustada = _filtros.area;
      if (ctx.rol.toUpperCase() == 'ENFERMERIA' &&
          ctx.areas.length == 1 &&
          areaAjustada == 'TODAS') {
        areaAjustada = ctx.areas.first.codigo;
      } else if (areaAjustada != 'TODAS' &&
          !ctx.areas.any((a) => a.codigo == areaAjustada)) {
        areaAjustada = 'TODAS';
      }

      final filtrosBase = FiltrosListadoFichas(area: areaAjustada);
      final base = await _repository.listarFichasConFiltros(
        filtros: filtrosBase,
        limite: 120,
      );
      final filtrosActivos = _filtros.copyWith(area: areaAjustada);
      final filtradas = filtrosActivos.tieneFiltrosActivos
          ? await _repository.listarFichasConFiltros(
              filtros: filtrosActivos,
              limite: 120,
            )
          : base;

      if (!mounted) return;
      setState(() {
        _contexto = ctx;
        _filtros = filtrosActivos;
        _todasDelContexto = base;
        _fichasFiltradas = filtradas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = FichasRepository.mensajeError(
          e,
          'No se pudo cargar el listado de fichas.',
        );
        _cargando = false;
      });
    }
  }

  Future<void> _aplicarFiltros(FiltrosListadoFichas nuevosFiltros) async {
    setState(() {
      _filtros = nuevosFiltros;
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final resultados = await Future.wait([
        _repository.listarFichasConFiltros(
          filtros: FiltrosListadoFichas(area: nuevosFiltros.area),
          limite: 120,
        ),
        _repository.listarFichasConFiltros(filtros: nuevosFiltros, limite: 120),
      ]);
      if (!mounted) return;
      setState(() {
        _todasDelContexto = resultados[0];
        _fichasFiltradas = resultados[1];
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = FichasRepository.mensajeError(e);
        _cargando = false;
      });
    }
  }

  void _limpiarFiltros() {
    _busquedaCtrl.clear();
    final areaInicial =
        (_rolUsuario == 'ENFERMERIA' && (_contexto?.areas.length ?? 0) == 1)
        ? _contexto!.areas.first.codigo
        : 'TODAS';
    _aplicarFiltros(FiltrosListadoFichas(area: areaInicial));
  }

  Future<void> _abrirDetalleFicha(FichaRegistrada ficha) async {
    final huboCambios = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            FichaDetalleAtencionView(fichaId: ficha.id, fichaInicial: ficha),
      ),
    );
    if (huboCambios == true && mounted) {
      await _aplicarFiltros(_filtros);
    }
  }

  Future<void> _abrirRegistroNuevaFicha() async {
    final areaSugerida = _filtros.area != 'TODAS'
        ? _filtros.area
        : widget.areaInicial;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RegistroFichaView(areaInicial: areaSugerida),
      ),
    );
    if (mounted) {
      await _aplicarFiltros(_filtros);
    }
  }

  int _contarPorEstado(String estado) =>
      _todasDelContexto.where((f) => f.estado == estado).length;

  String _formatearFechaHora(DateTime fecha) {
    final f = fecha.toLocal();
    final d = f.day.toString().padLeft(2, '0');
    final m = f.month.toString().padLeft(2, '0');
    final hh = f.hour.toString().padLeft(2, '0');
    final mm = f.minute.toString().padLeft(2, '0');
    return '$d/$m/${f.year} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TemaPedidos.aplicar(context, TemaPedidos.rolActual(context)),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          backgroundColor: TemaPedidos.colorRol(TemaPedidos.rolActual(context)),
          foregroundColor: Colors.white,
          title: const Text(
            'Atender pedidos de áreas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'Actualizar listado',
              onPressed: _cargando ? null : () => _aplicarFiltros(_filtros),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: _puedeRegistrarNuevaFicha
            ? FloatingActionButton.extended(
                onPressed: _cargando ? null : _abrirRegistroNuevaFicha,
                backgroundColor: TemaPedidos.colorRol(
                  TemaPedidos.rolActual(context),
                ),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.post_add_rounded),
                label: const Text('Registrar pedido'),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: () => _aplicarFiltros(_filtros),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ContenidoAdaptable(
              anchoMaximo: 1120,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FranjaPedidos(
                    titulo: 'Estado de pedidos',
                    icono: Icons.inbox_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildResumenEstados(),
                  const SizedBox(height: 14),
                  _buildPanelFiltros(),
                  const SizedBox(height: 14),
                  if (_errorCarga != null) ...[
                    MensajesApp.nota(_errorCarga!, tipo: TipoMensaje.error),
                    const SizedBox(height: 14),
                  ],
                  if (_cargando)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_fichasFiltradas.isEmpty)
                    _buildEstadoVacio()
                  else
                    _buildListaTarjetasFichas(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResumenEstados() {
    final tarjetas = [
      (
        'TODOS',
        'Total en área',
        _todasDelContexto.length,
        TemaPedidos.colorRol(TemaPedidos.rolActual(context)),
        TemaPedidos.colorRol(
          TemaPedidos.rolActual(context),
        ).withValues(alpha: .10),
        Icons.folder_copy_outlined,
      ),
      (
        'SOLICITADO',
        'Pendientes',
        _contarPorEstado('SOLICITADO'),
        TemaPedidos.colorRol(TemaPedidos.rolActual(context)),
        TemaPedidos.colorRol(
          TemaPedidos.rolActual(context),
        ).withValues(alpha: .10),
        Icons.mark_email_unread_outlined,
      ),
      (
        'EN_PREPARACION',
        'En preparación',
        _contarPorEstado('EN_PREPARACION'),
        TemaPedidos.colorRol(TemaPedidos.rolActual(context)),
        TemaPedidos.colorRol(
          TemaPedidos.rolActual(context),
        ).withValues(alpha: .10),
        Icons.inventory_2_outlined,
      ),
      (
        'LISTO_PARA_RECOJO',
        'Listas recojo',
        _contarPorEstado('LISTO_PARA_RECOJO'),
        TemaPedidos.colorRol(TemaPedidos.rolActual(context)),
        TemaPedidos.colorRol(
          TemaPedidos.rolActual(context),
        ).withValues(alpha: .10),
        Icons.fact_check_outlined,
      ),
      (
        'ENTREGADO',
        'Entregadas',
        _contarPorEstado('ENTREGADO'),
        TemaPedidos.colorRol(TemaPedidos.rolActual(context)),
        TemaPedidos.colorRol(
          TemaPedidos.rolActual(context),
        ).withValues(alpha: .10),
        Icons.verified_outlined,
      ),
      (
        'CANCELADO',
        'Anuladas',
        _contarPorEstado('CANCELADO'),
        const Color(0xFFB71C1C),
        const Color(0xFFFFEBEE),
        Icons.cancel_outlined,
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tarjetas.map((t) {
        final seleccionado = _filtros.estado == t.$1;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _aplicarFiltros(_filtros.copyWith(estado: t.$1)),
          child: Container(
            constraints: const BoxConstraints(minWidth: 145),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: seleccionado ? t.$5 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: seleccionado ? t.$4 : const Color(0xFFE2E8F0),
                width: seleccionado ? 1.8 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(t.$6, color: t.$4, size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t.$3}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: t.$4,
                      ),
                    ),
                    Text(
                      t.$2,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPanelFiltros() {
    final areas = {
      for (final area in _contexto?.areas ?? const <AreaFicha>[])
        if (area.codigo != 'TODAS') area.codigo: area,
    }.values.toList();
    // El filtro inicial puede llegar desde un aviso antes de cargar el catálogo.
    // Conservarlo para la consulta, pero mostrar solo valores existentes en el menú.
    final areaVisible = areas.any((a) => a.codigo == _filtros.area)
        ? _filtros.area
        : 'TODAS';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FranjaPedidos(
            titulo: 'Buscar pedidos',
            icono: Icons.filter_alt_outlined,
          ),
          if (_filtros.tieneFiltrosActivos)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _limpiarFiltros,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Limpiar filtros'),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _busquedaCtrl,
                  onSubmitted: (val) =>
                      _aplicarFiltros(_filtros.copyWith(busqueda: val)),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText:
                        'Buscar por N° ficha, paciente, madre/RN, médico, receptor o kit...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _busquedaCtrl.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _busquedaCtrl.clear();
                              _aplicarFiltros(_filtros.copyWith(busqueda: ''));
                            },
                            icon: const Icon(Icons.clear_rounded),
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _aplicarFiltros(
                  _filtros.copyWith(busqueda: _busquedaCtrl.text),
                ),
                child: const Text('Buscar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('filtro-area-$areaVisible'),
                  initialValue: areaVisible,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Área clínica',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'TODAS',
                      child: Text('Todas las áreas autorizadas'),
                    ),
                    ...areas.map(
                      (a) => DropdownMenuItem(
                        value: a.codigo,
                        child: Text(a.nombre, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: _contexto == null || _cargando
                      ? null
                      : (val) {
                          if (val != null) {
                            _aplicarFiltros(_filtros.copyWith(area: val));
                          }
                        },
                ),
              ),
              SizedBox(
                width: 195,
                child: DropdownButtonFormField<String>(
                  initialValue: _filtros.estado,
                  key: ValueKey('filtro-estado-${_filtros.estado}'),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'TODOS',
                      child: Text('Todos los estados'),
                    ),
                    DropdownMenuItem(
                      value: 'SOLICITADO',
                      child: Text('Solicitado'),
                    ),
                    DropdownMenuItem(
                      value: 'EN_PREPARACION',
                      child: Text('En preparación'),
                    ),
                    DropdownMenuItem(
                      value: 'LISTO_PARA_RECOJO',
                      child: Text('Listo para recojo'),
                    ),
                    DropdownMenuItem(
                      value: 'ENTREGADO',
                      child: Text('Entregado'),
                    ),
                    DropdownMenuItem(
                      value: 'CANCELADO',
                      child: Text('Anulado'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      _aplicarFiltros(_filtros.copyWith(estado: val));
                    }
                  },
                ),
              ),
              SizedBox(
                width: 185,
                child: DropdownButtonFormField<String>(
                  initialValue: _filtros.tipoFicha,
                  key: ValueKey('filtro-tipo-${_filtros.tipoFicha}'),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Formato de ficha',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'TODOS',
                      child: Text('General y Neonatología'),
                    ),
                    DropdownMenuItem(
                      value: 'GENERAL',
                      child: Text('Ficha General'),
                    ),
                    DropdownMenuItem(
                      value: 'NEONATOLOGIA',
                      child: Text('Ficha Neonatología'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      _aplicarFiltros(_filtros.copyWith(tipoFicha: val));
                    }
                  },
                ),
              ),
              SizedBox(
                width: 165,
                child: DropdownButtonFormField<String>(
                  initialValue: _filtros.prioridad,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Prioridad',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'TODAS', child: Text('Todas')),
                    DropdownMenuItem(value: 'URGENTE', child: Text('Urgente')),
                    DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      _aplicarFiltros(_filtros.copyWith(prioridad: val));
                    }
                  },
                ),
              ),
              SizedBox(
                width: 155,
                child: DropdownButtonFormField<String>(
                  initialValue: _filtros.turno,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Turno',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'TODOS', child: Text('Todos')),
                    DropdownMenuItem(value: 'DIA', child: Text('Día')),
                    DropdownMenuItem(value: 'TARDE', child: Text('Tarde')),
                    DropdownMenuItem(value: 'NOCHE', child: Text('Noche')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      _aplicarFiltros(_filtros.copyWith(turno: val));
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 46, color: Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          const Text(
            'No se encontraron fichas con los filtros seleccionados.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Puedes limpiar los filtros o registrar una nueva ficha clínica desde el botón superior.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              if (_filtros.tieneFiltrosActivos)
                OutlinedButton.icon(
                  onPressed: _limpiarFiltros,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('Mostrar todas'),
                ),
              if (_puedeRegistrarNuevaFicha)
                FilledButton.icon(
                  onPressed: _abrirRegistroNuevaFicha,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Registrar nueva ficha'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListaTarjetasFichas() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _fichasFiltradas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final f = _fichasFiltradas[index];
        final tema = TemaArea.desde(f.areaTemaColor);
        return _TarjetaFichaItem(
          ficha: f,
          tema: tema,
          rolUsuario: _rolUsuario,
          fechaTexto: _formatearFechaHora(f.fechaCreacion),
          onAbrirDetalle: () => _abrirDetalleFicha(f),
        );
      },
    );
  }
}

class _TarjetaFichaItem extends StatelessWidget {
  final FichaRegistrada ficha;
  final TemaArea tema;
  final String rolUsuario;
  final String fechaTexto;
  final VoidCallback onAbrirDetalle;

  const _TarjetaFichaItem({
    required this.ficha,
    required this.tema,
    required this.rolUsuario,
    required this.fechaTexto,
    required this.onAbrirDetalle,
  });

  Widget _datoPedido(IconData icono, String texto) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF475569),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final (colorEstado, fondoEstado) = switch (ficha.estado) {
      'SOLICITADO' => (
        Theme.of(context).colorScheme.primary,
        Theme.of(context).colorScheme.primary.withValues(alpha: .10),
      ),
      'EN_PREPARACION' => (const Color(0xFFE65100), const Color(0xFFFFF3E0)),
      'LISTO_PARA_RECOJO' => (const Color(0xFF4A148C), const Color(0xFFF3E5F5)),
      'ENTREGADO' => (const Color(0xFF1B5E20), const Color(0xFFE8F5E9)),
      'CANCELADO' => (const Color(0xFFB71C1C), const Color(0xFFFFEBEE)),
      _ => (const Color(0xFF334155), const Color(0xFFF1F5F9)),
    };

    final etiquetaAccion = switch ((rolUsuario, ficha.estado)) {
      ('FARMACIA' || 'ADMINISTRADOR', 'SOLICITADO') => 'Revisar pedido',
      ('FARMACIA' || 'ADMINISTRADOR', 'EN_PREPARACION') => 'Continuar despacho',
      (_, 'LISTO_PARA_RECOJO') => 'Confirmar entrega',
      _ => 'Ver detalle e historial',
    };

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onAbrirDetalle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ficha.esUrgente
                ? const Color(0xFFC62828)
                : const Color(0xFFE2E8F0),
            width: ficha.esUrgente ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tema.principal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ficha.numeroFicha,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tema.suave,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ficha.areaNombre,
                        style: TextStyle(
                          color: tema.principal,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (ficha.esUrgente)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC62828),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'URGENTE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        Text(
                          fechaTexto,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: fondoEstado,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    ficha.etiquetaEstado.toUpperCase(),
                    style: TextStyle(
                      color: colorEstado,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              ficha.esNeonatologia
                  ? 'RN: ${ficha.recienNacidoApellidos ?? "-"} (Madre: ${ficha.madreNombre ?? "-"} · Hab: ${ficha.habitacion ?? "-"})'
                  : 'Paciente: ${ficha.pacienteNombre} (${ficha.procedencia ?? "-"})',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            _datoPedido(
              Icons.person_outline_rounded,
              'Solicitante: ${ficha.solicitadoPorNombre ?? "-"}',
            ),
            _datoPedido(
              Icons.medical_services_outlined,
              'Médico: ${ficha.doctorNombre ?? "-"}',
            ),
            _datoPedido(
              Icons.badge_outlined,
              'Receptor: ${ficha.recibidoPor ?? "-"}',
            ),
            _datoPedido(
              Icons.account_balance_wallet_outlined,
              'Financiamiento: ${ficha.financiamientoNombreAplicado ?? ficha.tipoAtencion}',
            ),
            if (ficha.kitNombre != null && ficha.kitNombre!.isNotEmpty)
              _datoPedido(
                Icons.inventory_2_outlined,
                'Kit: ${ficha.kitNombre}',
              ),
            if (ficha.estado == 'CANCELADO' &&
                (ficha.motivoAnulacion ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Motivo de anulación: ${ficha.motivoAnulacion}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB71C1C),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _ChipResumen(
                      icono: Icons.medication_outlined,
                      texto: '${ficha.medicamentos.length} med.',
                    ),
                    _ChipResumen(
                      icono: Icons.medical_services_outlined,
                      texto: '${ficha.dispositivosMedicos.length} disp.',
                    ),
                    _ChipResumen(
                      icono: Icons.inventory_rounded,
                      texto:
                          'Despachado: ${ficha.totalUnidadesEntregadas}/${ficha.totalUnidadesSolicitadas} und.',
                    ),
                    if (ficha.montoTotalSolicitado > 0)
                      _ChipResumen(
                        icono: Icons.payments_outlined,
                        texto:
                            'S/ ${(ficha.estado == 'SOLICITADO' ? ficha.montoTotalSolicitado : ficha.montoTotalEntregado).toStringAsFixed(2)}',
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: FilledButton.icon(
                    onPressed: onAbrirDetalle,
                    icon: const Icon(Icons.fact_check_outlined, size: 20),
                    label: Text(etiquetaAccion),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipResumen extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _ChipResumen({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: const Color(0xFF475569)),
          const SizedBox(width: 4),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

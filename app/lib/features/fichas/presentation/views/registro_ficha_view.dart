import '../../../../core/theme/tema_pedidos.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/tema_area.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../../../core/widgets/selector_catalogo.dart';
import '../../../administracion/presentation/widgets/catalogo_estilo.dart';
import '../../../almacen/domain/solicitud_id.dart';
import '../../data/repositories/fichas_repository.dart';
import '../../domain/entities/ficha_catalogo_entities.dart';
import '../../domain/ficha_borrador.dart';
import '../../domain/ficha_validadores.dart';
import '../widgets/selector_item_ficha_dialog.dart';
import '../widgets/selector_kit_ficha_dialog.dart';
import 'ficha_detalle_atencion_view.dart';

/// Vista dinámica única para registrar y editar fichas de pedido (General y Neonatología),
/// seleccionar productos con stock real en Farmacia y aplicar kits como copia editable
/// (HU-003, HU-004 y HU-005).
class RegistroFichaView extends StatefulWidget {
  final String? areaInicial;
  final FichasRepository? repositorio;

  const RegistroFichaView({super.key, this.areaInicial, this.repositorio});

  @override
  State<RegistroFichaView> createState() => _RegistroFichaViewState();
}

class _RegistroFichaViewState extends State<RegistroFichaView> {
  late final FichasRepository _repository;

  final TextEditingController _pacienteCtrl = TextEditingController();
  final TextEditingController _procedenciaDetalleCtrl = TextEditingController();
  final TextEditingController _diagnosticoCtrl = TextEditingController();
  final TextEditingController _madreCtrl = TextEditingController();
  final TextEditingController _habitacionCtrl = TextEditingController();
  final TextEditingController _rnApellidosCtrl = TextEditingController();
  final TextEditingController _observacionesCtrl = TextEditingController();

  ContextoRegistroFicha? _contexto;
  List<MedicamentoStockFicha> _catalogoStock = const [];
  List<FichaRegistrada> _fichasRecientes = const [];

  FichaBorrador _borrador = FichaBorrador();
  bool _cargando = true;
  bool _guardando = false;
  bool _guardandoProcedencia = false;
  List<ProcedenciaFicha> _procedencias = List.of(ProcedenciaFicha.iniciales);
  String? _errorCarga;
  String? _solicitudIdPendiente;

  @override
  void initState() {
    super.initState();
    _repository = widget.repositorio ?? FichasRepository();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _pacienteCtrl.dispose();
    _procedenciaDetalleCtrl.dispose();
    _diagnosticoCtrl.dispose();
    _madreCtrl.dispose();
    _habitacionCtrl.dispose();
    _rnApellidosCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  TemaArea get _temaActual {
    final rol = TemaPedidos.rolActual(context);
    final color = TemaPedidos.colorRol(rol);
    // La identidad visual del formulario no depende del área que solicita.
    return TemaArea(rol, rol, color, Color.lerp(color, Colors.white, .93)!);
  }

  void _seleccionarTipoFicha(bool neonatal) {
    final destino = _contexto?.areas
        .where((a) => a.esNeonatologia == neonatal)
        .firstOrNull;
    if (destino != null) _cambiarArea(destino.codigo);
  }

  AreaFicha? get _areaSeleccionada {
    final areas = _contexto?.areas ?? const [];
    for (final a in areas) {
      if (a.codigo == _borrador.areaOrigen) return a;
    }
    return null;
  }

  FinanciamientoFicha? get _financiamientoSeleccionado {
    final lista = _contexto?.financiamientos ?? const [];
    for (final f in lista) {
      if (f.id == _borrador.financiamientoId) return f;
    }
    return null;
  }

  Map<String, int> get _mapaStockFarmacia => {
    for (final m in _catalogoStock) m.id: m.farmaciaDisponible,
  };

  String get _procedenciaSeleccionada {
    if (_borrador.procedencia != 'OTRO') return _borrador.procedencia;
    final normalizado = normalizarEtiquetaCatalogo(
      _borrador.procedenciaDetalle,
    );
    return _procedencias
            .where((p) => normalizarEtiquetaCatalogo(p.nombre) == normalizado)
            .firstOrNull
            ?.codigo ??
        'OTRO';
  }

  void _elegirProcedencia(ProcedenciaFicha? p) {
    final base =
        p != null &&
        (p.codigo == 'EMERGENCIA' || p.codigo == 'HOSPITALIZACION');
    final detalle = p != null && !base ? p.nombre : '';
    _procedenciaDetalleCtrl.text = detalle;
    _solicitudIdPendiente = null;
    _borrador = _borrador.copyWith(
      procedencia: base ? p.codigo : 'OTRO',
      procedenciaDetalle: detalle,
    );
  }

  Future<void> _guardarProcedencia() async {
    if (_guardandoProcedencia || _guardando) return;
    final error = FichaValidadores.validarProcedenciaDetalle(
      'OTRO',
      _procedenciaDetalleCtrl.text,
    );
    if (error != null) {
      MensajesApp.mostrar(context, error, tipo: TipoMensaje.advertencia);
      return;
    }
    final borradorAnterior = _borrador;
    setState(() => _guardandoProcedencia = true);
    try {
      final p = await _repository.registrarProcedencia(
        _procedenciaDetalleCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        if (!_procedencias.any((o) => o.codigo == p.codigo)) {
          _procedencias.add(p);
          _procedencias.sort((a, b) => a.nombre.compareTo(b.nombre));
        }
        if (identical(_borrador, borradorAnterior)) _elegirProcedencia(p);
      });
      MensajesApp.mostrar(
        context,
        'Procedencia disponible para todos los usuarios.',
      );
    } catch (e) {
      if (mounted) {
        MensajesApp.mostrar(
          context,
          'No se pudo guardar la procedencia: $e',
          tipo: TipoMensaje.error,
        );
      }
    } finally {
      if (mounted) setState(() => _guardandoProcedencia = false);
    }
  }

  Future<void> _cargarDatosIniciales({String? areaPreferida}) async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final resultados = await Future.wait([
        _repository.obtenerContexto(),
        _repository.buscarCatalogoConStock(limite: 300),
      ]);
      final ctx = resultados[0] as ContextoRegistroFicha;
      final stock = resultados[1] as List<MedicamentoStockFicha>;

      String areaCodigo =
          areaPreferida ??
          widget.areaInicial ??
          (_borrador.areaOrigen.isNotEmpty ? _borrador.areaOrigen : '');
      if (areaCodigo.isEmpty || !ctx.areas.any((a) => a.codigo == areaCodigo)) {
        areaCodigo = ctx.areas.isNotEmpty ? ctx.areas.first.codigo : '';
      }

      final areaObj = ctx.areas
          .where((a) => a.codigo == areaCodigo)
          .firstOrNull;
      final tipoFichaInicial = areaObj != null && areaObj.esNeonatologia
          ? 'NEONATOLOGIA'
          : 'GENERAL';

      final finParticular = ctx
          .financiamientosPorTipo('PARTICULAR')
          .firstOrNull;

      final receptoresArea = ctx.receptoresParaArea(areaCodigo);
      ReceptorFicha? receptorDefecto;
      for (final r in receptoresArea) {
        if (r.id == ctx.usuarioId) {
          receptorDefecto = r;
          break;
        }
      }
      receptorDefecto ??= receptoresArea.firstOrNull;

      final doctorDefecto = ctx.doctoresParaArea(areaCodigo).firstOrNull;

      final recientes = areaCodigo.isEmpty
          ? const <FichaRegistrada>[]
          : await _repository.listarFichasRecientes(area: areaCodigo);

      if (!mounted) return;
      setState(() {
        _contexto = ctx;
        _procedencias = List.of(ctx.procedencias);
        _catalogoStock = stock;
        _fichasRecientes = recientes;
        if (_borrador.id == null && _borrador.items.isEmpty) {
          _borrador = FichaBorrador(
            tipoFicha: tipoFichaInicial,
            areaOrigen: areaCodigo,
            turno: _turnoSegunHoraActual(),
            prioridad: 'NORMAL',
            tipoAtencion: 'PARTICULAR',
            financiamientoId: finParticular?.id,
            doctorId: doctorDefecto?.id,
            doctorNombre: doctorDefecto?.nombre ?? '',
            receptorId: receptorDefecto?.id,
            recibidoPor: receptorDefecto?.nombre ?? '',
          );
        }
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

  String _turnoSegunHoraActual() {
    final h = DateTime.now().hour;
    if (h >= 7 && h < 14) return 'DIA';
    if (h >= 14 && h < 20) return 'TARDE';
    return 'NOCHE';
  }

  Future<void> _cambiarArea(String nuevoCodigo) async {
    final ctx = _contexto;
    if (ctx == null || nuevoCodigo == _borrador.areaOrigen) return;
    final areaObj = ctx.areas.where((a) => a.codigo == nuevoCodigo).firstOrNull;
    final receptores = ctx.receptoresParaArea(nuevoCodigo);
    ReceptorFicha? nuevoReceptor;
    for (final r in receptores) {
      if (r.id == ctx.usuarioId) {
        nuevoReceptor = r;
        break;
      }
    }
    nuevoReceptor ??= receptores.firstOrNull;

    setState(() {
      _solicitudIdPendiente = null;
      _borrador = _borrador.copyWith(
        doctorId:
            ctx
                .doctoresParaArea(nuevoCodigo)
                .any((d) => d.id == _borrador.doctorId)
            ? _borrador.doctorId
            : null,
        limpiarDoctorId: !ctx
            .doctoresParaArea(nuevoCodigo)
            .any((d) => d.id == _borrador.doctorId),
        doctorNombre:
            ctx
                .doctoresParaArea(nuevoCodigo)
                .any((d) => d.id == _borrador.doctorId)
            ? _borrador.doctorNombre
            : '',
        areaOrigen: nuevoCodigo,
        tipoFicha: areaObj != null && areaObj.esNeonatologia
            ? 'NEONATOLOGIA'
            : 'GENERAL',
        receptorId: nuevoReceptor?.id,
        limpiarReceptorId: nuevoReceptor == null,
        recibidoPor: nuevoReceptor?.nombre ?? '',
        limpiarKit: _borrador.kitId != null,
      );
    });

    try {
      final recientes = await _repository.listarFichasRecientes(
        area: nuevoCodigo,
      );
      if (mounted) {
        setState(() => _fichasRecientes = recientes);
      }
    } catch (_) {}
  }

  void _cambiarTipoAtencion(String nuevoTipo) {
    final ctx = _contexto;
    if (ctx == null) return;
    final opciones = ctx.financiamientosPorTipo(nuevoTipo);
    setState(() {
      _solicitudIdPendiente = null;
      _borrador = _borrador.copyWith(
        tipoAtencion: nuevoTipo,
        financiamientoId: opciones.firstOrNull?.id,
        limpiarFinanciamientoId: opciones.isEmpty,
      );
    });
  }

  Future<void> _abrirSelectorItem(String categoriaInicial) async {
    try {
      final fresco = await _repository.buscarCatalogoConStock(limite: 300);
      if (mounted) {
        setState(() => _catalogoStock = fresco);
      }
    } catch (_) {}
    if (!mounted) return;

    final nuevoItem = await showDialog<FichaItemBorrador>(
      context: context,
      builder: (_) => SelectorItemFichaDialog(
        catalogo: _catalogoStock,
        categoriaInicial: categoriaInicial,
        idsYaSeleccionados: _borrador.items.map((i) => i.medicamentoId).toSet(),
        tema: _temaActual,
      ),
    );
    if (nuevoItem == null || !mounted) return;
    setState(() {
      _solicitudIdPendiente = null;
      _borrador = _borrador.agregarOActualizarItem(nuevoItem);
    });
    MensajesApp.mostrar(
      context,
      '"${nuevoItem.nombreComercial}" agregado a la ficha.',
      tipo: TipoMensaje.exito,
    );
  }

  Future<void> _abrirSelectorKit() async {
    final ctx = _contexto;
    if (ctx == null) return;
    final kitsArea = ctx.kitsParaArea(_borrador.areaOrigen);
    final areaNombre = _areaSeleccionada?.nombre ?? _borrador.areaOrigen;

    final resultado = await showDialog<SeleccionKitResultado>(
      context: context,
      builder: (_) => SelectorKitFichaDialog(
        kitsDisponibles: kitsArea,
        areaNombre: areaNombre,
        fichaYaTieneItems: _borrador.items.isNotEmpty,
        tema: _temaActual,
      ),
    );
    if (resultado == null || !mounted) return;
    setState(() {
      _solicitudIdPendiente = null;
      _borrador = _borrador.aplicarKit(
        resultado.kit,
        conservarExistentes: resultado.conservarExistentes,
        confirmarFaltante: resultado.confirmarFaltante,
      );
    });
    MensajesApp.mostrar(
      context,
      'Se copiaron los ítems del kit "${resultado.kit.nombre}" a la ficha. Puedes editar cantidades o agregar más productos.',
      tipo: TipoMensaje.exito,
    );
  }

  void _cargarFichaParaEdicion(FichaRegistrada ficha) {
    final borradorEdicion = FichaBorrador.desdeFicha(
      ficha,
      stockFarmaciaPorMed: _mapaStockFarmacia,
    );
    _pacienteCtrl.text = borradorEdicion.pacienteNombre;
    _procedenciaDetalleCtrl.text = borradorEdicion.procedenciaDetalle;
    _diagnosticoCtrl.text = borradorEdicion.diagnosticoMotivo;
    _madreCtrl.text = borradorEdicion.madreNombre;
    _habitacionCtrl.text = borradorEdicion.habitacion;
    _rnApellidosCtrl.text = borradorEdicion.recienNacidoApellidos;
    _observacionesCtrl.text = borradorEdicion.observaciones;

    setState(() {
      _solicitudIdPendiente = null;
      _borrador = borradorEdicion;
    });
    MensajesApp.mostrar(
      context,
      'Editando ficha ${ficha.numeroFicha}. Realiza las correcciones y presiona Guardar cambios.',
      tipo: TipoMensaje.informacion,
    );
  }

  void _limpiarFormulario() {
    final ctx = _contexto;
    if (ctx == null) return;
    _pacienteCtrl.clear();
    _procedenciaDetalleCtrl.clear();
    _diagnosticoCtrl.clear();
    _madreCtrl.clear();
    _habitacionCtrl.clear();
    _rnApellidosCtrl.clear();
    _observacionesCtrl.clear();

    final areaCodigo = _borrador.areaOrigen;
    final areaObj = ctx.areas.where((a) => a.codigo == areaCodigo).firstOrNull;
    final finParticular = ctx.financiamientosPorTipo('PARTICULAR').firstOrNull;
    final receptoresArea = ctx.receptoresParaArea(areaCodigo);
    final receptorDefecto =
        receptoresArea.where((r) => r.id == ctx.usuarioId).firstOrNull ??
        receptoresArea.firstOrNull;
    final doctorDefecto = ctx.doctoresParaArea(areaCodigo).firstOrNull;

    setState(() {
      _solicitudIdPendiente = null;
      _borrador = FichaBorrador(
        tipoFicha: areaObj != null && areaObj.esNeonatologia
            ? 'NEONATOLOGIA'
            : 'GENERAL',
        areaOrigen: areaCodigo,
        turno: _turnoSegunHoraActual(),
        prioridad: 'NORMAL',
        tipoAtencion: 'PARTICULAR',
        financiamientoId: finParticular?.id,
        doctorId: doctorDefecto?.id,
        doctorNombre: doctorDefecto?.nombre ?? '',
        receptorId: receptorDefecto?.id,
        recibidoPor: receptorDefecto?.nombre ?? '',
      );
    });
  }

  Future<void> _guardarFicha() async {
    if (_guardando || _guardandoProcedencia) return;
    final sincronizado = _borrador.copyWith(
      pacienteNombre: _pacienteCtrl.text,
      procedenciaDetalle: _procedenciaDetalleCtrl.text,
      diagnosticoMotivo: _diagnosticoCtrl.text,
      madreNombre: _madreCtrl.text,
      habitacion: _habitacionCtrl.text,
      recienNacidoApellidos: _rnApellidosCtrl.text,
      doctorNombre: _borrador.doctorNombre,
      observaciones: _observacionesCtrl.text,
    );

    final errorValidacion = FichaValidadores.validarBorrador(sincronizado);
    if (errorValidacion != null) {
      MensajesApp.mostrar(context, errorValidacion, tipo: TipoMensaje.error);
      return;
    }

    final ctx = _contexto;
    if (ctx == null ||
        !ctx
            .doctoresParaArea(sincronizado.areaOrigen)
            .any((d) => d.id == sincronizado.doctorId) ||
        !ctx
            .receptoresParaArea(sincronizado.areaOrigen)
            .any((r) => r.id == sincronizado.receptorId)) {
      MensajesApp.mostrar(
        context,
        'Selecciona un médico del catálogo y un receptor activo de esta área. Actualiza los datos si cambiaron las asignaciones.',
        tipo: TipoMensaje.error,
      );
      return;
    }

    setState(() {
      _guardando = true;
      _borrador = sincronizado;
      _solicitudIdPendiente ??= generarSolicitudId();
    });

    try {
      final esEdicion = sincronizado.id != null;
      final resultado = await _repository.guardarFichaConActualizacion(
        solicitudId: _solicitudIdPendiente!,
        borrador: sincronizado,
      );
      final guardada = resultado.ficha;
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _fichasRecientes =
            resultado.recientes ??
            [guardada, ..._fichasRecientes.where((f) => f.id != guardada.id)];
        if (resultado.catalogo != null) _catalogoStock = resultado.catalogo!;
      });
      _limpiarFormulario();
      MensajesApp.mostrar(
        context,
        resultado.actualizacionPendiente
            ? 'Ficha ${guardada.numeroFicha} ${esEdicion ? "actualizada" : "guardada y enviada a Farmacia"}. No se pudo actualizar la lista o el stock. No vuelvas a enviarla; usa Actualizar para consultar los datos.'
            : esEdicion
            ? 'Ficha ${guardada.numeroFicha} actualizada y auditada correctamente.'
            : 'Ficha ${guardada.numeroFicha} registrada y enviada a Farmacia.',
        tipo: resultado.actualizacionPendiente
            ? TipoMensaje.advertencia
            : TipoMensaje.exito,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      MensajesApp.mostrar(
        context,
        FichasRepository.mensajeError(e),
        tipo: TipoMensaje.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = _temaActual;
    return Theme(
      data: TemaPedidos.aplicar(
        context,
        TemaPedidos.rolActual(context),
        base: CatalogoEstilo.tema(context, area: tema),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          toolbarHeight: DisenoAdaptable.altoCabecera(context),
          title: Text(_borrador.id == null ? 'Nueva ficha' : 'Editar ficha'),
          actions: [
            IconButton(
              tooltip: 'Actualizar catálogo y stock en tiempo real',
              onPressed: _cargando || _guardando || _guardandoProcedencia
                  ? null
                  : () => _cargarDatosIniciales(
                      areaPreferida: _borrador.areaOrigen,
                    ),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _errorCarga != null
              ? _buildErrorEstado()
              : ContenidoAdaptable(
                  anchoMaximo: 1080,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCabeceraContexto(tema),
                        const SizedBox(height: 16),
                        _buildSeccionAreaYModalidad(tema),
                        const SizedBox(height: 16),
                        _buildSeccionDatosClinicos(tema),
                        const SizedBox(height: 16),
                        _buildSeccionResponsablesYFinanciamiento(tema),
                        const SizedBox(height: 16),
                        _buildSeccionKitEItems(tema),
                        const SizedBox(height: 20),
                        _buildBarraEnvio(),
                        if (_fichasRecientes.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _buildSeccionFichasRecientes(tema),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildErrorEstado() {
    return ContenidoAdaptable(
      anchoMaximo: 680,
      child: Center(
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE0E0E8)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MensajesApp.nota(_errorCarga!, tipo: TipoMensaje.error),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _cargarDatosIniciales,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar conexión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCabeceraContexto(TemaArea tema) {
    return Container(
      padding: EdgeInsets.all(
        DisenoAdaptable.margen(MediaQuery.sizeOf(context).width),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tema.principal.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FranjaPedidos(
            titulo: 'Tipo de pedido',
            icono: Icons.assignment_outlined,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, limites) {
              final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
              final vertical = limites.maxWidth < 240 * escala;
              final opciones = [
                _PestanaTipoFicha(
                  nombre: 'Otras áreas',
                  icono: Icons.apartment_rounded,
                  seleccionada: !_borrador.esNeonatologia,
                  habilitada:
                      _contexto?.areas.any((a) => !a.esNeonatologia) ?? false,
                  onTap: () => _seleccionarTipoFicha(false),
                ),
                _PestanaTipoFicha(
                  nombre: 'Neonatología',
                  icono: Icons.child_friendly_rounded,
                  seleccionada: _borrador.esNeonatologia,
                  habilitada:
                      _contexto?.areas.any((a) => a.esNeonatologia) ?? false,
                  onTap: () => _seleccionarTipoFicha(true),
                ),
              ];
              if (vertical) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    opciones[0],
                    const SizedBox(height: 12),
                    opciones[1],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: opciones[0]),
                    const SizedBox(width: 12),
                    Expanded(child: opciones[1]),
                  ],
                ),
              );
            },
          ),
          if (_borrador.id != null) ...[
            const SizedBox(height: 12),
            MensajesApp.nota(
              'Modo edición activo: estás corrigiendo una ficha en estado SOLICITADO. '
              'El cambio quedará registrado en la auditoría de trazabilidad.',
              tipo: TipoMensaje.advertencia,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeccionAreaYModalidad(TemaArea tema) {
    final areas = (_contexto?.areas ?? const <AreaFicha>[])
        .where((a) => a.esNeonatologia == _borrador.esNeonatologia)
        .toList();
    return _SeccionTarjeta(
      titulo: 'Área y prioridad',
      icono: Icons.local_hospital_rounded,
      tema: tema,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columnas = DisenoAdaptable.columnasFormulario(
            context,
            constraints.maxWidth,
            maxColumnas: 3,
          );
          final anchoCol = columnas == 3
              ? (constraints.maxWidth - 24) / 3
              : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!_borrador.esNeonatologia || areas.length > 1)
                SizedBox(
                  width: anchoCol,
                  child: SelectorCatalogo(
                    value: areas.any((a) => a.codigo == _borrador.areaOrigen)
                        ? _borrador.areaOrigen
                        : null,

                    decoration: const InputDecoration(
                      labelText: 'Área clínica solicitante',
                      prefixIcon: Icon(Icons.apartment_rounded),
                    ),
                    items: areas
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.codigo,
                            child: Text(
                              '${a.nombre} (${a.codigoInterno})',
                              softWrap: true,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _cambiarArea(v);
                    },
                  ),
                ),
              SizedBox(
                width: anchoCol,
                child: SelectorCatalogo(
                  value: _borrador.turno,
                  decoration: const InputDecoration(
                    labelText: 'Turno asistencial',
                    prefixIcon: Icon(Icons.schedule_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DIA', child: Text('Turno Día')),
                    DropdownMenuItem(
                      value: 'TARDE',
                      child: Text('Turno Tarde'),
                    ),
                    DropdownMenuItem(
                      value: 'NOCHE',
                      child: Text('Turno Noche'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _solicitudIdPendiente = null;
                        _borrador = _borrador.copyWith(turno: v);
                      });
                    }
                  },
                ),
              ),
              SizedBox(
                width: anchoCol,
                child: SelectorCatalogo(
                  value: _borrador.prioridad,
                  decoration: const InputDecoration(
                    labelText: 'Prioridad del pedido',
                    prefixIcon: Icon(Icons.flag_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                    DropdownMenuItem(
                      value: 'URGENTE',
                      child: Text('Urgente (Atención prioritaria)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _solicitudIdPendiente = null;
                        _borrador = _borrador.copyWith(prioridad: v);
                      });
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSeccionDatosClinicos(TemaArea tema) {
    if (_borrador.esNeonatologia) {
      return _SeccionTarjeta(
        titulo: 'Madre y recién nacido',
        icono: Icons.child_friendly_rounded,
        tema: tema,
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final dosCol =
                    DisenoAdaptable.columnasFormulario(
                      context,
                      constraints.maxWidth,
                    ) >
                    1;
                final ancho = dosCol
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: ancho,
                      child: TextField(
                        controller: _madreCtrl,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nombres y apellidos de la madre *',
                          prefixIcon: Icon(Icons.pregnant_woman_rounded),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: ancho,
                      child: TextField(
                        controller: _rnApellidosCtrl,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Apellidos del recién nacido (RN) *',
                          prefixIcon: Icon(Icons.baby_changing_station_rounded),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: ancho,
                      child: SelectorCatalogo(
                        value: _borrador.tipoParto,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de parto *',
                          prefixIcon: Icon(Icons.medical_information_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'EUTOCICO',
                            child: Text('Parto Eutócico'),
                          ),
                          DropdownMenuItem(
                            value: 'DISTOCICO',
                            child: Text('Parto Distócico'),
                          ),
                          DropdownMenuItem(
                            value: 'CESAREA',
                            child: Text('Cesárea'),
                          ),
                          DropdownMenuItem(value: 'OTRO', child: Text('Otro')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _solicitudIdPendiente = null;
                              _borrador = _borrador.copyWith(tipoParto: v);
                            });
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: ancho,
                      child: TextField(
                        controller: _habitacionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Habitación / Cuna (opcional)',
                          prefixIcon: Icon(Icons.bed_rounded),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _diagnosticoCtrl,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Diagnóstico o motivo neonatal (opcional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
          ],
        ),
      );
    }

    return _SeccionTarjeta(
      titulo: 'Datos del paciente',
      icono: Icons.person_pin_rounded,
      tema: tema,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final dosCol =
                  DisenoAdaptable.columnasFormulario(
                    context,
                    constraints.maxWidth,
                  ) >
                  1;
              final ancho = dosCol
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: ancho,
                    child: TextField(
                      controller: _pacienteCtrl,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nombres y apellidos del paciente *',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: ancho,
                    child: SelectorCatalogo(
                      value: _procedenciaSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Procedencia del paciente *',
                        prefixIcon: Icon(
                          Icons.transfer_within_a_station_rounded,
                        ),
                      ),
                      items: [
                        for (final p in _procedencias)
                          DropdownMenuItem(
                            value: p.codigo,
                            child: Text(p.nombre),
                          ),
                        const DropdownMenuItem(
                          value: 'OTRO',
                          child: Text('Otra procedencia…'),
                        ),
                      ],
                      onChanged: _guardandoProcedencia
                          ? null
                          : (v) {
                              if (v == null) return;
                              final p = _procedencias
                                  .where((p) => p.codigo == v)
                                  .firstOrNull;
                              setState(() => _elegirProcedencia(p));
                            },
                    ),
                  ),
                ],
              );
            },
          ),
          if (_procedenciaSeleccionada == 'OTRO') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _procedenciaDetalleCtrl,
              enabled: !_guardandoProcedencia,
              maxLength: 120,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre de la procedencia *',
                prefixIcon: Icon(Icons.edit_location_alt_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _guardandoProcedencia ? null : _guardarProcedencia,
                icon: _guardandoProcedencia
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_location_alt_rounded),
                label: const Text('Guardar procedencia'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _diagnosticoCtrl,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Diagnóstico o motivo del pedido *',
              prefixIcon: Icon(Icons.medical_information_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionResponsablesYFinanciamiento(TemaArea tema) {
    final ctx = _contexto;
    final doctores =
        ctx?.doctoresParaArea(_borrador.areaOrigen) ?? const <DoctorFicha>[];
    final receptores =
        ctx?.receptoresParaArea(_borrador.areaOrigen) ?? const [];
    final financiamientosTipo =
        ctx?.financiamientosPorTipo(_borrador.tipoAtencion) ?? const [];
    final finActual = _financiamientoSeleccionado;

    return _SeccionTarjeta(
      titulo: 'Responsables y financiamiento',
      icono: Icons.verified_user_rounded,
      tema: tema,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final dosCol =
                  DisenoAdaptable.columnasFormulario(
                    context,
                    constraints.maxWidth,
                  ) >
                  1;
              final ancho = dosCol
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: ancho,
                    child: SelectorCatalogo(
                      value: _borrador.tipoAtencion,
                      decoration: const InputDecoration(
                        labelText: 'Financiamiento *',
                        prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'PARTICULAR',
                          child: Text('Particular (Sin descuento de seguro)'),
                        ),
                        DropdownMenuItem(
                          value: 'SEGURO',
                          child: Text('Seguro de salud'),
                        ),
                        DropdownMenuItem(
                          value: 'CONVENIO',
                          child: Text('Convenio institucional'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) _cambiarTipoAtencion(v);
                      },
                    ),
                  ),
                  if (_borrador.tipoAtencion != 'PARTICULAR')
                    SizedBox(
                      width: ancho,
                      child: SelectorCatalogo(
                        value:
                            financiamientosTipo.any(
                              (f) => f.id == _borrador.financiamientoId,
                            )
                            ? _borrador.financiamientoId
                            : null,

                        decoration: InputDecoration(
                          labelText: _borrador.tipoAtencion == 'SEGURO'
                              ? 'Seguro seleccionado *'
                              : 'Convenio seleccionado *',
                          prefixIcon: const Icon(
                            Icons.health_and_safety_rounded,
                          ),
                        ),
                        items: financiamientosTipo
                            .map(
                              (f) => DropdownMenuItem(
                                value: f.id,
                                child: Text(
                                  '${f.nombre} (Desc. ${f.porcentajeDescuento.toStringAsFixed(0)}%)',
                                  softWrap: true,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _solicitudIdPendiente = null;
                            _borrador = _borrador.copyWith(financiamientoId: v);
                          });
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          if (finActual != null && _borrador.tipoAtencion != 'PARTICULAR') ...[
            const SizedBox(height: 8),
            MensajesApp.nota(
              'Cobertura activa de ${finActual.nombre}: aplica ${finActual.porcentajeDescuento.toStringAsFixed(0)}% de descuento sobre el precio Kairos en los ${finActual.medicamentosCubiertos.length} medicamentos cubiertos.',
              tipo: TipoMensaje.informacion,
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final dosCol =
                  DisenoAdaptable.columnasFormulario(
                    context,
                    constraints.maxWidth,
                  ) >
                  1;
              final ancho = dosCol
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: ancho,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: doctores.isEmpty
                              ? null
                              : () async {
                                  final doc = await showDialog<DoctorFicha>(
                                    context: context,
                                    builder: (_) => _SelectorProfesionalFicha(
                                      profesionales: doctores,
                                      seleccionado: _borrador.doctorId,
                                      tema: _temaActual,
                                    ),
                                  );
                                  if (doc == null || !mounted) return;
                                  setState(() {
                                    _solicitudIdPendiente = null;
                                    _borrador = _borrador.copyWith(
                                      doctorId: doc.id,
                                      doctorNombre: doc.nombre,
                                    );
                                  });
                                },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Profesional a cargo *',
                              prefixIcon: Icon(Icons.medical_services_rounded),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    doctores
                                            .where(
                                              (d) => d.id == _borrador.doctorId,
                                            )
                                            .firstOrNull
                                            ?.etiquetaCompleta ??
                                        'Buscar por nombre',
                                    softWrap: true,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.search_rounded,
                                  color: _temaActual.principal,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (doctores.isEmpty) ...[
                          const SizedBox(height: 8),
                          MensajesApp.nota(
                            'No hay profesionales disponibles para esta área. Administración debe completar su colegiatura y asignación antes de enviar la ficha.',
                            tipo: TipoMensaje.advertencia,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: ancho,
                    child: SelectorCatalogo(
                      key: ValueKey(
                        'receptor-${_borrador.areaOrigen}-${_borrador.receptorId}',
                      ),
                      value: receptores.any((r) => r.id == _borrador.receptorId)
                          ? _borrador.receptorId
                          : null,

                      decoration: const InputDecoration(
                        labelText: 'Receptor del área *',
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                      items: receptores
                          .map(
                            (r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(
                                '${r.nombre} (${r.cargo})',
                                softWrap: true,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        if (id == null) return;
                        final rec = receptores.firstWhere((r) => r.id == id);
                        setState(() {
                          _solicitudIdPendiente = null;
                          _borrador = _borrador.copyWith(
                            receptorId: rec.id,
                            recibidoPor: rec.nombre,
                          );
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          if (receptores.isEmpty) ...[
            MensajesApp.nota(
              'Esta área no tiene personal receptor activo asignado. Solicita la asignación antes de enviar la ficha.',
              tipo: TipoMensaje.advertencia,
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _observacionesCtrl,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Observaciones adicionales para Farmacia (opcional)',
              prefixIcon: Icon(Icons.comment_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionKitEItems(TemaArea tema) {
    final kitsArea = _contexto?.kitsParaArea(_borrador.areaOrigen) ?? const [];
    final meds = _borrador.medicamentos;
    final dispositivos = _borrador.dispositivosMedicos;

    return _SeccionTarjeta(
      titulo: 'Productos del pedido',
      icono: Icons.inventory_rounded,
      tema: tema,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              FilledButton.tonalIcon(
                onPressed: _abrirSelectorKit,
                icon: const Icon(Icons.medical_services_rounded),
                label: Text(
                  'Aplicar kit del área (${kitsArea.length} disponible(s))',
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _abrirSelectorItem('MEDICAMENTO'),
                    icon: const Icon(Icons.medication_rounded),
                    label: const Text('Agregar medicamento'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _abrirSelectorItem('DISPOSITIVO_MEDICO'),
                    icon: const Icon(Icons.healing_rounded),
                    label: const Text('Agregar dispositivo / insumo'),
                  ),
                ],
              ),
            ],
          ),
          if (_borrador.kitId != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: tema.suave,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: tema.principal.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.copy_all_rounded, color: tema.principal, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kit aplicado como copia editable: "${_borrador.kitNombre ?? "Kit del área"}". '
                      'Cualquier ajuste que realices aquí pertenece solo a esta ficha.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _solicitudIdPendiente = null;
                        _borrador = _borrador.copyWith(limpiarKit: true);
                      });
                    },
                    child: const Text('Desvincular etiqueta'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildSubseccionItems(
            titulo: 'Medicamentos (${meds.length})',
            icono: Icons.medication_rounded,
            vacioTexto:
                'No hay medicamentos en la ficha. Usa "Aplicar kit del área" o "Agregar medicamento".',
            items: meds,
            tema: tema,
          ),
          const SizedBox(height: 16),
          _buildSubseccionItems(
            titulo:
                'Sección B · Dispositivos médicos e insumos (${dispositivos.length})',
            icono: Icons.healing_rounded,
            vacioTexto:
                'No hay dispositivos médicos o insumos en la ficha. Usa "Agregar dispositivo / insumo".',
            items: dispositivos,
            tema: tema,
          ),
        ],
      ),
    );
  }

  Widget _buildSubseccionItems({
    required String titulo,
    required IconData icono,
    required String vacioTexto,
    required List<FichaItemBorrador> items,
    required TemaArea tema,
  }) {
    final fin = _financiamientoSeleccionado;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E4EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FranjaPedidos(titulo: titulo, icono: icono),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                vacioTexto,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6E6E77),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 12, color: Color(0xFFE8E8F0)),
              itemBuilder: (context, index) {
                final item = items[index];
                final descuento =
                    fin?.calcularDescuentoPara(item.medicamentoId) ?? 0;
                final precioFinal = item.precioKairos != null
                    ? item.precioKairos! * (1 - descuento / 100.0)
                    : null;
                final excedeStock = item.superaStockFarmacia;

                return Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nombreComercial,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (item.presentacion != null &&
                                  item.presentacion!.trim().isNotEmpty)
                                item.presentacion!,
                              item.origenKit
                                  ? 'Copia de kit (editable)'
                                  : 'Selección individual',
                              'Stock Farmacia: ${item.farmaciaDisponible}',
                              if (precioFinal != null)
                                'S/ ${precioFinal.toStringAsFixed(2)}${descuento > 0 ? " (-${descuento.toStringAsFixed(0)}%)" : ""}',
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              color: excedeStock
                                  ? const Color(0xFFC62828)
                                  : const Color(0xFF5A5A66),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 8,
                      children: [
                        IconButton(
                          tooltip:
                              'Cambiar de sección (Medicamento / Dispositivo)',
                          onPressed: () {
                            final nueva = item.esDispositivoMedico
                                ? 'MEDICAMENTO'
                                : 'DISPOSITIVO_MEDICO';
                            setState(() {
                              _solicitudIdPendiente = null;
                              _borrador = _borrador.cambiarCategoriaItem(
                                item.medicamentoId,
                                nueva,
                              );
                            });
                          },
                          icon: const Icon(
                            Icons.swap_vert_circle_outlined,
                            size: 20,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Disminuir cantidad',
                          onPressed: () {
                            setState(() {
                              _solicitudIdPendiente = null;
                              _borrador = _borrador.cambiarCantidadItem(
                                item.medicamentoId,
                                item.cantidad - 1,
                              );
                            });
                          },
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 38),
                          alignment: Alignment.center,
                          child: Text(
                            '${item.cantidad}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Aumentar cantidad',
                          onPressed:
                              (!item.origenKit &&
                                  item.cantidad >= item.farmaciaDisponible)
                              ? null
                              : () {
                                  setState(() {
                                    _solicitudIdPendiente = null;
                                    _borrador = _borrador.cambiarCantidadItem(
                                      item.medicamentoId,
                                      item.cantidad + 1,
                                    );
                                  });
                                },
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                        IconButton(
                          tooltip: 'Quitar de la ficha',
                          onPressed: () {
                            setState(() {
                              _solicitudIdPendiente = null;
                              _borrador = _borrador.quitarItem(
                                item.medicamentoId,
                              );
                            });
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFC62828),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBarraEnvio() {
    return AccionesAdaptables(
      anchoMinimo: 220,
      acciones: [
        OutlinedButton.icon(
          onPressed: _guardando || _guardandoProcedencia
              ? null
              : _limpiarFormulario,
          icon: const Icon(Icons.cleaning_services_rounded),
          label: Text(
            _borrador.id == null ? 'Limpiar formulario' : 'Cancelar edición',
          ),
        ),
        FilledButton.icon(
          onPressed: _guardando || _guardandoProcedencia ? null : _guardarFicha,
          icon: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(
            _borrador.id == null
                ? 'Registrar ficha y enviar a Farmacia'
                : 'Guardar cambios de la ficha',
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionFichasRecientes(TemaArea tema) {
    return _SeccionTarjeta(
      titulo: 'Fichas recientes del área (${_fichasRecientes.length})',
      icono: Icons.history_rounded,
      tema: tema,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _fichasRecientes.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 16, color: Color(0xFFE8E8F0)),
        itemBuilder: (context, index) {
          final f = _fichasRecientes[index];
          return Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${f.numeroFicha} · ${f.pacienteNombre}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${f.tipoFicha} · Estado: ${f.estado} · '
                      'Financiamiento: ${f.financiamientoNombreAplicado ?? f.tipoAtencion} · '
                      'Médico: ${f.doctorNombre ?? "-"} · Receptor: ${f.recibidoPor ?? "-"} · '
                      '${f.items.length} ítem(s)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5A5A66),
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final huboCambios = await Navigator.of(context)
                          .push<bool>(
                            MaterialPageRoute(
                              builder: (_) => FichaDetalleAtencionView(
                                fichaId: f.id,
                                fichaInicial: f,
                              ),
                            ),
                          );
                      if (huboCambios == true && mounted) {
                        await _cargarDatosIniciales(
                          areaPreferida: _borrador.areaOrigen,
                        );
                      }
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Ver detalle'),
                  ),
                  if (f.esEditable)
                    OutlinedButton.icon(
                      onPressed: () => _cargarFichaParaEdicion(f),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('Editar ficha'),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SeccionTarjeta extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final TemaArea tema;
  final Widget child;

  const _SeccionTarjeta({
    required this.titulo,
    required this.icono,
    required this.tema,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        DisenoAdaptable.margen(MediaQuery.sizeOf(context).width),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E4EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FranjaPedidos(titulo: titulo, icono: icono),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Opciones anchas con estado seleccionado visible, sin comprimir la etiqueta.
class _PestanaTipoFicha extends StatelessWidget {
  final String nombre;
  final IconData icono;
  final bool seleccionada, habilitada;
  final VoidCallback onTap;
  const _PestanaTipoFicha({
    required this.nombre,
    required this.icono,
    required this.seleccionada,
    required this.habilitada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final principal = Theme.of(context).colorScheme.primary;
    final color = !habilitada
        ? const Color(0xFF85858F)
        : seleccionada
        ? Colors.white
        : principal;
    return Semantics(
      button: true,
      selected: seleccionada,
      enabled: habilitada,
      child: Material(
        color: !habilitada
            ? const Color(0xFFF2F2F5)
            : seleccionada
            ? principal
            : principal.withValues(alpha: .06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: habilitada
                ? principal.withValues(alpha: .25)
                : const Color(0xFFE0E0E6),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: habilitada ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icono, color: color, size: 24),
                      if (seleccionada && habilitada) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check_circle_rounded,
                          color: color,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nombre,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
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

class _SelectorProfesionalFicha extends StatefulWidget {
  final List<DoctorFicha> profesionales;
  final String? seleccionado;
  final TemaArea tema;
  const _SelectorProfesionalFicha({
    required this.profesionales,
    this.seleccionado,
    required this.tema,
  });
  @override
  State<_SelectorProfesionalFicha> createState() =>
      _SelectorProfesionalFichaState();
}

class _SelectorProfesionalFichaState extends State<_SelectorProfesionalFicha> {
  final _buscar = TextEditingController();
  int _limite = 30;
  @override
  Widget build(BuildContext context) {
    final q = _buscar.text.trim().toLowerCase();
    final lista = widget.profesionales
        .where((p) => p.etiquetaCompleta.toLowerCase().contains(q))
        .toList();
    return Theme(
      data: CatalogoEstilo.tema(context, area: widget.tema),
      child: DialogoAdaptable(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FranjaPedidos(
                titulo: 'Seleccionar profesional',
                icono: Icons.medical_services_outlined,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _buscar,
                onChanged: (_) => setState(() => _limite = 30),
                decoration: const InputDecoration(
                  labelText: 'Buscar por nombre',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              if (lista.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay coincidencias.'),
                ),
              for (final p in lista.take(_limite))
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  leading: Icon(
                    Icons.person_outline_rounded,
                    color: widget.tema.principal,
                  ),
                  title: Text(p.nombre, softWrap: true),
                  subtitle: Text(p.etiquetaCompleta, softWrap: true),
                  trailing: p.id == widget.seleccionado
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: widget.tema.principal,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, p),
                ),
              if (lista.length > _limite)
                TextButton(
                  onPressed: () => setState(() => _limite += 30),
                  child: const Text('Ver más'),
                ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }
}

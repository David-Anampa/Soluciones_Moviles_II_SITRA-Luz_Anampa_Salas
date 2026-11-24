import '../../../../core/theme/tema_pedidos.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/tema_area.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../../almacen/domain/solicitud_id.dart';
import '../../data/repositories/fichas_repository.dart';
import '../../domain/entities/ficha_catalogo_entities.dart';
import '../../domain/ficha_validadores.dart';

/// Vista de detalle completo, preparación en Farmacia, despacho parcial por ítem,
/// confirmación de entrega con descuento único por lote FEFO, anulación con motivo/contra-asiento
/// e historial cronológico de auditoría (HU-007, HU-008, HU-009, HU-010 y HU-011).
class FichaDetalleAtencionView extends StatefulWidget {
  final String fichaId;
  final FichaRegistrada? fichaInicial;

  const FichaDetalleAtencionView({
    super.key,
    required this.fichaId,
    this.fichaInicial,
  });

  @override
  State<FichaDetalleAtencionView> createState() =>
      _FichaDetalleAtencionViewState();
}

class _FichaDetalleAtencionViewState extends State<FichaDetalleAtencionView> {
  final FichasRepository _repository = FichasRepository();
  final TextEditingController _notasFarmaciaCtrl = TextEditingController();
  final Map<String, TextEditingController> _obsItemCtrls = {};

  ContextoRegistroFicha? _contexto;
  FichaRegistrada? _ficha;
  List<ItemDespachoEdicion> _edicionItems = const [];

  bool _cargando = true;
  bool _procesandoAccion = false;
  String? _errorCarga;
  String? _operacionIdPendiente;
  String? _accionPendiente;
  bool _huboCambios = false;

  @override
  void initState() {
    super.initState();
    if (widget.fichaInicial != null) {
      _aplicarFichaCargada(widget.fichaInicial!);
    }
    _cargarDetalle();
  }

  @override
  void dispose() {
    _notasFarmaciaCtrl.dispose();
    for (final c in _obsItemCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _rolUsuario => (_contexto?.rol ?? '').toUpperCase();

  List<String> get _areasUsuario => (_contexto?.areas ?? const [])
      .map((a) => a.codigo)
      .toList(growable: false);

  TemaArea get _temaFicha {
    final color = _ficha?.areaTemaColor ?? 'AZUL';
    return TemaArea.desde(color);
  }

  void _aplicarFichaCargada(FichaRegistrada ficha) {
    _ficha = ficha;
    _notasFarmaciaCtrl.text = ficha.notasFarmacia ?? '';

    final nuevosItems = <ItemDespachoEdicion>[];
    for (final item in ficha.items) {
      final cantSugerida =
          (ficha.estado == 'SOLICITADO' && item.cantidadEntregada == 0)
          ? (item.farmaciaDisponible < item.cantidadSolicitada
                ? item.farmaciaDisponible
                : item.cantidadSolicitada)
          : item.cantidadEntregada;
      final obsInicial =
          item.observacionItem ??
          ((ficha.estado == 'SOLICITADO' &&
                  cantSugerida < item.cantidadSolicitada)
              ? 'Stock disponible parcial en Farmacia ($cantSugerida de ${item.cantidadSolicitada})'
              : '');

      final ctrl = _obsItemCtrls.putIfAbsent(
        item.id,
        () => TextEditingController(text: obsInicial),
      );
      if (ctrl.text != obsInicial) {
        ctrl.text = obsInicial;
      }

      nuevosItems.add(
        ItemDespachoEdicion(
          itemId: item.id,
          medicamentoId: item.medicamentoId,
          nombreComercial: item.nombreComercial,
          cantidadSolicitada: item.cantidadSolicitada,
          cantidadEntregada: cantSugerida,
          farmaciaDisponible: item.farmaciaDisponible,
          observacionItem: obsInicial,
        ),
      );
    }
    _edicionItems = List.unmodifiable(nuevosItems);
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final resultados = await Future.wait([
        _repository.obtenerContexto(),
        _repository.obtenerDetalleFicha(widget.fichaId),
      ]);
      if (!mounted) return;
      final ctx = resultados[0] as ContextoRegistroFicha;
      final ficha = resultados[1] as FichaRegistrada;
      setState(() {
        _contexto = ctx;
        _aplicarFichaCargada(ficha);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = FichasRepository.mensajeError(
          e,
          'No se pudo cargar el detalle de la ficha.',
        );
        _cargando = false;
      });
    }
  }

  void _cambiarCantidadItem(String itemId, int nuevaCantidad) {
    final ficha = _ficha;
    if (ficha == null || !ficha.puedeEditarDespacho(_rolUsuario)) return;
    setState(() {
      _operacionIdPendiente = null;
      _edicionItems = _edicionItems
          .map((item) {
            if (item.itemId != itemId) return item;
            final tope = item.cantidadSolicitada;
            final ajustada = nuevaCantidad.clamp(0, tope);
            return item.copyWith(cantidadEntregada: ajustada);
          })
          .toList(growable: false);
    });
  }

  void _cambiarObservacionItem(String itemId, String texto) {
    setState(() {
      _operacionIdPendiente = null;
      _edicionItems = _edicionItems
          .map((item) {
            if (item.itemId != itemId) return item;
            return item.copyWith(observacionItem: texto);
          })
          .toList(growable: false);
    });
  }

  void _aplicarSugerenciaObservacion(String itemId, String sugerencia) {
    final ctrl = _obsItemCtrls[itemId];
    if (ctrl != null) {
      ctrl.text = sugerencia;
    }
    _cambiarObservacionItem(itemId, sugerencia);
  }

  Future<void> _ejecutarAccionAtencion({
    required String accion,
    String? notas,
    String? motivo,
    String? receptorId,
    String? recibidoPor,
    required String mensajeExito,
  }) async {
    final ficha = _ficha;
    if (ficha == null || _procesandoAccion) return;

    final errorPermiso = FichaValidadores.validarTransicionAtencion(
      ficha: ficha,
      accion: accion,
      rol: _rolUsuario,
      areasUsuario: _areasUsuario,
    );
    if (errorPermiso != null) {
      MensajesApp.mostrar(context, errorPermiso, tipo: TipoMensaje.error);
      return;
    }

    if (accion == 'GUARDAR_PREPARACION' || accion == 'MARCAR_LISTO_RECOJO') {
      final errorItems = FichaValidadores.validarDespachoItems(
        _edicionItems,
        notasFarmacia: notas ?? _notasFarmaciaCtrl.text,
        exigirAlMenosUnoEntregado: accion == 'MARCAR_LISTO_RECOJO',
      );
      if (errorItems != null) {
        MensajesApp.mostrar(context, errorItems, tipo: TipoMensaje.advertencia);
        return;
      }
    }

    if (accion == 'ANULAR_FICHA') {
      final errorMotivo = FichaValidadores.validarMotivoAnulacion(motivo);
      if (errorMotivo != null) {
        MensajesApp.mostrar(
          context,
          errorMotivo,
          tipo: TipoMensaje.advertencia,
        );
        return;
      }
    }

    if (_operacionIdPendiente == null || _accionPendiente != accion) {
      _operacionIdPendiente = generarSolicitudId();
      _accionPendiente = accion;
    }

    setState(() => _procesandoAccion = true);
    try {
      final actualizada = await _repository.procesarFicha(
        operacionId: _operacionIdPendiente!,
        fichaId: ficha.id,
        accion: accion,
        items:
            (accion == 'GUARDAR_PREPARACION' ||
                accion == 'MARCAR_LISTO_RECOJO' ||
                (accion == 'CONFIRMAR_ENTREGA' &&
                    ficha.puedeEditarDespacho(_rolUsuario)))
            ? _edicionItems
            : const [],
        notas: notas ?? _notasFarmaciaCtrl.text,
        motivo: motivo,
        receptorId: receptorId,
        recibidoPor: recibidoPor,
      );
      if (!mounted) return;
      setState(() {
        _operacionIdPendiente = null;
        _accionPendiente = null;
        _procesandoAccion = false;
        _huboCambios = true;
        _aplicarFichaCargada(actualizada);
      });
      MensajesApp.mostrar(context, mensajeExito, tipo: TipoMensaje.exito);
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesandoAccion = false);
      MensajesApp.mostrar(
        context,
        FichasRepository.mensajeError(e),
        tipo: TipoMensaje.error,
      );
    }
  }

  Future<void> _abrirDialogoConfirmarEntrega() async {
    final ficha = _ficha;
    if (ficha == null || _procesandoAccion) return;

    if (ficha.puedeEditarDespacho(_rolUsuario)) {
      final errorItems = FichaValidadores.validarDespachoItems(
        _edicionItems,
        notasFarmacia: _notasFarmaciaCtrl.text,
        exigirAlMenosUnoEntregado: true,
      );
      if (errorItems != null) {
        MensajesApp.mostrar(context, errorItems, tipo: TipoMensaje.advertencia);
        return;
      }
    }

    final receptoresArea =
        _contexto?.receptoresParaArea(ficha.areaOrigen) ?? const [];
    String? receptorIdSel = ficha.receptorId;
    if (receptorIdSel != null &&
        !receptoresArea.any((r) => r.id == receptorIdSel)) {
      receptorIdSel = null;
    }
    final obsEntregaCtrl = TextEditingController(
      text: ficha.observacionEntrega ?? '',
    );

    final totalADescontar = ficha.puedeEditarDespacho(_rolUsuario)
        ? _edicionItems.fold<int>(0, (acc, i) => acc + i.cantidadEntregada)
        : ficha.totalUnidadesEntregadas;

    final resultado = await showDialog<Map<String, String?>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.assignment_turned_in_rounded,
                    color: Color(0xFF1B5E20),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Confirmar entrega y descuento FEFO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MensajesApp.nota(
                        'Al confirmar la entrega de ${ficha.numeroFicha}, se descontarán de forma única y atómica $totalADescontar unidad(es) del stock de FARMACIA empezando por los lotes con vencimiento más próximo (FEFO).',
                        tipo: TipoMensaje.informacion,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: receptorIdSel,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Personal receptor del área *',
                          border: OutlineInputBorder(),
                        ),
                        items: receptoresArea
                            .map(
                              (r) => DropdownMenuItem(
                                value: r.id,
                                child: Text(
                                  '${r.nombre} (${r.cargo})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setModalState(() => receptorIdSel = val),
                      ),
                      if (receptoresArea.isEmpty)
                        MensajesApp.nota(
                          'No hay personal receptor activo asignado a esta área. Actualiza la ficha después de corregir la asignación.',
                          tipo: TipoMensaje.advertencia,
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: obsEntregaCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Observación de entrega / conformidad',
                          hintText:
                              'Opcional: conformidad de recojo en ventanilla o piso',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: TemaPedidos.colorRol(
                      TemaPedidos.rolActual(context),
                    ),
                  ),
                  onPressed: () {
                    final nombreReceptor = receptoresArea
                        .where((r) => r.id == receptorIdSel)
                        .firstOrNull
                        ?.nombre;
                    final errRec = FichaValidadores.validarReceptor(
                      receptorId: receptorIdSel,
                      recibidoPor: nombreReceptor,
                    );
                    if (errRec != null) {
                      MensajesApp.mostrar(
                        ctx,
                        errRec,
                        tipo: TipoMensaje.advertencia,
                      );
                      return;
                    }
                    Navigator.of(ctx).pop({
                      'receptor_id': receptorIdSel,
                      'recibido_por': nombreReceptor,
                      'notas': obsEntregaCtrl.text.trim(),
                    });
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Confirmar entrega'),
                ),
              ],
            );
          },
        );
      },
    );

    obsEntregaCtrl.dispose();

    if (resultado == null || !mounted) return;
    await _ejecutarAccionAtencion(
      accion: 'CONFIRMAR_ENTREGA',
      receptorId: resultado['receptor_id'],
      recibidoPor: resultado['recibido_por'],
      notas: resultado['notas'],
      mensajeExito:
          'Entrega confirmada (${ficha.numeroFicha}). Stock descontado por lote FEFO.',
    );
  }

  Future<void> _abrirDialogoAnularFicha() async {
    final ficha = _ficha;
    if (ficha == null || _procesandoAccion) return;

    final motivoCtrl = TextEditingController();
    final yaEntregada = ficha.estado == 'ENTREGADO';

    final motivoConfirmado = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.cancel_outlined, color: Color(0xFFB3261E)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  yaEntregada
                      ? 'Anular ficha con contra-asiento'
                      : 'Anular ficha de pedido',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MensajesApp.nota(
                    yaEntregada
                        ? 'Esta ficha ya fue ENTREGADA. Al anularla se generará un contra-asiento automático que reingresará las ${ficha.totalUnidadesEntregadas} unidad(es) a sus respectivos lotes en FARMACIA sin borrar ningún movimiento histórico.'
                        : 'La ficha pasará a estado ANULADO conservando el registro y el historial de auditoría. Como aún no fue entregada, el stock de Farmacia no fue descontado.',
                    tipo: yaEntregada
                        ? TipoMensaje.advertencia
                        : TipoMensaje.informacion,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: motivoCtrl,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Motivo obligatorio de anulación *',
                      hintText:
                          'Ej. Cambio de indicación médica, duplicidad de solicitud o alta del paciente...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Volver'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB3261E),
              ),
              onPressed: () {
                final err = FichaValidadores.validarMotivoAnulacion(
                  motivoCtrl.text,
                );
                if (err != null) {
                  MensajesApp.mostrar(ctx, err, tipo: TipoMensaje.advertencia);
                  return;
                }
                Navigator.of(ctx).pop(motivoCtrl.text.trim());
              },
              icon: const Icon(Icons.block_rounded),
              label: Text(
                yaEntregada
                    ? 'Anular y ejecutar contra-asiento'
                    : 'Confirmar anulación',
              ),
            ),
          ],
        );
      },
    );

    motivoCtrl.dispose();
    if (motivoConfirmado == null || !mounted) return;

    await _ejecutarAccionAtencion(
      accion: 'ANULAR_FICHA',
      motivo: motivoConfirmado,
      mensajeExito: yaEntregada
          ? 'Ficha ${ficha.numeroFicha} anulada con contra-asiento de reingreso a Farmacia.'
          : 'Ficha ${ficha.numeroFicha} anulada correctamente.',
    );
  }

  String _formatearFechaHora(DateTime? fecha) {
    if (fecha == null) return '-';
    final f = fecha.toLocal();
    final d = f.day.toString().padLeft(2, '0');
    final m = f.month.toString().padLeft(2, '0');
    final y = f.year;
    final hh = f.hour.toString().padLeft(2, '0');
    final mm = f.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  String _formatearFechaCorta(DateTime? fecha) {
    if (fecha == null) return '-';
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    return '$d/$m/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tema = _temaFicha;
    final ficha = _ficha;

    return Theme(
      data: TemaPedidos.aplicar(context, _rolUsuario).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: tema.principal,
          onPrimary: Colors.white,
        ),
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          Navigator.of(context).pop(_huboCambios);
        },
        child: Scaffold(
          backgroundColor: tema.suave,
          appBar: AppBar(
            backgroundColor: tema.principal,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Volver al listado',
              onPressed: () => Navigator.of(context).pop(_huboCambios),
            ),
            title: Text(
              ficha == null
                  ? 'Detalle del pedido'
                  : '${ficha.numeroFicha} · ${ficha.areaNombre}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                tooltip: 'Recargar detalle e historial',
                onPressed: _cargando || _procesandoAccion
                    ? null
                    : _cargarDetalle,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: _cargando && ficha == null
              ? const Center(child: CircularProgressIndicator())
              : _errorCarga != null && ficha == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MensajesApp.nota(_errorCarga!, tipo: TipoMensaje.error),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _cargarDetalle,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : ficha == null
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ContenidoAdaptable(
                    anchoMaximo: 1080,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBannerEstadoYFlujo(ficha, tema),
                        const SizedBox(height: 14),
                        _buildDatosClinicosYFinanciamiento(ficha, tema),
                        const SizedBox(height: 14),
                        if (ficha.puedeEditarDespacho(_rolUsuario)) ...[
                          _buildNotaModoPreparacion(ficha),
                          const SizedBox(height: 14),
                        ],
                        _buildSeccionItemsCategoria(
                          ficha: ficha,
                          tema: tema,
                          titulo: 'Medicamentos (${ficha.medicamentos.length})',
                          icono: Icons.medication_rounded,
                          items: ficha.medicamentos,
                        ),
                        const SizedBox(height: 14),
                        _buildSeccionItemsCategoria(
                          ficha: ficha,
                          tema: tema,
                          titulo:
                              'Dispositivos Médicos e Insumos (${ficha.dispositivosMedicos.length})',
                          icono: Icons.medical_services_rounded,
                          items: ficha.dispositivosMedicos,
                        ),
                        const SizedBox(height: 14),
                        _buildPanelOperacionAtencion(ficha, tema),
                        const SizedBox(height: 14),
                        _buildSeccionHistorialAuditoria(ficha, tema),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildBannerEstadoYFlujo(FichaRegistrada ficha, TemaArea tema) {
    final pasos = const [
      ('SOLICITADO', 'Solicitado', Icons.description_outlined),
      ('EN_PREPARACION', 'En preparación', Icons.inventory_2_outlined),
      ('LISTO_PARA_RECOJO', 'Listo para recojo', Icons.fact_check_outlined),
      ('ENTREGADO', 'Entregado', Icons.verified_rounded),
    ];
    final indiceActual = pasos.indexWhere((p) => p.$1 == ficha.estado);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ficha.esUrgente
              ? const Color(0xFFC62828)
              : tema.principal.withValues(alpha: 0.28),
          width: ficha.esUrgente ? 1.6 : 1,
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
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _ChipEtiqueta(
                    texto: ficha.numeroFicha,
                    colorTexto: Colors.white,
                    colorFondo: tema.principal,
                    icono: Icons.receipt_long_rounded,
                  ),
                  _ChipEtiqueta(
                    texto: ficha.areaNombre,
                    colorTexto: tema.principal,
                    colorFondo: tema.suave,
                    icono: Icons.local_hospital_rounded,
                  ),
                  _ChipEtiqueta(
                    texto: ficha.esNeonatologia
                        ? 'NEONATOLOGÍA'
                        : 'FICHA GENERAL',
                    colorTexto: const Color(0xFF37474F),
                    colorFondo: const Color(0xFFECEFF1),
                  ),
                  _ChipEtiqueta(
                    texto: 'Turno ${ficha.turno}',
                    colorTexto: const Color(0xFF455A64),
                    colorFondo: const Color(0xFFF1F5F9),
                  ),
                  if (ficha.esUrgente)
                    const _ChipEtiqueta(
                      texto: 'PRIORIDAD URGENTE',
                      colorTexto: Colors.white,
                      colorFondo: Color(0xFFC62828),
                      icono: Icons.priority_high_rounded,
                    ),
                ],
              ),
              _buildBadgeEstado(ficha.estado),
            ],
          ),
          const SizedBox(height: 14),
          if (ficha.estado == 'CANCELADO')
            MensajesApp.nota(
              'FICHA ANULADA · Motivo: "${ficha.motivoAnulacion ?? "Sin motivo especificado"}"\n'
              'Anulado por: ${ficha.anuladoPorNombre ?? "-"} · Fecha: ${_formatearFechaHora(ficha.fechaAnulacion)}',
              tipo: TipoMensaje.error,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(pasos.length, (i) {
                final paso = pasos[i];
                final completado = indiceActual >= i;
                final actual = indiceActual == i;
                final color = completado
                    ? (actual ? tema.principal : const Color(0xFF2E7D32))
                    : const Color(0xFF94A3B8);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: completado
                        ? color.withValues(alpha: 0.1)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: completado ? color : const Color(0xFFE2E8F0),
                      width: actual ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(paso.$3, size: 17, color: color),
                      const SizedBox(width: 6),
                      Text(
                        '${i + 1}. ${paso.$2}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: actual
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildBadgeEstado(String estado) {
    final (color, fondo, etiqueta) = switch (estado) {
      'SOLICITADO' => (
        const Color(0xFF0D47A1),
        const Color(0xFFE3F2FD),
        'SOLICITADO',
      ),
      'EN_PREPARACION' => (
        const Color(0xFFE65100),
        const Color(0xFFFFF3E0),
        'EN PREPARACIÓN',
      ),
      'LISTO_PARA_RECOJO' => (
        const Color(0xFF4A148C),
        const Color(0xFFF3E5F5),
        'LISTO PARA RECOJO',
      ),
      'ENTREGADO' => (
        const Color(0xFF1B5E20),
        const Color(0xFFE8F5E9),
        'ENTREGADO',
      ),
      'CANCELADO' => (
        const Color(0xFFB71C1C),
        const Color(0xFFFFEBEE),
        'ANULADO',
      ),
      _ => (const Color(0xFF37474F), const Color(0xFFECEFF1), estado),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        etiqueta,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDatosClinicosYFinanciamiento(
    FichaRegistrada ficha,
    TemaArea tema,
  ) {
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
          FranjaPedidos(
            titulo: 'Datos del pedido',
            icono: Icons.person_pin_rounded,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              if (!ficha.esNeonatologia) ...[
                _DatoDetalle(
                  etiqueta: 'Paciente',
                  valor: ficha.pacienteNombre,
                  destacado: true,
                ),
                _DatoDetalle(
                  etiqueta: 'Procedencia',
                  valor:
                      ficha.procedencia == 'OTRO' &&
                          (ficha.procedenciaDetalle ?? '').isNotEmpty
                      ? 'OTRO (${ficha.procedenciaDetalle})'
                      : (ficha.procedencia ?? '-'),
                ),
                _DatoDetalle(
                  etiqueta: 'Diagnóstico / Motivo',
                  valor: ficha.diagnosticoMotivo ?? '-',
                ),
              ] else ...[
                _DatoDetalle(
                  etiqueta: 'Madre',
                  valor: ficha.madreNombre ?? '-',
                  destacado: true,
                ),
                _DatoDetalle(
                  etiqueta: 'Recién Nacido (Apellidos)',
                  valor: ficha.recienNacidoApellidos ?? '-',
                  destacado: true,
                ),
                _DatoDetalle(
                  etiqueta: 'Habitación / Cuna',
                  valor: (ficha.habitacion ?? '').isEmpty
                      ? '-'
                      : ficha.habitacion!,
                ),
                _DatoDetalle(
                  etiqueta: 'Tipo de parto',
                  valor: ficha.tipoParto ?? '-',
                ),
              ],
              _DatoDetalle(
                etiqueta: 'Médico a cargo',
                valor: ficha.doctorNombre ?? '-',
              ),
              _DatoDetalle(
                etiqueta: 'Personal receptor (Piso)',
                valor: ficha.recibidoPor ?? '-',
              ),
              _DatoDetalle(
                etiqueta: 'Financiamiento / Seguro',
                valor: ficha.financiamientoNombreAplicado ?? ficha.tipoAtencion,
              ),
              if (ficha.kitNombre != null && ficha.kitNombre!.isNotEmpty)
                _DatoDetalle(etiqueta: 'Kit', valor: ficha.kitNombre!),
              _DatoDetalle(
                etiqueta: 'Solicitado el',
                valor: _formatearFechaHora(ficha.fechaCreacion),
              ),
              if (ficha.solicitadoPorNombre != null)
                _DatoDetalle(
                  etiqueta: 'Registrado por',
                  valor: ficha.solicitadoPorNombre!,
                ),
              if (ficha.preparadoPorNombre != null)
                _DatoDetalle(
                  etiqueta: 'Preparado por (Farmacia)',
                  valor:
                      '${ficha.preparadoPorNombre!} (${_formatearFechaHora(ficha.fechaPreparacion)})',
                ),
              if (ficha.entregadoPorNombre != null ||
                  ficha.fechaEntrega != null)
                _DatoDetalle(
                  etiqueta: 'Entregado el',
                  valor:
                      '${_formatearFechaHora(ficha.fechaEntrega)} · ${ficha.entregadoPorNombre ?? "Farmacia"}',
                ),
              _DatoDetalle(
                etiqueta: 'Unidades (Despachado / Solicitado)',
                valor:
                    '${ficha.totalUnidadesEntregadas} / ${ficha.totalUnidadesSolicitadas} und.',
                destacado: true,
              ),
              if (ficha.montoTotalSolicitado > 0)
                _DatoDetalle(
                  etiqueta: 'Valorización referencial Kairos',
                  valor:
                      'Solicitado: S/ ${ficha.montoTotalSolicitado.toStringAsFixed(2)} · Despachado: S/ ${ficha.montoTotalEntregado.toStringAsFixed(2)}',
                ),
            ],
          ),
          if ((ficha.observaciones ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'Observación clínica de solicitud: ${ficha.observaciones}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
          if ((ficha.notasFarmacia ?? '').trim().isNotEmpty &&
              !ficha.puedeEditarDespacho(_rolUsuario)) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Text(
                'Nota de Farmacia: ${ficha.notasFarmacia}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF4E342E),
                ),
              ),
            ),
          ],
          if ((ficha.observacionEntrega ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Text(
                'Conformidad de entrega: ${ficha.observacionEntrega}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotaModoPreparacion(FichaRegistrada ficha) {
    return MensajesApp.nota(
      'Puedes ajustar la cantidad real a despachar en cada ítem según el stock vigente en Farmacia. Si entregas menos de lo solicitado (despacho parcial), ingresa la observación justificativa en el ítem.',
      tipo: TipoMensaje.informacion,
    );
  }

  Widget _buildSeccionItemsCategoria({
    required FichaRegistrada ficha,
    required TemaArea tema,
    required String titulo,
    required IconData icono,
    required List<FichaRegistradaItem> items,
  }) {
    final puedeEditar = ficha.puedeEditarDespacho(_rolUsuario);

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
          FranjaPedidos(titulo: titulo, icono: icono),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Sin ítems registrados en esta categoría.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, index) {
                final item = items[index];
                final edicion = _edicionItems
                    .where((e) => e.itemId == item.id)
                    .firstOrNull;
                final cantDespachada =
                    edicion?.cantidadEntregada ?? item.cantidadEntregada;
                final esParcial = cantDespachada < item.cantidadSolicitada;
                final sinStockSuficiente =
                    cantDespachada > item.farmaciaDisponible &&
                    ficha.estado != 'ENTREGADO' &&
                    ficha.estado != 'CANCELADO';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    item.nombreComercial,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (item.origenKit)
                                    const _ChipEtiqueta(
                                      texto: 'Kit',
                                      colorTexto: Color(0xFF0D47A1),
                                      colorFondo: Color(0xFFE3F2FD),
                                    ),
                                  if (esParcial &&
                                      (puedeEditar ||
                                          ficha.estado != 'SOLICITADO'))
                                    const _ChipEtiqueta(
                                      texto: 'Despacho parcial',
                                      colorTexto: Color(0xFFE65100),
                                      colorFondo: Color(0xFFFFF3E0),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  if ((item.presentacion ?? '').isNotEmpty)
                                    item.presentacion!,
                                  if ((item.laboratorio ?? '').isNotEmpty)
                                    item.laboratorio!,
                                  item.unidad,
                                  if (item.precioUnitarioAplicado != null)
                                    'Neto: S/ ${item.precioUnitarioAplicado!.toStringAsFixed(2)}'
                                  else if (item.precioKairosAplicado != null)
                                    'Kairos: S/ ${item.precioKairosAplicado!.toStringAsFixed(2)}',
                                  if ((item.porcentajeDescuentoAplicado ?? 0) >
                                      0)
                                    'Desc. ${item.porcentajeDescuentoAplicado!.toStringAsFixed(0)}%',
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _ChipEtiqueta(
                              texto: 'Solicitado: ${item.cantidadSolicitada}',
                              colorTexto: const Color(0xFF1E293B),
                              colorFondo: const Color(0xFFF1F5F9),
                            ),
                            _ChipEtiqueta(
                              texto: 'Despachado: $cantDespachada',
                              colorTexto: esParcial
                                  ? const Color(0xFFE65100)
                                  : const Color(0xFF1B5E20),
                              colorFondo: esParcial
                                  ? const Color(0xFFFFF3E0)
                                  : const Color(0xFFE8F5E9),
                            ),
                            if (ficha.estado != 'ENTREGADO' &&
                                ficha.estado != 'CANCELADO')
                              _ChipEtiqueta(
                                texto:
                                    'Stock Farmacia: ${item.farmaciaDisponible}',
                                colorTexto: sinStockSuficiente
                                    ? const Color(0xFFB71C1C)
                                    : const Color(0xFF0D47A1),
                                colorFondo: sinStockSuficiente
                                    ? const Color(0xFFFFEBEE)
                                    : const Color(0xFFE3F2FD),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (puedeEditar) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Cantidad a despachar:',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            onPressed: cantDespachada <= 0
                                ? null
                                : () => _cambiarCantidadItem(
                                    item.id,
                                    cantDespachada - 1,
                                  ),
                            icon: const Icon(Icons.remove_rounded, size: 18),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              '$cantDespachada / ${item.cantidadSolicitada}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            visualDensity: VisualDensity.compact,
                            onPressed: cantDespachada >= item.cantidadSolicitada
                                ? null
                                : () => _cambiarCantidadItem(
                                    item.id,
                                    cantDespachada + 1,
                                  ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                          ),
                          TextButton(
                            onPressed: () => _cambiarCantidadItem(
                              item.id,
                              item.farmaciaDisponible < item.cantidadSolicitada
                                  ? item.farmaciaDisponible
                                  : item.cantidadSolicitada,
                            ),
                            child: const Text('Máx. disponible'),
                          ),
                          if (cantDespachada > 0)
                            TextButton(
                              onPressed: () => _cambiarCantidadItem(item.id, 0),
                              child: const Text('No disponible (0)'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _obsItemCtrls[item.id],
                        onChanged: (v) => _cambiarObservacionItem(item.id, v),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: esParcial
                              ? 'Observación obligatoria por despacho parcial *'
                              : 'Observación del ítem (opcional)',
                          hintText:
                              'Ej. Stock parcial en Farmacia, ajuste de dosis o pendiente de reposición',
                          border: const OutlineInputBorder(),
                          filled: esParcial,
                          fillColor: esParcial
                              ? const Color(0xFFFFFBF0)
                              : Colors.transparent,
                        ),
                      ),
                      if (esParcial) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text(
                                'Stock parcial en Farmacia',
                                style: TextStyle(fontSize: 11.5),
                              ),
                              onPressed: () => _aplicarSugerenciaObservacion(
                                item.id,
                                'Stock disponible parcial en Farmacia ($cantDespachada de ${item.cantidadSolicitada} und.)',
                              ),
                            ),
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text(
                                'Sin stock vigente en Farmacia',
                                style: TextStyle(fontSize: 11.5),
                              ),
                              onPressed: () => _aplicarSugerenciaObservacion(
                                item.id,
                                'Sin stock vigente disponible en Farmacia al momento del despacho',
                              ),
                            ),
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text(
                                'Ajuste coordinado con piso',
                                style: TextStyle(fontSize: 11.5),
                              ),
                              onPressed: () => _aplicarSugerenciaObservacion(
                                item.id,
                                'Cantidad ajustada en coordinación con el área clínica',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ] else if ((item.observacionItem ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Observación de despacho: ${item.observacionItem}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                    ],
                    if (item.lotesDespachados.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lotes FEFO descontados de Farmacia:',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: item.lotesDespachados.map((lote) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: lote.fueReingresado
                                        ? const Color(0xFFFFEBEE)
                                        : const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Lote ${lote.numeroLote} · Vence: ${_formatearFechaCorta(lote.fechaVencimiento)} · '
                                    '${lote.cantidad} und.${lote.fueReingresado ? " (Reingresado: ${lote.cantidadReingresada})" : ""}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: lote.fueReingresado
                                          ? const Color(0xFFB71C1C)
                                          : const Color(0xFF1B5E20),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPanelOperacionAtencion(FichaRegistrada ficha, TemaArea tema) {
    final puedeIniciar = ficha.puedeIniciarPreparacion(_rolUsuario);
    final puedeEditar = ficha.puedeEditarDespacho(_rolUsuario);
    final puedeMarcarListo = ficha.puedeMarcarListoRecojo(_rolUsuario);
    final puedeEntregar = ficha.puedeConfirmarEntrega(
      rol: _rolUsuario,
      areasUsuario: _areasUsuario,
    );
    final puedeAnular = ficha.puedeAnular(
      rol: _rolUsuario,
      areasUsuario: _areasUsuario,
    );

    if (!puedeIniciar &&
        !puedeEditar &&
        !puedeMarcarListo &&
        !puedeEntregar &&
        !puedeAnular) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tema.principal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FranjaPedidos(
            titulo: 'Atender pedido',
            icono: Icons.published_with_changes_rounded,
          ),
          const SizedBox(height: 14),
          AccionesAdaptables(
            anchoMinimo: 210,
            acciones: [
              if (puedeIniciar)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: TemaPedidos.colorRol(
                      TemaPedidos.rolActual(context),
                    ),
                  ),
                  onPressed: _procesandoAccion
                      ? null
                      : () => _ejecutarAccionAtencion(
                          accion: 'INICIAR_PREPARACION',
                          mensajeExito:
                              'Ficha ${ficha.numeroFicha} marcada EN PREPARACIÓN.',
                        ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Iniciar preparación'),
                ),
              if (puedeEditar)
                OutlinedButton.icon(
                  onPressed: _procesandoAccion
                      ? null
                      : () => _ejecutarAccionAtencion(
                          accion: 'GUARDAR_PREPARACION',
                          mensajeExito:
                              'Cantidades y observaciones de despacho guardadas.',
                        ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar avance de despacho'),
                ),
              if (puedeMarcarListo)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: TemaPedidos.colorRol(
                      TemaPedidos.rolActual(context),
                    ),
                  ),
                  onPressed: _procesandoAccion
                      ? null
                      : () => _ejecutarAccionAtencion(
                          accion: 'MARCAR_LISTO_RECOJO',
                          mensajeExito:
                              'Ficha ${ficha.numeroFicha} marcada como LISTA PARA RECOJO.',
                        ),
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('Marcar listo para recojo'),
                ),
              if (puedeEntregar)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: TemaPedidos.colorRol(
                      TemaPedidos.rolActual(context),
                    ),
                  ),
                  onPressed: _procesandoAccion
                      ? null
                      : _abrirDialogoConfirmarEntrega,
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Confirmar entrega'),
                ),
              if (puedeAnular)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB3261E),
                    side: const BorderSide(color: Color(0xFFB3261E)),
                  ),
                  onPressed: _procesandoAccion
                      ? null
                      : _abrirDialogoAnularFicha,
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(
                    ficha.estado == 'ENTREGADO'
                        ? 'Anular con contra-asiento'
                        : 'Anular ficha con motivo',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionHistorialAuditoria(FichaRegistrada ficha, TemaArea tema) {
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
          FranjaPedidos(
            titulo: 'Historial (${ficha.historial.length})',
            icono: Icons.timeline_rounded,
          ),
          const SizedBox(height: 12),
          if (ficha.historial.isEmpty)
            const Text(
              'Aún no se registran eventos detallados en la bitácora para esta ficha.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ficha.historial.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, index) {
                final ev = ficha.historial[index];
                final esReingreso =
                    ev.tipoEvento.contains('ANULA') ||
                    ev.tipoEvento.contains('REINGRESO');
                final esConsumo =
                    ev.tipoEvento == 'CONSUMO_FICHA_AREA' ||
                    ev.tipoEvento == 'FICHA_ENTREGADA';
                final colorIcono = esReingreso
                    ? const Color(0xFFB3261E)
                    : esConsumo
                    ? const Color(0xFF1B5E20)
                    : tema.principal;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorIcono.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        esReingreso
                            ? Icons.replay_circle_filled_rounded
                            : esConsumo
                            ? Icons.check_circle_rounded
                            : Icons.history_edu_rounded,
                        size: 16,
                        color: colorIcono,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                ev.etiquetaEvento,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: colorIcono,
                                ),
                              ),
                              Text(
                                _formatearFechaHora(ev.fechaEvento),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              _ChipEtiqueta(
                                texto: ev.usuarioRol != null
                                    ? '${ev.usuarioNombre} (${ev.usuarioRol})'
                                    : ev.usuarioNombre,
                                colorTexto: const Color(0xFF334155),
                                colorFondo: const Color(0xFFF1F5F9),
                              ),
                              if (ev.numeroLote != null)
                                _ChipEtiqueta(
                                  texto: 'Lote ${ev.numeroLote}',
                                  colorTexto: const Color(0xFF1B5E20),
                                  colorFondo: const Color(0xFFE8F5E9),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ev.descripcion,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DatoDetalle extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final bool destacado;

  const _DatoDetalle({
    required this.etiqueta,
    required this.valor,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 310),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(
              fontSize: destacado ? 13.5 : 13,
              fontWeight: destacado ? FontWeight.w800 : FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipEtiqueta extends StatelessWidget {
  final String texto;
  final Color colorTexto;
  final Color colorFondo;
  final IconData? icono;

  const _ChipEtiqueta({
    required this.texto,
    required this.colorTexto,
    required this.colorFondo,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 14, color: colorTexto),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: colorTexto,
            ),
          ),
        ],
      ),
    );
  }
}

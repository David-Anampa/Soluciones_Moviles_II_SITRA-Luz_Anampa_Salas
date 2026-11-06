import 'entities/ficha_catalogo_entities.dart';

/// Ítem inmutable dentro del borrador de una ficha de pedido (HU-003 / HU-004 / HU-005).
class FichaItemBorrador {
  final String medicamentoId;
  final String nombreComercial;
  final String? presentacion;
  final String? laboratorio;
  final String unidad;
  final String categoriaItem; // MEDICAMENTO | DISPOSITIVO_MEDICO
  final int cantidad;
  final int farmaciaDisponible;
  final double? precioKairos;
  final bool origenKit;
  final bool activo;

  const FichaItemBorrador({
    required this.medicamentoId,
    required this.nombreComercial,
    this.presentacion,
    this.laboratorio,
    this.unidad = 'UNIDAD',
    this.categoriaItem = 'MEDICAMENTO',
    required this.cantidad,
    required this.farmaciaDisponible,
    this.precioKairos,
    this.origenKit = false,
    this.activo = true,
  });

  bool get esDispositivoMedico => categoriaItem == 'DISPOSITIVO_MEDICO';

  bool get superaStockFarmacia => cantidad > farmaciaDisponible;

  FichaItemBorrador copyWith({
    int? cantidad,
    String? categoriaItem,
    int? farmaciaDisponible,
    bool? origenKit,
  }) {
    return FichaItemBorrador(
      medicamentoId: medicamentoId,
      nombreComercial: nombreComercial,
      presentacion: presentacion,
      laboratorio: laboratorio,
      unidad: unidad,
      categoriaItem: categoriaItem ?? this.categoriaItem,
      cantidad: cantidad ?? this.cantidad,
      farmaciaDisponible: farmaciaDisponible ?? this.farmaciaDisponible,
      precioKairos: precioKairos,
      origenKit: origenKit ?? this.origenKit,
      activo: activo,
    );
  }

  Map<String, dynamic> toMap() => {
        'medicamento_id': medicamentoId,
        'cantidad': cantidad,
        'categoria_item': categoriaItem,
        'origen_kit': origenKit,
      };
}

/// Borrador inmutable para crear o editar una ficha de pedido (General o Neonatología).
/// Al aplicar un kit (HU-005), sus ítems se copian como elementos propios del borrador,
/// permitiendo editar cantidades, quitar o agregar ítems sin alterar la plantilla del kit.
class FichaBorrador {
  final String? id;
  final String tipoFicha; // GENERAL | NEONATOLOGIA
  final String areaOrigen;
  final String turno; // DIA | TARDE | NOCHE
  final String prioridad; // NORMAL | URGENTE
  final String tipoAtencion; // PARTICULAR | SEGURO | CONVENIO
  final String? financiamientoId;
  final String? doctorId;
  final String doctorNombre;
  final String? receptorId;
  final String recibidoPor;

  // Campos Ficha General (RF-003)
  final String pacienteNombre;
  final String procedencia; // EMERGENCIA | HOSPITALIZACION | OTRO
  final String procedenciaDetalle;
  final String diagnosticoMotivo;

  // Campos Ficha Neonatología (RF-003)
  final String madreNombre;
  final String habitacion;
  final String recienNacidoApellidos;
  final String tipoParto; // EUTOCICO | DISTOCICO | CESAREA | OTRO

  // Kit aplicado opcional (HU-005) y observaciones
  final String? kitId;
  final String? kitNombre;
  final bool confirmarFaltanteKit;
  final String observaciones;
  final List<FichaItemBorrador> items;

  FichaBorrador({
    this.id,
    this.tipoFicha = 'GENERAL',
    this.areaOrigen = '',
    this.turno = 'DIA',
    this.prioridad = 'NORMAL',
    this.tipoAtencion = 'PARTICULAR',
    this.financiamientoId,
    this.doctorId,
    this.doctorNombre = '',
    this.receptorId,
    this.recibidoPor = '',
    this.pacienteNombre = '',
    this.procedencia = 'EMERGENCIA',
    this.procedenciaDetalle = '',
    this.diagnosticoMotivo = '',
    this.madreNombre = '',
    this.habitacion = '',
    this.recienNacidoApellidos = '',
    this.tipoParto = 'EUTOCICO',
    this.kitId,
    this.kitNombre,
    this.confirmarFaltanteKit = false,
    this.observaciones = '',
    List<FichaItemBorrador> items = const [],
  }) : items = List.unmodifiable(items);

  bool get esNeonatologia => tipoFicha == 'NEONATOLOGIA';

  /// Sección diferenciada de medicamentos (RF-003).
  List<FichaItemBorrador> get medicamentos => items
      .where((i) => i.categoriaItem != 'DISPOSITIVO_MEDICO')
      .toList(growable: false);

  /// Sección diferenciada de dispositivos médicos e insumos (RF-003).
  List<FichaItemBorrador> get dispositivosMedicos => items
      .where((i) => i.categoriaItem == 'DISPOSITIVO_MEDICO')
      .toList(growable: false);

  bool get tieneItemsConFaltanteKit =>
      items.any((i) => i.origenKit && i.superaStockFarmacia);

  /// Construye un borrador a partir de una ficha existente en estado SOLICITADO para su edición.
  factory FichaBorrador.desdeFicha(
    FichaRegistrada ficha, {
    Map<String, int> stockFarmaciaPorMed = const {},
  }) {
    return FichaBorrador(
      id: ficha.id,
      tipoFicha: ficha.tipoFicha,
      areaOrigen: ficha.areaOrigen,
      turno: ficha.turno,
      prioridad: ficha.prioridad,
      tipoAtencion: ficha.tipoAtencion,
      financiamientoId: ficha.financiamientoId,
      doctorId: ficha.doctorId,
      doctorNombre: ficha.doctorNombre ?? '',
      receptorId: ficha.receptorId,
      recibidoPor: ficha.recibidoPor ?? '',
      pacienteNombre: ficha.tipoFicha == 'GENERAL' ? ficha.pacienteNombre : '',
      procedencia: ficha.procedencia ?? 'EMERGENCIA',
      procedenciaDetalle: ficha.procedenciaDetalle ?? '',
      diagnosticoMotivo: ficha.diagnosticoMotivo ?? '',
      madreNombre: ficha.madreNombre ?? '',
      habitacion: ficha.habitacion ?? '',
      recienNacidoApellidos: ficha.recienNacidoApellidos ?? '',
      tipoParto: ficha.tipoParto ?? 'EUTOCICO',
      kitId: ficha.kitId,
      kitNombre: ficha.kitNombre,
      observaciones: ficha.observaciones ?? '',
      items: ficha.items
          .map(
            (i) => FichaItemBorrador(
              medicamentoId: i.medicamentoId,
              nombreComercial: i.nombreComercial,
              presentacion: i.presentacion,
              laboratorio: i.laboratorio,
              unidad: i.unidad,
              categoriaItem: i.categoriaItem,
              cantidad: i.cantidadSolicitada,
              farmaciaDisponible:
                  stockFarmaciaPorMed[i.medicamentoId] ?? i.cantidadSolicitada,
              precioKairos: i.precioKairosAplicado,
              origenKit: i.origenKit,
            ),
          )
          .toList(growable: false),
    );
  }

  /// Copia los ítems del kit seleccionado a la ficha como elementos independientes y editables (HU-005).
  FichaBorrador aplicarKit(
    KitDisponibleFicha kit, {
    bool conservarExistentes = false,
    bool confirmarFaltante = false,
  }) {
    final mapa = <String, FichaItemBorrador>{};
    if (conservarExistentes) {
      for (final existente in items) {
        mapa[existente.medicamentoId] = existente;
      }
    }
    for (final kItem in kit.items) {
      if (!kItem.activo) continue;
      mapa[kItem.medicamentoId] = FichaItemBorrador(
        medicamentoId: kItem.medicamentoId,
        nombreComercial: kItem.nombreComercial,
        presentacion: kItem.presentacion,
        laboratorio: kItem.laboratorio,
        unidad: kItem.unidad,
        categoriaItem: kItem.categoria,
        cantidad: kItem.cantidad,
        farmaciaDisponible: kItem.farmaciaDisponible,
        precioKairos: kItem.precioKairos,
        origenKit: true,
        activo: kItem.activo,
      );
    }
    return copyWith(
      kitId: kit.id,
      kitNombre: kit.nombre,
      confirmarFaltanteKit: confirmarFaltante,
      items: mapa.values.toList(growable: false),
    );
  }

  /// Agrega o actualiza un ítem individual seleccionado del catálogo con stock en Farmacia (HU-004).
  FichaBorrador agregarOActualizarItem(FichaItemBorrador nuevo) {
    final indice =
        items.indexWhere((i) => i.medicamentoId == nuevo.medicamentoId);
    final copia = List<FichaItemBorrador>.from(items);
    if (indice >= 0) {
      final actual = copia[indice];
      final suma = actual.cantidad + nuevo.cantidad;
      final tope = nuevo.farmaciaDisponible > 0
          ? (suma > nuevo.farmaciaDisponible ? nuevo.farmaciaDisponible : suma)
          : suma;
      copia[indice] = actual.copyWith(
        cantidad: tope,
        categoriaItem: nuevo.categoriaItem,
        farmaciaDisponible: nuevo.farmaciaDisponible,
      );
    } else {
      copia.add(nuevo);
    }
    return copyWith(items: copia);
  }

  FichaBorrador cambiarCantidadItem(String medicamentoId, int nuevaCantidad) {
    if (nuevaCantidad <= 0) return quitarItem(medicamentoId);
    return copyWith(
      items: items
          .map(
            (i) => i.medicamentoId == medicamentoId
                ? i.copyWith(cantidad: nuevaCantidad)
                : i,
          )
          .toList(growable: false),
    );
  }

  FichaBorrador cambiarCategoriaItem(
    String medicamentoId,
    String nuevaCategoria,
  ) {
    return copyWith(
      items: items
          .map(
            (i) => i.medicamentoId == medicamentoId
                ? i.copyWith(categoriaItem: nuevaCategoria)
                : i,
          )
          .toList(growable: false),
    );
  }

  FichaBorrador quitarItem(String medicamentoId) {
    final restantes = items
        .where((i) => i.medicamentoId != medicamentoId)
        .toList(growable: false);
    final aunTieneItemsDeKit = restantes.any((i) => i.origenKit);
    return copyWith(
      items: restantes,
      limpiarKit: !aunTieneItemsDeKit && kitId != null,
    );
  }

  FichaBorrador copyWith({
    String? id,
    String? tipoFicha,
    String? areaOrigen,
    String? turno,
    String? prioridad,
    String? tipoAtencion,
    String? financiamientoId,
    bool limpiarFinanciamientoId = false,
    String? doctorId,
    bool limpiarDoctorId = false,
    String? doctorNombre,
    String? receptorId,
    bool limpiarReceptorId = false,
    String? recibidoPor,
    String? pacienteNombre,
    String? procedencia,
    String? procedenciaDetalle,
    String? diagnosticoMotivo,
    String? madreNombre,
    String? habitacion,
    String? recienNacidoApellidos,
    String? tipoParto,
    String? kitId,
    String? kitNombre,
    bool limpiarKit = false,
    bool? confirmarFaltanteKit,
    String? observaciones,
    List<FichaItemBorrador>? items,
  }) {
    return FichaBorrador(
      id: id ?? this.id,
      tipoFicha: tipoFicha ?? this.tipoFicha,
      areaOrigen: areaOrigen ?? this.areaOrigen,
      turno: turno ?? this.turno,
      prioridad: prioridad ?? this.prioridad,
      tipoAtencion: tipoAtencion ?? this.tipoAtencion,
      financiamientoId: limpiarFinanciamientoId
          ? null
          : (financiamientoId ?? this.financiamientoId),
      doctorId: limpiarDoctorId ? null : (doctorId ?? this.doctorId),
      doctorNombre: doctorNombre ?? this.doctorNombre,
      receptorId: limpiarReceptorId ? null : (receptorId ?? this.receptorId),
      recibidoPor: recibidoPor ?? this.recibidoPor,
      pacienteNombre: pacienteNombre ?? this.pacienteNombre,
      procedencia: procedencia ?? this.procedencia,
      procedenciaDetalle: procedenciaDetalle ?? this.procedenciaDetalle,
      diagnosticoMotivo: diagnosticoMotivo ?? this.diagnosticoMotivo,
      madreNombre: madreNombre ?? this.madreNombre,
      habitacion: habitacion ?? this.habitacion,
      recienNacidoApellidos:
          recienNacidoApellidos ?? this.recienNacidoApellidos,
      tipoParto: tipoParto ?? this.tipoParto,
      kitId: limpiarKit ? null : (kitId ?? this.kitId),
      kitNombre: limpiarKit ? null : (kitNombre ?? this.kitNombre),
      confirmarFaltanteKit: limpiarKit
          ? false
          : (confirmarFaltanteKit ?? this.confirmarFaltanteKit),
      observaciones: observaciones ?? this.observaciones,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() => {
        'tipo_ficha': tipoFicha.trim().toUpperCase(),
        'area_origen': areaOrigen.trim(),
        'turno': turno.trim().toUpperCase(),
        'prioridad': prioridad.trim().toUpperCase(),
        'tipo_atencion': tipoAtencion.trim().toUpperCase(),
        if (tipoAtencion.trim().toUpperCase() != 'PARTICULAR' &&
            financiamientoId != null &&
            financiamientoId!.trim().isNotEmpty)
          'financiamiento_id': financiamientoId!.trim(),
        if (doctorId != null && doctorId!.trim().isNotEmpty)
          'doctor_id': doctorId!.trim(),
        'doctor_nombre': doctorNombre.trim(),
        if (receptorId != null && receptorId!.trim().isNotEmpty)
          'receptor_id': receptorId!.trim(),
        'recibido_por': recibidoPor.trim(),
        if (tipoFicha == 'GENERAL') ...{
          'paciente_nombre': pacienteNombre.trim(),
          'procedencia': procedencia.trim().toUpperCase(),
          if (procedenciaDetalle.trim().isNotEmpty)
            'procedencia_detalle': procedenciaDetalle.trim(),
          'diagnostico_motivo': diagnosticoMotivo.trim(),
        } else ...{
          'madre_nombre': madreNombre.trim(),
          if (habitacion.trim().isNotEmpty) 'habitacion': habitacion.trim(),
          'recien_nacido_apellidos': recienNacidoApellidos.trim(),
          'tipo_parto': tipoParto.trim().toUpperCase(),
          if (diagnosticoMotivo.trim().isNotEmpty)
            'diagnostico_motivo': diagnosticoMotivo.trim(),
        },
        if (kitId != null && kitId!.trim().isNotEmpty) 'kit_id': kitId!.trim(),
        'confirmar_faltante_kit': confirmarFaltanteKit,
        if (observaciones.trim().isNotEmpty)
          'observaciones': observaciones.trim(),
        'items': items.map((i) => i.toMap()).toList(growable: false),
      };
}


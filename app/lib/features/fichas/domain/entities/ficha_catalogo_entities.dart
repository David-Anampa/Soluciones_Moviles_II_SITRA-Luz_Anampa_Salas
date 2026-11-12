/// Entidades de dominio inmutables para el registro de fichas de pedido (HU-003, HU-004, HU-005).
/// Ninguna entidad contiene valores fijos del negocio; todos provienen de Supabase.
class AreaFicha {
  final String id;
  final String codigo;
  final String codigoInterno;
  final String nombre;
  final String temaColor;
  final bool activo;

  const AreaFicha({
    required this.id,
    required this.codigo,
    required this.codigoInterno,
    required this.nombre,
    required this.temaColor,
    required this.activo,
  });

  /// Determina dinámicamente si el área corresponde a Neonatología por su código o nombre real.
  bool get esNeonatologia {
    final texto = '${codigo.toUpperCase()} ${nombre.toUpperCase()}';
    return texto.contains('NEONAT') || texto.contains('RN');
  }

  factory AreaFicha.fromMap(Map<String, dynamic> map) {
    final codigo = (map['codigo'] as String? ?? '').trim();
    return AreaFicha(
      id: map['id']?.toString() ?? '',
      codigo: codigo,
      codigoInterno: (map['codigo_interno'] as String? ?? codigo).trim(),
      nombre: (map['nombre'] as String? ?? codigo).trim(),
      temaColor: (map['tema_color'] as String? ?? 'ROJO').trim(),
      activo: map['activo'] as bool? ?? true,
    );
  }
}

class FinanciamientoFicha {
  final String id;
  final String nombre;
  final String tipo; // PARTICULAR | SEGURO | CONVENIO
  final String? descripcion;
  final double porcentajeDescuento;
  final Set<String> medicamentosCubiertos;

  const FinanciamientoFicha({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.descripcion,
    required this.porcentajeDescuento,
    required this.medicamentosCubiertos,
  });

  bool cubreMedicamento(String medicamentoId) =>
      tipo == 'PARTICULAR' || medicamentosCubiertos.contains(medicamentoId);

  double calcularDescuentoPara(String medicamentoId) {
    if (tipo == 'PARTICULAR') return 0;
    return medicamentosCubiertos.contains(medicamentoId)
        ? porcentajeDescuento
        : 0;
  }

  factory FinanciamientoFicha.fromMap(Map<String, dynamic> map) {
    final rawMeds = map['medicamentos'];
    final cubiertos = <String>{};
    if (rawMeds is List) {
      for (final item in rawMeds) {
        if (item != null) cubiertos.add(item.toString());
      }
    }
    return FinanciamientoFicha(
      id: map['id']?.toString() ?? '',
      nombre: (map['nombre'] as String? ?? '').trim(),
      tipo: (map['tipo'] as String? ?? 'PARTICULAR').trim().toUpperCase(),
      descripcion: map['descripcion'] as String?,
      porcentajeDescuento:
          (map['porcentaje_descuento'] as num?)?.toDouble() ?? 0.0,
      medicamentosCubiertos: Set.unmodifiable(cubiertos),
    );
  }
}

class DoctorFicha {
  final String id;
  final String nombre;
  final String? colegiatura;
  final String? especialidad;

  const DoctorFicha({
    required this.id,
    required this.nombre,
    this.colegiatura,
    this.especialidad,
  });

  String get etiquetaCompleta {
    final partes = <String>[nombre];
    if (colegiatura != null && colegiatura!.trim().isNotEmpty) {
      partes.add('CMP ${colegiatura!.trim()}');
    }
    if (especialidad != null && especialidad!.trim().isNotEmpty) {
      partes.add(especialidad!.trim());
    }
    return partes.join(' · ');
  }

  factory DoctorFicha.fromMap(Map<String, dynamic> map) {
    return DoctorFicha(
      id: map['id']?.toString() ?? '',
      nombre: (map['nombre'] as String? ?? '').trim(),
      colegiatura: map['colegiatura'] as String?,
      especialidad: map['especialidad'] as String?,
    );
  }
}

class ReceptorFicha {
  final String id;
  final String nombre;
  final String cargo;
  final List<String> areas;

  const ReceptorFicha({
    required this.id,
    required this.nombre,
    required this.cargo,
    required this.areas,
  });

  bool perteneceAArea(String codigoArea) =>
      areas.any((a) => a.toUpperCase() == codigoArea.toUpperCase());

  factory ReceptorFicha.fromMap(Map<String, dynamic> map) {
    final rawAreas = map['areas'];
    final listaAreas = <String>[];
    if (rawAreas is List) {
      for (final item in rawAreas) {
        if (item != null) listaAreas.add(item.toString());
      }
    }
    return ReceptorFicha(
      id: map['id']?.toString() ?? '',
      nombre: (map['nombre'] as String? ?? '').trim(),
      cargo: (map['cargo'] as String? ?? 'Enfermería / Técnico').trim(),
      areas: List.unmodifiable(listaAreas),
    );
  }
}

class MedicamentoStockFicha {
  final String id;
  final String nombre;
  final String? principioActivo;
  final String? presentacion;
  final String? laboratorio;
  final String unidad;
  final String categoria; // MEDICAMENTO | DISPOSITIVO_MEDICO
  final double? precioKairos;
  final bool activo;
  final int farmaciaDisponible;
  final int almacenDisponible;
  final int enTransito;

  const MedicamentoStockFicha({
    required this.id,
    required this.nombre,
    this.principioActivo,
    this.presentacion,
    this.laboratorio,
    required this.unidad,
    required this.categoria,
    this.precioKairos,
    required this.activo,
    required this.farmaciaDisponible,
    required this.almacenDisponible,
    required this.enTransito,
  });

  /// RF-004: solo los ítems con stock disponible > 0 en Farmacia pueden seleccionarse individualmente.
  bool get seleccionableIndividualmente => activo && farmaciaDisponible > 0;

  bool get esDispositivoMedico => categoria == 'DISPOSITIVO_MEDICO';

  String get subtituloDetalle {
    final partes = <String>[
      if (presentacion != null && presentacion!.trim().isNotEmpty)
        presentacion!.trim(),
      if (laboratorio != null && laboratorio!.trim().isNotEmpty)
        laboratorio!.trim(),
    ];
    return partes.isEmpty ? unidad : partes.join(' · ');
  }

  factory MedicamentoStockFicha.fromMap(Map<String, dynamic> map) {
    return MedicamentoStockFicha(
      id: (map['id'] ?? map['medicamento_id'])?.toString() ?? '',
      nombre:
          (map['nombre'] ?? map['nombre_comercial'] as String? ?? '').trim(),
      principioActivo: map['principio_activo'] as String?,
      presentacion: map['presentacion'] as String?,
      laboratorio: map['laboratorio'] as String?,
      unidad: (map['unidad'] as String? ?? 'UNIDAD').trim(),
      categoria: (map['categoria'] as String? ?? 'MEDICAMENTO')
          .trim()
          .toUpperCase(),
      precioKairos: (map['precio_kairos'] as num?)?.toDouble(),
      activo: map['activo'] as bool? ?? true,
      farmaciaDisponible:
          (map['farmacia_disponible'] as num?)?.toInt() ?? 0,
      almacenDisponible:
          (map['almacen_disponible'] as num?)?.toInt() ?? 0,
      enTransito: (map['en_transito'] as num?)?.toInt() ?? 0,
    );
  }
}

class KitItemFicha {
  final String medicamentoId;
  final String nombreComercial;
  final String? principioActivo;
  final String? presentacion;
  final String? laboratorio;
  final String unidad;
  final String categoria;
  final double? precioKairos;
  final int cantidad;
  final bool activo;
  final int farmaciaDisponible;
  final int almacenDisponible;
  final int enTransito;

  const KitItemFicha({
    required this.medicamentoId,
    required this.nombreComercial,
    this.principioActivo,
    this.presentacion,
    this.laboratorio,
    required this.unidad,
    required this.categoria,
    this.precioKairos,
    required this.cantidad,
    required this.activo,
    required this.farmaciaDisponible,
    required this.almacenDisponible,
    required this.enTransito,
  });

  bool get tieneStockSuficiente => activo && farmaciaDisponible >= cantidad;

  int get faltanteEnFarmacia =>
      cantidad > farmaciaDisponible ? cantidad - farmaciaDisponible : 0;

  factory KitItemFicha.fromMap(Map<String, dynamic> map) {
    return KitItemFicha(
      medicamentoId: map['medicamento_id']?.toString() ?? '',
      nombreComercial: (map['nombre_comercial'] as String? ?? '').trim(),
      principioActivo: map['principio_activo'] as String?,
      presentacion: map['presentacion'] as String?,
      laboratorio: map['laboratorio'] as String?,
      unidad: (map['unidad'] as String? ?? 'UNIDAD').trim(),
      categoria: (map['categoria'] as String? ?? 'MEDICAMENTO')
          .trim()
          .toUpperCase(),
      precioKairos: (map['precio_kairos'] as num?)?.toDouble(),
      cantidad: (map['cantidad'] as num?)?.toInt() ?? 1,
      activo: map['activo'] as bool? ?? true,
      farmaciaDisponible:
          (map['farmacia_disponible'] as num?)?.toInt() ?? 0,
      almacenDisponible:
          (map['almacen_disponible'] as num?)?.toInt() ?? 0,
      enTransito: (map['en_transito'] as num?)?.toInt() ?? 0,
    );
  }
}

class KitDisponibleFicha {
  final String id;
  final String nombre;
  final String? descripcion;
  final String areaDestino;
  final String areaNombre;
  final List<KitItemFicha> items;

  const KitDisponibleFicha({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.areaDestino,
    required this.areaNombre,
    required this.items,
  });

  bool get tieneStockCompleto =>
      items.isNotEmpty && items.every((i) => i.tieneStockSuficiente);

  List<KitItemFicha> get itemsConFaltante =>
      items.where((i) => !i.tieneStockSuficiente).toList(growable: false);

  factory KitDisponibleFicha.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    final parsedItems = <KitItemFicha>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map) {
          parsedItems.add(
            KitItemFicha.fromMap(Map<String, dynamic>.from(raw)),
          );
        }
      }
    }
    return KitDisponibleFicha(
      id: map['id']?.toString() ?? '',
      nombre: (map['nombre'] as String? ?? '').trim(),
      descripcion: map['descripcion'] as String?,
      areaDestino: (map['area_destino'] as String? ?? '').trim(),
      areaNombre: (map['area_nombre'] as String? ?? '').trim(),
      items: List.unmodifiable(parsedItems),
    );
  }
}

class ContextoRegistroFicha {
  final String rol;
  final String usuarioId;
  final String usuarioNombre;
  final List<AreaFicha> areas;
  final List<FinanciamientoFicha> financiamientos;
  final List<DoctorFicha> doctores;
  final List<ReceptorFicha> receptores;
  final List<KitDisponibleFicha> kits;

  const ContextoRegistroFicha({
    required this.rol,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.areas,
    required this.financiamientos,
    required this.doctores,
    required this.receptores,
    required this.kits,
  });

  List<FinanciamientoFicha> financiamientosPorTipo(String tipoAtencion) =>
      financiamientos
          .where((f) => f.tipo == tipoAtencion.toUpperCase())
          .toList(growable: false);

  List<ReceptorFicha> receptoresParaArea(String codigoArea) {
    final filtrados = receptores
        .where((r) => r.perteneceAArea(codigoArea))
        .toList(growable: false);
    return filtrados.isNotEmpty ? filtrados : receptores;
  }

  List<KitDisponibleFicha> kitsParaArea(String codigoArea) => kits
      .where((k) => k.areaDestino.toUpperCase() == codigoArea.toUpperCase())
      .toList(growable: false);

  factory ContextoRegistroFicha.fromMap(Map<String, dynamic> map) {
    List<T> parseList<T>(
      dynamic raw,
      T Function(Map<String, dynamic>) builder,
    ) {
      if (raw is! List) return const [];
      return List.unmodifiable(
        raw
            .whereType<Map>()
            .map((e) => builder(Map<String, dynamic>.from(e))),
      );
    }

    return ContextoRegistroFicha(
      rol: (map['rol'] as String? ?? '').trim(),
      usuarioId: map['usuario_id']?.toString() ?? '',
      usuarioNombre: (map['usuario_nombre'] as String? ?? '').trim(),
      areas: parseList(map['areas'], AreaFicha.fromMap),
      financiamientos: parseList(
        map['financiamientos'],
        FinanciamientoFicha.fromMap,
      ),
      doctores: parseList(map['doctores'], DoctorFicha.fromMap),
      receptores: parseList(map['receptores'], ReceptorFicha.fromMap),
      kits: parseList(map['kits'], KitDisponibleFicha.fromMap),
    );
  }
}

/// Desglose de lote despachado aplicando FEFO en la entrega de una ficha (HU-007 / HU-010 / HU-011).
class FichaItemLoteDespachado {
  final String id;
  final String loteId;
  final String numeroLote;
  final DateTime? fechaVencimiento;
  final int cantidad;
  final int cantidadReingresada;
  final double? costoCompraLote;
  final double? precioVentaLote;
  final DateTime? createdAt;
  final DateTime? reingresadoAt;

  const FichaItemLoteDespachado({
    required this.id,
    required this.loteId,
    required this.numeroLote,
    this.fechaVencimiento,
    required this.cantidad,
    this.cantidadReingresada = 0,
    this.costoCompraLote,
    this.precioVentaLote,
    this.createdAt,
    this.reingresadoAt,
  });

  bool get fueReingresado => cantidadReingresada > 0;

  factory FichaItemLoteDespachado.fromMap(Map<String, dynamic> map) {
    return FichaItemLoteDespachado(
      id: (map['id'] ?? '').toString(),
      loteId: (map['lote_id'] ?? '').toString(),
      numeroLote: (map['numero_lote'] ?? '-').toString(),
      fechaVencimiento: DateTime.tryParse(
        (map['fecha_vencimiento'] ?? '').toString(),
      ),
      cantidad: (map['cantidad'] as num?)?.toInt() ?? 0,
      cantidadReingresada: (map['cantidad_reingresada'] as num?)?.toInt() ?? 0,
      costoCompraLote: (map['costo_compra_lote'] as num?)?.toDouble(),
      precioVentaLote: (map['precio_venta_lote'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString())
          ?.toLocal(),
      reingresadoAt: DateTime.tryParse(
        (map['reingresado_at'] ?? '').toString(),
      )?.toLocal(),
    );
  }
}

/// Evento cronológico del historial de auditoría de una ficha (HU-007).
class EventoHistorialFicha {
  final String id;
  final String tipoEvento;
  final DateTime? fechaEvento;
  final String? usuarioId;
  final String usuarioNombre;
  final String? usuarioRol;
  final String? areaOrigen;
  final String? areaDestino;
  final String? medicamentoId;
  final String? medicamentoNombre;
  final String? loteId;
  final String? numeroLote;
  final int? cantidad;
  final String descripcion;
  final Map<String, dynamic> detallesExtra;

  const EventoHistorialFicha({
    required this.id,
    required this.tipoEvento,
    this.fechaEvento,
    this.usuarioId,
    required this.usuarioNombre,
    this.usuarioRol,
    this.areaOrigen,
    this.areaDestino,
    this.medicamentoId,
    this.medicamentoNombre,
    this.loteId,
    this.numeroLote,
    this.cantidad,
    required this.descripcion,
    this.detallesExtra = const {},
  });

  String get etiquetaEvento {
    switch (tipoEvento) {
      case 'FICHA_CREADA':
        return 'Ficha registrada';
      case 'FICHA_ACTUALIZADA':
        return 'Ficha editada';
      case 'FICHA_EN_PREPARACION':
        return 'En preparación en Farmacia';
      case 'FICHA_DESPACHO_ACTUALIZADO':
        return 'Cantidades de despacho actualizadas';
      case 'FICHA_LISTA_PARA_RECOJO':
        return 'Lista para recojo';
      case 'CONSUMO_FICHA_AREA':
        return 'Descuento por lote (FEFO)';
      case 'FICHA_ENTREGADA':
        return 'Entrega confirmada';
      case 'REINGRESO_ANULACION_FICHA':
        return 'Contra-asiento de reingreso a Farmacia';
      case 'FICHA_ANULADA':
        return 'Ficha anulada';
      case 'FICHA_ANULADA_CON_CONTRAASIENTO':
        return 'Ficha anulada con contra-asiento';
      default:
        return tipoEvento.replaceAll('_', ' ');
    }
  }

  factory EventoHistorialFicha.fromMap(Map<String, dynamic> map) {
    final rawExtra = map['detalles_extra'];
    return EventoHistorialFicha(
      id: (map['id'] ?? '').toString(),
      tipoEvento: (map['tipo_evento'] ?? '').toString(),
      fechaEvento: DateTime.tryParse(
        (map['fecha_evento'] ?? '').toString(),
      )?.toLocal(),
      usuarioId: map['usuario_id']?.toString(),
      usuarioNombre: (map['usuario_nombre'] ?? 'Sistema').toString(),
      usuarioRol: map['usuario_rol']?.toString(),
      areaOrigen: map['area_origen']?.toString(),
      areaDestino: map['area_destino']?.toString(),
      medicamentoId: map['medicamento_id']?.toString(),
      medicamentoNombre: map['medicamento_nombre']?.toString(),
      loteId: map['lote_id']?.toString(),
      numeroLote: map['numero_lote']?.toString(),
      cantidad: (map['cantidad'] as num?)?.toInt(),
      descripcion: (map['descripcion'] ?? '').toString(),
      detallesExtra: rawExtra is Map
          ? Map<String, dynamic>.from(rawExtra)
          : const <String, dynamic>{},
    );
  }
}

/// Contrato refinado de movimiento de Kardex por medicamento y lote para Sprint 8 (HU-025).
class MovimientoKardexContratoHu025 {
  final String id;
  final String tipoEvento;
  final String naturalezaMovimiento; // ENTRADA | SALIDA | TRANSFERENCIA | AJUSTE
  final DateTime? fechaEvento;
  final String usuarioNombre;
  final String? usuarioRol;
  final String? areaOrigen;
  final String? areaDestino;
  final String? loteId;
  final String? numeroLote;
  final DateTime? fechaVencimiento;
  final int cantidad;
  final String? entidadReferenciaId;
  final String? numeroFicha;
  final String descripcion;

  const MovimientoKardexContratoHu025({
    required this.id,
    required this.tipoEvento,
    required this.naturalezaMovimiento,
    this.fechaEvento,
    required this.usuarioNombre,
    this.usuarioRol,
    this.areaOrigen,
    this.areaDestino,
    this.loteId,
    this.numeroLote,
    this.fechaVencimiento,
    required this.cantidad,
    this.entidadReferenciaId,
    this.numeroFicha,
    required this.descripcion,
  });

  factory MovimientoKardexContratoHu025.fromMap(Map<String, dynamic> map) {
    return MovimientoKardexContratoHu025(
      id: (map['id'] ?? '').toString(),
      tipoEvento: (map['tipo_evento'] ?? '').toString(),
      naturalezaMovimiento:
          (map['naturaleza_movimiento'] ?? 'AJUSTE').toString(),
      fechaEvento: DateTime.tryParse(
        (map['fecha_evento'] ?? '').toString(),
      )?.toLocal(),
      usuarioNombre: (map['usuario_nombre'] ?? 'Sistema').toString(),
      usuarioRol: map['usuario_rol']?.toString(),
      areaOrigen: map['area_origen']?.toString(),
      areaDestino: map['area_destino']?.toString(),
      loteId: map['lote_id']?.toString(),
      numeroLote: map['numero_lote']?.toString(),
      fechaVencimiento: DateTime.tryParse(
        (map['fecha_vencimiento'] ?? '').toString(),
      ),
      cantidad: (map['cantidad'] as num?)?.toInt() ?? 0,
      entidadReferenciaId: map['entidad_referencia_id']?.toString(),
      numeroFicha: map['numero_ficha']?.toString(),
      descripcion: (map['descripcion'] ?? '').toString(),
    );
  }
}

class FichaRegistradaItem {
  final String id;
  final String medicamentoId;
  final String nombreComercial;
  final String? principioActivo;
  final String? presentacion;
  final String? laboratorio;
  final String unidad;
  final int cantidadSolicitada;
  final int cantidadEntregada;
  final String? observacionItem;
  final String categoriaItem;
  final bool origenKit;
  final double? precioKairosAplicado;
  final double? porcentajeDescuentoAplicado;
  final double? precioUnitarioAplicado;
  final double? costoUnitarioAplicado;
  final int farmaciaDisponible;
  final List<FichaItemLoteDespachado> lotesDespachados;

  const FichaRegistradaItem({
    required this.id,
    required this.medicamentoId,
    required this.nombreComercial,
    this.principioActivo,
    this.presentacion,
    this.laboratorio,
    required this.unidad,
    required this.cantidadSolicitada,
    required this.cantidadEntregada,
    this.observacionItem,
    required this.categoriaItem,
    required this.origenKit,
    this.precioKairosAplicado,
    this.porcentajeDescuentoAplicado,
    this.precioUnitarioAplicado,
    this.costoUnitarioAplicado,
    this.farmaciaDisponible = 0,
    this.lotesDespachados = const [],
  });

  bool get esDispositivoMedico => categoriaItem == 'DISPOSITIVO_MEDICO';

  bool get esDespachoParcial => cantidadEntregada < cantidadSolicitada;

  double get subtotalSolicitado =>
      (precioUnitarioAplicado ?? precioKairosAplicado ?? 0) *
      cantidadSolicitada;

  double get subtotalEntregado =>
      (precioUnitarioAplicado ?? precioKairosAplicado ?? 0) * cantidadEntregada;

  factory FichaRegistradaItem.fromMap(Map<String, dynamic> map) {
    final rawLotes = map['lotes_despachados'];
    final parsedLotes = <FichaItemLoteDespachado>[];
    if (rawLotes is List) {
      for (final raw in rawLotes) {
        if (raw is Map) {
          parsedLotes.add(
            FichaItemLoteDespachado.fromMap(Map<String, dynamic>.from(raw)),
          );
        }
      }
    }
    return FichaRegistradaItem(
      id: map['id']?.toString() ?? '',
      medicamentoId: map['medicamento_id']?.toString() ?? '',
      nombreComercial: (map['nombre_comercial'] as String? ?? '').trim(),
      principioActivo: map['principio_activo'] as String?,
      presentacion: map['presentacion'] as String?,
      laboratorio: map['laboratorio'] as String?,
      unidad: (map['unidad'] as String? ?? 'UNIDAD').trim(),
      cantidadSolicitada:
          (map['cantidad_solicitada'] as num?)?.toInt() ?? 1,
      cantidadEntregada: (map['cantidad_entregada'] as num?)?.toInt() ?? 0,
      observacionItem: map['observacion_item'] as String?,
      categoriaItem:
          (map['categoria_item'] as String? ?? 'MEDICAMENTO').toUpperCase(),
      origenKit: map['origen_kit'] as bool? ?? false,
      precioKairosAplicado:
          (map['precio_kairos_aplicado'] as num?)?.toDouble(),
      porcentajeDescuentoAplicado:
          (map['porcentaje_descuento_aplicado'] as num?)?.toDouble(),
      precioUnitarioAplicado:
          (map['precio_unitario_aplicado'] as num?)?.toDouble(),
      costoUnitarioAplicado:
          (map['costo_unitario_aplicado'] as num?)?.toDouble(),
      farmaciaDisponible:
          (map['farmacia_disponible'] as num?)?.toInt() ?? 0,
      lotesDespachados: List.unmodifiable(parsedLotes),
    );
  }
}

class FichaRegistrada {
  final String id;
  final String numeroFicha;
  final String tipo; // KIT | INDIVIDUAL
  final String tipoFicha; // GENERAL | NEONATOLOGIA
  final String? kitId;
  final String? kitNombre;
  final String areaOrigen;
  final String areaNombre;
  final String areaTemaColor;
  final String turno;
  final String prioridad;
  final String estado;
  final String tipoAtencion;
  final String? financiamientoId;
  final String? financiamientoNombreAplicado;
  final String? doctorId;
  final String? doctorNombre;
  final String pacienteNombre;
  final String? procedencia;
  final String? procedenciaDetalle;
  final String? diagnosticoMotivo;
  final String? madreNombre;
  final String? habitacion;
  final String? recienNacidoApellidos;
  final String? tipoParto;
  final String? receptorId;
  final String? recibidoPor;
  final String? observaciones;
  final String? notasFarmacia;
  final String? observacionEntrega;
  final String? solicitadoPor;
  final String? solicitadoPorNombre;
  final String? preparadoPor;
  final String? preparadoPorNombre;
  final String? entregadoPor;
  final String? entregadoPorNombre;
  final String? anuladoPor;
  final String? anuladoPorNombre;
  final String? motivoAnulacion;
  final DateTime fechaCreacion;
  final DateTime? fechaPreparacion;
  final DateTime? fechaListoRecojo;
  final DateTime? fechaEntrega;
  final DateTime? fechaAnulacion;
  final DateTime? updatedAt;
  final List<FichaRegistradaItem> items;
  final List<EventoHistorialFicha> historial;

  const FichaRegistrada({
    required this.id,
    required this.numeroFicha,
    required this.tipo,
    required this.tipoFicha,
    this.kitId,
    this.kitNombre,
    required this.areaOrigen,
    required this.areaNombre,
    required this.areaTemaColor,
    required this.turno,
    required this.prioridad,
    required this.estado,
    required this.tipoAtencion,
    this.financiamientoId,
    this.financiamientoNombreAplicado,
    this.doctorId,
    this.doctorNombre,
    required this.pacienteNombre,
    this.procedencia,
    this.procedenciaDetalle,
    this.diagnosticoMotivo,
    this.madreNombre,
    this.habitacion,
    this.recienNacidoApellidos,
    this.tipoParto,
    this.receptorId,
    this.recibidoPor,
    this.observaciones,
    this.notasFarmacia,
    this.observacionEntrega,
    this.solicitadoPor,
    this.solicitadoPorNombre,
    this.preparadoPor,
    this.preparadoPorNombre,
    this.entregadoPor,
    this.entregadoPorNombre,
    this.anuladoPor,
    this.anuladoPorNombre,
    this.motivoAnulacion,
    required this.fechaCreacion,
    this.fechaPreparacion,
    this.fechaListoRecojo,
    this.fechaEntrega,
    this.fechaAnulacion,
    this.updatedAt,
    required this.items,
    this.historial = const [],
  });

  bool get esEditable => estado == 'SOLICITADO';

  bool get esNeonatologia => tipoFicha == 'NEONATOLOGIA';

  bool get esUrgente => prioridad == 'URGENTE';

  List<FichaRegistradaItem> get medicamentos => items
      .where((i) => !i.esDispositivoMedico)
      .toList(growable: false);

  List<FichaRegistradaItem> get dispositivosMedicos => items
      .where((i) => i.esDispositivoMedico)
      .toList(growable: false);

  int get totalUnidadesSolicitadas =>
      items.fold<int>(0, (acc, i) => acc + i.cantidadSolicitada);

  int get totalUnidadesEntregadas =>
      items.fold<int>(0, (acc, i) => acc + i.cantidadEntregada);

  double get montoTotalSolicitado =>
      items.fold<double>(0, (acc, i) => acc + i.subtotalSolicitado);

  double get montoTotalEntregado =>
      items.fold<double>(0, (acc, i) => acc + i.subtotalEntregado);

  bool get tieneDespachoParcial =>
      estado != 'SOLICITADO' &&
      items.any((i) => i.cantidadEntregada < i.cantidadSolicitada);

  String get etiquetaEstado {
    switch (estado) {
      case 'SOLICITADO':
        return 'Solicitado';
      case 'EN_PREPARACION':
        return 'En preparación';
      case 'LISTO_PARA_RECOJO':
        return 'Listo para recojo';
      case 'ENTREGADO':
        return 'Entregado';
      case 'CANCELADO':
        return 'Anulado';
      default:
        return estado;
    }
  }

  /// Permisos de operación según rol y estado actual (HU-008 a HU-011).
  bool puedeIniciarPreparacion(String rol) =>
      estado == 'SOLICITADO' &&
      (rol == 'FARMACIA' || rol == 'ADMINISTRADOR');

  bool puedeEditarDespacho(String rol) =>
      (estado == 'SOLICITADO' ||
          estado == 'EN_PREPARACION' ||
          estado == 'LISTO_PARA_RECOJO') &&
      (rol == 'FARMACIA' || rol == 'ADMINISTRADOR');

  bool puedeMarcarListoRecojo(String rol) =>
      (estado == 'SOLICITADO' || estado == 'EN_PREPARACION') &&
      (rol == 'FARMACIA' || rol == 'ADMINISTRADOR');

  bool puedeConfirmarEntrega({
    required String rol,
    List<String> areasUsuario = const [],
  }) {
    if (estado == 'LISTO_PARA_RECOJO') {
      if (rol == 'FARMACIA' || rol == 'ADMINISTRADOR') return true;
      if (rol == 'ENFERMERIA') {
        return areasUsuario.isEmpty || areasUsuario.contains(areaOrigen);
      }
    }
    if (estado == 'EN_PREPARACION' &&
        (rol == 'FARMACIA' || rol == 'ADMINISTRADOR')) {
      return true;
    }
    return false;
  }

  bool puedeAnular({
    required String rol,
    List<String> areasUsuario = const [],
  }) {
    if (estado == 'CANCELADO') return false;
    if (rol == 'FARMACIA' || rol == 'ADMINISTRADOR') return true;
    if (rol == 'ENFERMERIA' && estado == 'SOLICITADO') {
      return areasUsuario.isEmpty || areasUsuario.contains(areaOrigen);
    }
    return false;
  }

  factory FichaRegistrada.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    final items = <FichaRegistradaItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map) {
          items.add(
            FichaRegistradaItem.fromMap(Map<String, dynamic>.from(raw)),
          );
        }
      }
    }
    final rawHistorial = map['historial'];
    final historial = <EventoHistorialFicha>[];
    if (rawHistorial is List) {
      for (final raw in rawHistorial) {
        if (raw is Map) {
          historial.add(
            EventoHistorialFicha.fromMap(Map<String, dynamic>.from(raw)),
          );
        }
      }
    }
    return FichaRegistrada(
      id: map['id']?.toString() ?? '',
      numeroFicha: (map['numero_ficha'] as String? ?? '').trim(),
      tipo: (map['tipo'] as String? ?? 'INDIVIDUAL').trim(),
      tipoFicha: (map['tipo_ficha'] as String? ?? 'GENERAL').trim(),
      kitId: map['kit_id']?.toString(),
      kitNombre: map['kit_nombre'] as String?,
      areaOrigen: (map['area_origen'] as String? ?? '').trim(),
      areaNombre: (map['area_nombre'] as String? ??
              map['area_origen'] as String? ??
              '')
          .trim(),
      areaTemaColor: (map['area_tema_color'] as String? ?? 'ROJO').trim(),
      turno: (map['turno'] as String? ?? 'DIA').trim(),
      prioridad: (map['prioridad'] as String? ?? 'NORMAL').trim(),
      estado: (map['estado'] as String? ?? 'SOLICITADO').trim(),
      tipoAtencion: (map['tipo_atencion'] as String? ?? 'PARTICULAR').trim(),
      financiamientoId: map['financiamiento_id']?.toString(),
      financiamientoNombreAplicado:
          map['financiamiento_nombre_aplicado'] as String?,
      doctorId: map['doctor_id']?.toString(),
      doctorNombre: map['doctor_nombre'] as String?,
      pacienteNombre: (map['paciente_nombre'] as String? ?? '').trim(),
      procedencia: map['procedencia'] as String?,
      procedenciaDetalle: map['procedencia_detalle'] as String?,
      diagnosticoMotivo: map['diagnostico_motivo'] as String?,
      madreNombre: map['madre_nombre'] as String?,
      habitacion: map['habitacion'] as String?,
      recienNacidoApellidos: map['recien_nacido_apellidos'] as String?,
      tipoParto: map['tipo_parto'] as String?,
      receptorId: map['receptor_id']?.toString(),
      recibidoPor: map['recibido_por'] as String?,
      observaciones: map['observaciones'] as String?,
      notasFarmacia: map['notas_farmacia'] as String?,
      observacionEntrega: map['observacion_entrega'] as String?,
      solicitadoPor: map['solicitado_por']?.toString(),
      solicitadoPorNombre: map['solicitado_por_nombre'] as String?,
      preparadoPor: map['preparado_por']?.toString(),
      preparadoPorNombre: map['preparado_por_nombre'] as String?,
      entregadoPor: map['entregado_por']?.toString(),
      entregadoPorNombre: map['entregado_por_nombre'] as String?,
      anuladoPor: map['anulado_por']?.toString(),
      anuladoPorNombre: map['anulado_por_nombre'] as String?,
      motivoAnulacion: map['motivo_anulacion'] as String?,
      fechaCreacion: DateTime.tryParse(map['fecha_creacion']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
      fechaPreparacion:
          DateTime.tryParse(map['fecha_preparacion']?.toString() ?? '')
              ?.toLocal(),
      fechaListoRecojo:
          DateTime.tryParse(map['fecha_listo_recojo']?.toString() ?? '')
              ?.toLocal(),
      fechaEntrega:
          DateTime.tryParse(map['fecha_entrega']?.toString() ?? '')?.toLocal(),
      fechaAnulacion:
          DateTime.tryParse(map['fecha_anulacion']?.toString() ?? '')
              ?.toLocal(),
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '')?.toLocal(),
      items: List.unmodifiable(items),
      historial: List.unmodifiable(historial),
    );
  }
}

/// Filtros inmutables para el listado de fichas de pedido (HU-006).
class FiltrosListadoFichas {
  final String area; // TODAS o código de área
  final String estado; // TODOS | SOLICITADO | EN_PREPARACION | LISTO_PARA_RECOJO | ENTREGADO | CANCELADO
  final String tipoFicha; // TODOS | GENERAL | NEONATOLOGIA
  final String prioridad; // TODAS | NORMAL | URGENTE
  final String turno; // TODOS | DIA | TARDE | NOCHE
  final String busqueda;

  const FiltrosListadoFichas({
    this.area = 'TODAS',
    this.estado = 'TODOS',
    this.tipoFicha = 'TODOS',
    this.prioridad = 'TODAS',
    this.turno = 'TODOS',
    this.busqueda = '',
  });

  bool get tieneFiltrosActivos =>
      area != 'TODAS' ||
      estado != 'TODOS' ||
      tipoFicha != 'TODOS' ||
      prioridad != 'TODAS' ||
      turno != 'TODOS' ||
      busqueda.trim().isNotEmpty;

  FiltrosListadoFichas copyWith({
    String? area,
    String? estado,
    String? tipoFicha,
    String? prioridad,
    String? turno,
    String? busqueda,
  }) {
    return FiltrosListadoFichas(
      area: area ?? this.area,
      estado: estado ?? this.estado,
      tipoFicha: tipoFicha ?? this.tipoFicha,
      prioridad: prioridad ?? this.prioridad,
      turno: turno ?? this.turno,
      busqueda: busqueda ?? this.busqueda,
    );
  }
}

/// Línea editable para registrar la cantidad despachada y observación por ítem en Farmacia (HU-009).
class ItemDespachoEdicion {
  final String itemId;
  final String medicamentoId;
  final String nombreComercial;
  final int cantidadSolicitada;
  final int cantidadEntregada;
  final int farmaciaDisponible;
  final String observacionItem;

  const ItemDespachoEdicion({
    required this.itemId,
    required this.medicamentoId,
    required this.nombreComercial,
    required this.cantidadSolicitada,
    required this.cantidadEntregada,
    required this.farmaciaDisponible,
    this.observacionItem = '',
  });

  bool get esDespachoParcial => cantidadEntregada < cantidadSolicitada;

  bool get superaStockFarmacia => cantidadEntregada > farmaciaDisponible;

  ItemDespachoEdicion copyWith({
    int? cantidadEntregada,
    int? farmaciaDisponible,
    String? observacionItem,
  }) {
    return ItemDespachoEdicion(
      itemId: itemId,
      medicamentoId: medicamentoId,
      nombreComercial: nombreComercial,
      cantidadSolicitada: cantidadSolicitada,
      cantidadEntregada: cantidadEntregada ?? this.cantidadEntregada,
      farmaciaDisponible: farmaciaDisponible ?? this.farmaciaDisponible,
      observacionItem: observacionItem ?? this.observacionItem,
    );
  }

  Map<String, dynamic> toMap() => {
        'item_id': itemId,
        'medicamento_id': medicamentoId,
        'cantidad_entregada': cantidadEntregada,
        if (observacionItem.trim().isNotEmpty)
          'observacion_item': observacionItem.trim(),
      };
}


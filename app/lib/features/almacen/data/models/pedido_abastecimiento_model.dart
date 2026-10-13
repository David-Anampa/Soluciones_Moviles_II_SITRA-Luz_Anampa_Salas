import '../../domain/entities/pedido_abastecimiento_entity.dart';

class PedidoAbastecimientoItemModel extends PedidoAbastecimientoItemEntity {
  const PedidoAbastecimientoItemModel({
    required super.id,
    required super.pedidoId,
    required super.medicamentoId,
    required super.nombreMedicamento,
    super.formaFarmaceutica,
    required super.cantidadSolicitada,
    super.cantidadDespachada,
    super.loteId,
    super.cantidadRecibida,
  });

  factory PedidoAbastecimientoItemModel.fromMap(Map<String, dynamic> map) {
    final med = map['medicamento'] as Map<String, dynamic>?;

    return PedidoAbastecimientoItemModel(
      id: map['id']?.toString() ?? '',
      pedidoId: map['pedido_id']?.toString() ?? '',
      medicamentoId: map['medicamento_id']?.toString() ?? '',
      nombreMedicamento:
          med?['nombre_comercial']?.toString() ?? 'Medicamento Solicitado',
      formaFarmaceutica: med?['presentacion']?.toString() ?? '',
      cantidadSolicitada: (map['cantidad_solicitada'] as num?)?.toInt() ?? 0,
      cantidadDespachada: (map['cantidad_despachada'] as num?)?.toInt() ?? 0,
      loteId: map['lote_id']?.toString(),
      cantidadRecibida: (map['cantidad_recibida'] as num?)?.toInt(),
    );
  }
}

class PedidoAbastecimientoModel extends PedidoAbastecimientoEntity {
  const PedidoAbastecimientoModel({
    required super.id,
    required super.codigo,
    super.solicitanteId,
    super.solicitanteNombre,
    super.responsableAlmacenId,
    super.responsableFarmaciaId,
    super.areaOrigen,
    super.areaDestino,
    super.estado,
    super.turno,
    super.justificacion,
    super.modalidadEntrega,
    super.confirmadoAlmacen,
    super.confirmadoFarmacia,
    super.notas,
    super.notasAlmacen,
    super.motivoCancelacion,
    super.motivoRechazo,
    super.observacionRecepcion,
    super.canceladoPorNombre,
    super.rechazadoPorNombre,
    super.fechaRechazo,
    required super.fechaSolicitud,
    super.fechaToma,
    super.fechaListo,
    super.fechaDespacho,
    super.fechaConfirmacionAlmacen,
    super.fechaConfirmacionFarmacia,
    super.fechaCancelacion,
    super.fechaCompletado,
    super.items,
  });

  factory PedidoAbastecimientoModel.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    final itemsParsed = rawItems
        .map(
          (i) =>
              PedidoAbastecimientoItemModel.fromMap(i as Map<String, dynamic>),
        )
        .toList();

    final profile = map['solicitante'] as Map<String, dynamic>?;

    return PedidoAbastecimientoModel(
      id: map['id']?.toString() ?? '',
      codigo: map['codigo']?.toString() ?? 'PED-2026',
      solicitanteId: map['solicitante_id']?.toString(),
      solicitanteNombre:
          profile?['nombre']?.toString() ?? 'Guardia de Farmacia',
      responsableAlmacenId: map['responsable_almacen_id']?.toString(),
      responsableFarmaciaId: map['responsable_farmacia_id']?.toString(),
      areaOrigen: map['area_origen']?.toString() ?? 'FARMACIA',
      areaDestino: map['area_destino']?.toString() ?? 'ALMACEN',
      estado: map['estado']?.toString() ?? 'PENDIENTE',
      turno: map['turno']?.toString() ?? 'DIA',
      justificacion: map['justificacion']?.toString() ?? 'RELLENAR_STOCK',
      modalidadEntrega: map['modalidad_entrega']?.toString(),
      confirmadoAlmacen: map['confirmado_almacen'] as bool? ?? false,
      confirmadoFarmacia: map['confirmado_farmacia'] as bool? ?? false,
      notas: map['notas']?.toString(),
      notasAlmacen: map['notas_almacen']?.toString(),
      motivoCancelacion: map['motivo_cancelacion']?.toString(),
      motivoRechazo: map['motivo_rechazo']?.toString(),
      observacionRecepcion: map['observacion_recepcion']?.toString(),
      canceladoPorNombre:
          (map['cancelado_por_perfil'] as Map<String, dynamic>?)?['nombre']
              ?.toString(),
      rechazadoPorNombre:
          (map['rechazado_por_perfil'] as Map<String, dynamic>?)?['nombre']
              ?.toString(),
      fechaRechazo: DateTime.tryParse(
        map['fecha_rechazo']?.toString() ?? '',
      )?.toLocal(),
      fechaSolicitud: map['fecha_solicitud'] != null
          ? DateTime.tryParse(map['fecha_solicitud'].toString())?.toLocal() ??
                DateTime.now()
          : DateTime.now(),
      fechaToma: map['fecha_toma'] != null
          ? DateTime.tryParse(map['fecha_toma'].toString())?.toLocal()
          : null,
      fechaListo: map['fecha_listo'] != null
          ? DateTime.tryParse(map['fecha_listo'].toString())?.toLocal()
          : null,
      fechaDespacho: map['fecha_despacho'] != null
          ? DateTime.tryParse(map['fecha_despacho'].toString())?.toLocal()
          : null,
      fechaConfirmacionAlmacen: map['fecha_confirmacion_almacen'] != null
          ? DateTime.tryParse(
              map['fecha_confirmacion_almacen'].toString(),
            )?.toLocal()
          : null,
      fechaConfirmacionFarmacia: map['fecha_confirmacion_farmacia'] != null
          ? DateTime.tryParse(
              map['fecha_confirmacion_farmacia'].toString(),
            )?.toLocal()
          : null,
      fechaCancelacion: map['fecha_cancelacion'] != null
          ? DateTime.tryParse(map['fecha_cancelacion'].toString())?.toLocal()
          : null,
      fechaCompletado: map['fecha_completado'] != null
          ? DateTime.tryParse(map['fecha_completado'].toString())?.toLocal()
          : null,
      items: itemsParsed,
    );
  }
}

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

class FichaRegistradaItem {
  final String id;
  final String medicamentoId;
  final String nombreComercial;
  final String? presentacion;
  final String? laboratorio;
  final String unidad;
  final int cantidadSolicitada;
  final int cantidadEntregada;
  final String categoriaItem;
  final bool origenKit;
  final double? precioKairosAplicado;
  final double? porcentajeDescuentoAplicado;
  final double? precioUnitarioAplicado;

  const FichaRegistradaItem({
    required this.id,
    required this.medicamentoId,
    required this.nombreComercial,
    this.presentacion,
    this.laboratorio,
    required this.unidad,
    required this.cantidadSolicitada,
    required this.cantidadEntregada,
    required this.categoriaItem,
    required this.origenKit,
    this.precioKairosAplicado,
    this.porcentajeDescuentoAplicado,
    this.precioUnitarioAplicado,
  });

  factory FichaRegistradaItem.fromMap(Map<String, dynamic> map) {
    return FichaRegistradaItem(
      id: map['id']?.toString() ?? '',
      medicamentoId: map['medicamento_id']?.toString() ?? '',
      nombreComercial: (map['nombre_comercial'] as String? ?? '').trim(),
      presentacion: map['presentacion'] as String?,
      laboratorio: map['laboratorio'] as String?,
      unidad: (map['unidad'] as String? ?? 'UNIDAD').trim(),
      cantidadSolicitada:
          (map['cantidad_solicitada'] as num?)?.toInt() ?? 1,
      cantidadEntregada: (map['cantidad_entregada'] as num?)?.toInt() ?? 0,
      categoriaItem:
          (map['categoria_item'] as String? ?? 'MEDICAMENTO').toUpperCase(),
      origenKit: map['origen_kit'] as bool? ?? false,
      precioKairosAplicado:
          (map['precio_kairos_aplicado'] as num?)?.toDouble(),
      porcentajeDescuentoAplicado:
          (map['porcentaje_descuento_aplicado'] as num?)?.toDouble(),
      precioUnitarioAplicado:
          (map['precio_unitario_aplicado'] as num?)?.toDouble(),
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
  final DateTime fechaCreacion;
  final List<FichaRegistradaItem> items;

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
    required this.fechaCreacion,
    required this.items,
  });

  bool get esEditable => estado == 'SOLICITADO';

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
      fechaCreacion: DateTime.tryParse(map['fecha_creacion']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
      items: List.unmodifiable(items),
    );
  }
}


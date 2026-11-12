import 'entities/ficha_catalogo_entities.dart';
import 'ficha_borrador.dart';

/// Validadores puros de dominio para el registro, edición, atención, despacho y anulación
/// de fichas de pedido (HU-003 a HU-011).
/// No dependen de Flutter ni de red, facilitando pruebas unitarias determinísticas.
class FichaValidadores {
  static const tiposFicha = ['GENERAL', 'NEONATOLOGIA'];
  static const turnos = ['DIA', 'TARDE', 'NOCHE'];
  static const prioridades = ['NORMAL', 'URGENTE'];
  static const tiposAtencion = ['PARTICULAR', 'SEGURO', 'CONVENIO'];
  static const procedencias = ['EMERGENCIA', 'HOSPITALIZACION', 'OTRO'];
  static const tiposParto = ['EUTOCICO', 'DISTOCICO', 'CESAREA', 'OTRO'];
  static const categoriasItem = ['MEDICAMENTO', 'DISPOSITIVO_MEDICO'];
  static const estadosFicha = [
    'SOLICITADO',
    'EN_PREPARACION',
    'LISTO_PARA_RECOJO',
    'ENTREGADO',
    'CANCELADO',
  ];

  static String normalizarEspacios(String valor) =>
      valor.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? validarPacienteGeneral(String? valor) {
    final limpio = normalizarEspacios(valor ?? '');
    if (limpio.length < 3 || limpio.length > 120) {
      return 'Ingresa los nombres y apellidos del paciente (3 a 120 caracteres).';
    }
    return null;
  }

  static String? validarProcedenciaDetalle(
    String procedencia,
    String? detalle,
  ) {
    if (procedencia.toUpperCase() != 'OTRO') return null;
    final limpio = normalizarEspacios(detalle ?? '');
    if (limpio.length < 2 || limpio.length > 120) {
      return 'Especifica el detalle de procedencia (2 a 120 caracteres).';
    }
    return null;
  }

  static String? validarDiagnostico(String? valor) {
    final limpio = normalizarEspacios(valor ?? '');
    if (limpio.length < 3 || limpio.length > 250) {
      return 'Ingresa el diagnóstico o motivo del pedido (3 a 250 caracteres).';
    }
    return null;
  }

  static String? validarMadreNeonatologia(String? valor) {
    final limpio = normalizarEspacios(valor ?? '');
    if (limpio.length < 3 || limpio.length > 120) {
      return 'Ingresa los nombres y apellidos de la madre (3 a 120 caracteres).';
    }
    return null;
  }

  static String? validarApellidosRecienNacido(String? valor) {
    final limpio = normalizarEspacios(valor ?? '');
    if (limpio.length < 2 || limpio.length > 120) {
      return 'Ingresa los apellidos del recién nacido (2 a 120 caracteres).';
    }
    return null;
  }

  static String? validarDoctor({String? doctorId, String? doctorNombre}) {
    if (doctorId != null && doctorId.trim().isNotEmpty) return null;
    final limpio = normalizarEspacios(doctorNombre ?? '');
    if (limpio.length < 3 || limpio.length > 120) {
      return 'Selecciona o ingresa el nombre del médico a cargo (3 a 120 caracteres).';
    }
    return null;
  }

  static String? validarReceptor({String? receptorId, String? recibidoPor}) {
    if (receptorId != null && receptorId.trim().isNotEmpty) return null;
    final limpio = normalizarEspacios(recibidoPor ?? '');
    if (limpio.length < 3 || limpio.length > 120) {
      return 'Selecciona al personal receptor del área solicitante.';
    }
    return null;
  }

  static String? validarFinanciamiento({
    required String tipoAtencion,
    String? financiamientoId,
  }) {
    final tipo = tipoAtencion.trim().toUpperCase();
    if (!tiposAtencion.contains(tipo)) {
      return 'Selecciona la modalidad de financiamiento (Particular, Seguro o Convenio).';
    }
    if ((tipo == 'SEGURO' || tipo == 'CONVENIO') &&
        (financiamientoId == null || financiamientoId.trim().isEmpty)) {
      return tipo == 'SEGURO'
          ? 'Selecciona el seguro que cubre al paciente.'
          : 'Selecciona el convenio aplicable al paciente.';
    }
    return null;
  }

  static String? validarItems(
    List<FichaItemBorrador> items, {
    bool confirmarFaltanteKit = false,
  }) {
    if (items.isEmpty) {
      return 'Agrega al menos un medicamento, insumo o aplica un kit del área.';
    }
    if (items.length > 500) {
      return 'La ficha no puede superar los 500 ítems.';
    }
    final vistos = <String>{};
    for (final item in items) {
      if (item.medicamentoId.trim().isEmpty) {
        return 'Uno de los ítems seleccionados no tiene identificador válido.';
      }
      if (!vistos.add(item.medicamentoId)) {
        return 'El ítem "${item.nombreComercial}" está duplicado; consolida su cantidad en una línea.';
      }
      if (!item.activo) {
        return 'El ítem "${item.nombreComercial}" está inhabilitado en el catálogo.';
      }
      if (item.cantidad <= 0) {
        return 'La cantidad de "${item.nombreComercial}" debe ser mayor que cero.';
      }
      if (!item.origenKit && item.farmaciaDisponible <= 0) {
        return 'El ítem "${item.nombreComercial}" no tiene stock disponible en Farmacia.';
      }
      if (item.cantidad > item.farmaciaDisponible &&
          !(item.origenKit && confirmarFaltanteKit)) {
        return 'La cantidad solicitada de "${item.nombreComercial}" (${item.cantidad}) supera el stock disponible en Farmacia (${item.farmaciaDisponible}).';
      }
    }
    return null;
  }

  /// Valida el borrador completo y devuelve el primer mensaje de error o `null` si es válido.
  static String? validarBorrador(FichaBorrador borrador) {
    if (!tiposFicha.contains(borrador.tipoFicha.toUpperCase())) {
      return 'Selecciona el tipo de ficha (General o Neonatología).';
    }
    if (borrador.areaOrigen.trim().isEmpty) {
      return 'Selecciona el área clínica solicitante.';
    }
    if (!turnos.contains(borrador.turno.toUpperCase())) {
      return 'Selecciona el turno (Día, Tarde o Noche).';
    }
    if (!prioridades.contains(borrador.prioridad.toUpperCase())) {
      return 'Selecciona la prioridad del pedido (Normal o Urgente).';
    }

    final errorFin = validarFinanciamiento(
      tipoAtencion: borrador.tipoAtencion,
      financiamientoId: borrador.financiamientoId,
    );
    if (errorFin != null) return errorFin;

    final errorDoctor = validarDoctor(
      doctorId: borrador.doctorId,
      doctorNombre: borrador.doctorNombre,
    );
    if (errorDoctor != null) return errorDoctor;

    final errorReceptor = validarReceptor(
      receptorId: borrador.receptorId,
      recibidoPor: borrador.recibidoPor,
    );
    if (errorReceptor != null) return errorReceptor;

    if (borrador.tipoFicha == 'GENERAL') {
      final errorPac = validarPacienteGeneral(borrador.pacienteNombre);
      if (errorPac != null) return errorPac;
      if (!procedencias.contains(borrador.procedencia.toUpperCase())) {
        return 'Selecciona la procedencia del paciente (Emergencia, Hospitalización u Otro).';
      }
      final errorProc = validarProcedenciaDetalle(
        borrador.procedencia,
        borrador.procedenciaDetalle,
      );
      if (errorProc != null) return errorProc;
      final errorDiag = validarDiagnostico(borrador.diagnosticoMotivo);
      if (errorDiag != null) return errorDiag;
    } else {
      final errorMadre = validarMadreNeonatologia(borrador.madreNombre);
      if (errorMadre != null) return errorMadre;
      final errorRn =
          validarApellidosRecienNacido(borrador.recienNacidoApellidos);
      if (errorRn != null) return errorRn;
      if (!tiposParto.contains(borrador.tipoParto.toUpperCase())) {
        return 'Selecciona el tipo de parto (Eutócico, Distócico, Cesárea u Otro).';
      }
    }

    return validarItems(
      borrador.items,
      confirmarFaltanteKit: borrador.confirmarFaltanteKit,
    );
  }

  /// Valida las cantidades despachadas reales y las observaciones por ítem (HU-009).
  static String? validarDespachoItems(
    List<ItemDespachoEdicion> items, {
    String? notasFarmacia,
    bool exigirAlMenosUnoEntregado = true,
  }) {
    if (items.isEmpty) {
      return 'La ficha no contiene ítems para despachar.';
    }
    final notaGlobalLimpia = normalizarEspacios(notasFarmacia ?? '');
    var totalEntregado = 0;

    for (final item in items) {
      if (item.cantidadEntregada < 0 ||
          item.cantidadEntregada > item.cantidadSolicitada) {
        return 'La cantidad a despachar de "${item.nombreComercial}" (${item.cantidadEntregada}) debe estar entre 0 y ${item.cantidadSolicitada}.';
      }
      if (item.cantidadEntregada > item.farmaciaDisponible) {
        return 'Stock insuficiente en Farmacia para "${item.nombreComercial}" (a despachar: ${item.cantidadEntregada}, disponible vigente: ${item.farmaciaDisponible}).';
      }
      final obsLimpia = normalizarEspacios(item.observacionItem);
      if (item.cantidadEntregada < item.cantidadSolicitada &&
          obsLimpia.isEmpty &&
          notaGlobalLimpia.isEmpty) {
        return 'El ítem "${item.nombreComercial}" tiene despacho parcial (${item.cantidadEntregada} de ${item.cantidadSolicitada} solicitados). Ingresa una observación justificativa.';
      }
      totalEntregado += item.cantidadEntregada;
    }

    if (exigirAlMenosUnoEntregado && totalEntregado <= 0) {
      return 'Debes despachar al menos 1 unidad en la ficha para marcarla como lista o entregada. Si no se atenderá ningún ítem, anula la ficha con motivo.';
    }
    return null;
  }

  /// Valida el motivo obligatorio de anulación de una ficha (HU-011).
  static String? validarMotivoAnulacion(String? motivo) {
    final limpio = normalizarEspacios(motivo ?? '');
    if (limpio.length < 5 || limpio.length > 500) {
      return 'Ingresa el motivo obligatorio de anulación (5 a 500 caracteres).';
    }
    return null;
  }

  /// Valida si un rol y área pueden ejecutar una transición de atención sobre la ficha (HU-008 / HU-010 / HU-011).
  static String? validarTransicionAtencion({
    required FichaRegistrada ficha,
    required String accion,
    required String rol,
    List<String> areasUsuario = const [],
  }) {
    final accionUpper = accion.trim().toUpperCase();
    final rolUpper = rol.trim().toUpperCase();

    switch (accionUpper) {
      case 'INICIAR_PREPARACION':
        if (rolUpper != 'FARMACIA' && rolUpper != 'ADMINISTRADOR') {
          return 'Solo Farmacia o Administración pueden iniciar la preparación de una ficha.';
        }
        if (ficha.estado != 'SOLICITADO' &&
            ficha.estado != 'EN_PREPARACION') {
          return 'Solo se puede iniciar la preparación desde el estado SOLICITADO.';
        }
        return null;

      case 'GUARDAR_PREPARACION':
      case 'MARCAR_LISTO_RECOJO':
        if (rolUpper != 'FARMACIA' && rolUpper != 'ADMINISTRADOR') {
          return 'Solo Farmacia o Administración pueden registrar cantidades despachadas.';
        }
        if (ficha.estado != 'SOLICITADO' &&
            ficha.estado != 'EN_PREPARACION' &&
            ficha.estado != 'LISTO_PARA_RECOJO') {
          return 'No se puede modificar la preparación de una ficha en estado ${ficha.etiquetaEstado}.';
        }
        return null;

      case 'CONFIRMAR_ENTREGA':
        if (ficha.estado == 'ENTREGADO') {
          return 'Esta ficha ya fue entregada y su stock ya fue descontado.';
        }
        if (!ficha.puedeConfirmarEntrega(
          rol: rolUpper,
          areasUsuario: areasUsuario,
        )) {
          return 'No tienes permiso o la ficha no está en un estado válido para confirmar la entrega.';
        }
        return null;

      case 'ANULAR_FICHA':
        if (ficha.estado == 'CANCELADO') {
          return 'Esta ficha ya se encuentra anulada.';
        }
        if (!ficha.puedeAnular(
          rol: rolUpper,
          areasUsuario: areasUsuario,
        )) {
          if (rolUpper == 'ENFERMERIA' && ficha.estado != 'SOLICITADO') {
            return 'La ficha ya está en atención por Farmacia (${ficha.etiquetaEstado}). Solicita su anulación a Farmacia.';
          }
          return 'No tienes permiso para anular esta ficha.';
        }
        return null;

      default:
        return 'Acción de ficha no reconocida ($accionUpper).';
    }
  }
}


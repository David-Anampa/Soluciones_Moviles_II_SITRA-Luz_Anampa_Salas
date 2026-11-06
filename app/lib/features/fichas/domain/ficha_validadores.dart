import 'ficha_borrador.dart';

/// Validadores puros de dominio para el registro y edición de fichas (HU-003 / HU-004 / HU-005).
/// No dependen de Flutter ni de red, facilitando pruebas unitarias determinísticas.
class FichaValidadores {
  static const tiposFicha = ['GENERAL', 'NEONATOLOGIA'];
  static const turnos = ['DIA', 'TARDE', 'NOCHE'];
  static const prioridades = ['NORMAL', 'URGENTE'];
  static const tiposAtencion = ['PARTICULAR', 'SEGURO', 'CONVENIO'];
  static const procedencias = ['EMERGENCIA', 'HOSPITALIZACION', 'OTRO'];
  static const tiposParto = ['EUTOCICO', 'DISTOCICO', 'CESAREA', 'OTRO'];
  static const categoriasItem = ['MEDICAMENTO', 'DISPOSITIVO_MEDICO'];

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
}


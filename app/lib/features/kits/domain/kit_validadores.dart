import 'entities/kit_item_entity.dart';
import 'kit_borrador.dart';

/// Funciones puras de validación para las historias de usuario HU-017, HU-018 y HU-019.
/// Cumple con SRP (Single Responsibility Principle) y permite pruebas unitarias aisladas.
class KitValidadores {
  KitValidadores._();

  /// Valida el nombre de la plantilla de kit
  static String? validarNombre(String? valor) {
    final limpio = (valor ?? '').trim();
    if (limpio.isEmpty) {
      return 'Escribe el nombre del kit.';
    }
    if (limpio.length < 3) {
      return 'El nombre debe tener al menos 3 caracteres.';
    }
    if (limpio.length > 120) {
      return 'El nombre no puede exceder 120 caracteres.';
    }
    return null;
  }

  /// Valida que se haya seleccionado un área destino válida
  static String? validarArea(String? valor) {
    final limpio = (valor ?? '').trim();
    if (limpio.isEmpty) {
      return 'Selecciona el área de destino del kit.';
    }
    return null;
  }

  /// Valida la descripción clínica opcional
  static String? validarDescripcion(String? valor) {
    final limpio = (valor ?? '').trim();
    if (limpio.isNotEmpty && limpio.length > 300) {
      return 'La descripción no puede exceder 300 caracteres.';
    }
    return null;
  }

  /// Valida la lista de insumos del kit
  static String? validarItems(List<KitItemEntity> items) {
    if (items.isEmpty) {
      return 'Agrega al menos un medicamento o insumo al kit.';
    }

    final idsVistos = <String>{};
    for (final item in items) {
      if (item.medicamentoId.trim().isEmpty) {
        return 'Uno de los ítems no tiene medicamento válido.';
      }
      if (item.cantidad <= 0) {
        return 'La cantidad de "${item.medicamentoNombre}" debe ser mayor a 0.';
      }
      if (idsVistos.contains(item.medicamentoId)) {
        return 'El medicamento "${item.medicamentoNombre}" está duplicado.';
      }
      idsVistos.add(item.medicamentoId);
    }

    return null;
  }

  /// Valida de forma integral el borrador antes de enviar al repositorio / RPC
  static String? validarBorradorCompleto(KitBorrador borrador) {
    final errNombre = validarNombre(borrador.nombre);
    if (errNombre != null) return errNombre;

    final errArea = validarArea(borrador.areaDestino);
    if (errArea != null) return errArea;

    final errDesc = validarDescripcion(borrador.descripcion);
    if (errDesc != null) return errDesc;

    final errItems = validarItems(borrador.items);
    if (errItems != null) return errItems;

    return null;
  }
}

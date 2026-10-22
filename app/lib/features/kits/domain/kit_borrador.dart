import 'entities/kit_item_entity.dart';

class KitBorrador {
  final String nombre;
  final String descripcion;
  final String areaDestino;
  final List<KitItemEntity> items;

  const KitBorrador({
    this.nombre = '',
    this.descripcion = '',
    this.areaDestino = '',
    this.items = const [],
  });

  KitBorrador copyWith({
    String? nombre,
    String? descripcion,
    String? areaDestino,
    List<KitItemEntity>? items,
  }) {
    return KitBorrador(
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      areaDestino: areaDestino ?? this.areaDestino,
      items: items ?? this.items,
    );
  }

  /// Agrega un ítem o actualiza su cantidad si ya existe en la lista
  KitBorrador agregarOActualizarItem(KitItemEntity nuevoItem) {
    final index = items.indexWhere((i) => i.medicamentoId == nuevoItem.medicamentoId);
    if (index >= 0) {
      final updatedList = List<KitItemEntity>.from(items);
      final actual = updatedList[index];
      updatedList[index] = actual.copyWith(cantidad: actual.cantidad + nuevoItem.cantidad);
      return copyWith(items: updatedList);
    } else {
      return copyWith(items: [...items, nuevoItem]);
    }
  }

  /// Remueve un ítem según el medicamentoId
  KitBorrador eliminarItem(String medicamentoId) {
    return copyWith(
      items: items.where((i) => i.medicamentoId != medicamentoId).toList(),
    );
  }

  /// Modifica la cantidad de un ítem existente
  KitBorrador cambiarCantidad(String medicamentoId, int nuevaCantidad) {
    if (nuevaCantidad <= 0) return eliminarItem(medicamentoId);
    final updatedList = items.map((i) {
      if (i.medicamentoId == medicamentoId) {
        return i.copyWith(cantidad: nuevaCantidad);
      }
      return i;
    }).toList();
    return copyWith(items: updatedList);
  }

  /// Serializa para envío seguro a la RPC `administrar_kit_hu018`
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim().isEmpty ? null : descripcion.trim(),
      'area_destino': areaDestino.trim(),
      'items': items.map((i) => i.toMap()).toList(),
    };
  }
}

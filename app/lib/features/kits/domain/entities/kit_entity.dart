import 'kit_item_entity.dart';

class KitEntity {
  final String id;
  final String nombre;
  final String? descripcion;
  final String areaDestino;
  final String areaNombre;
  final String areaCodigoInterno;
  final bool activo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int totalItems;
  final List<KitItemEntity> items;

  const KitEntity({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.areaDestino,
    required this.areaNombre,
    required this.areaCodigoInterno,
    required this.activo,
    this.createdAt,
    this.updatedAt,
    required this.totalItems,
    this.items = const [],
  });

  KitEntity copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    String? areaDestino,
    String? areaNombre,
    String? areaCodigoInterno,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalItems,
    List<KitItemEntity>? items,
  }) {
    return KitEntity(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      areaDestino: areaDestino ?? this.areaDestino,
      areaNombre: areaNombre ?? this.areaNombre,
      areaCodigoInterno: areaCodigoInterno ?? this.areaCodigoInterno,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalItems: totalItems ?? this.totalItems,
      items: items ?? this.items,
    );
  }

  factory KitEntity.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    List<KitItemEntity> itemsList = [];
    if (rawItems is List) {
      itemsList = rawItems
          .map((item) => KitItemEntity.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    final total = (map['total_items'] as num?)?.toInt() ?? itemsList.length;

    return KitEntity(
      id: map['id']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      descripcion: map['descripcion']?.toString(),
      areaDestino: map['area_destino']?.toString() ?? '',
      areaNombre:
          map['area_nombre']?.toString() ??
          map['area_destino']?.toString() ??
          '',
      areaCodigoInterno:
          map['area_codigo_interno']?.toString() ??
          map['area_destino']?.toString() ??
          '',
      activo: map['activo'] as bool? ?? true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
      totalItems: total,
      items: itemsList,
    );
  }
}

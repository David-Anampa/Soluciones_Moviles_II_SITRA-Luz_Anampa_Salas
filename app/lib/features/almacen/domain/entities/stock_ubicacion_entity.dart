/// Existencias reales por producto: tránsito y stock no utilizable se separan.
class StockUbicacionEntity {
  final String id, nombre, principioActivo, gtin, presentacion, unidad;
  final int almacen, farmacia, transito, almacenFisico, farmaciaFisico;
  final bool activo, pendienteConciliacion;
  const StockUbicacionEntity({
    required this.id,
    required this.nombre,
    required this.principioActivo,
    required this.gtin,
    required this.presentacion,
    required this.unidad,
    required this.almacen,
    required this.farmacia,
    required this.transito,
    required this.almacenFisico,
    required this.farmaciaFisico,
    required this.activo,
    required this.pendienteConciliacion,
  });

  factory StockUbicacionEntity.fromMap(Map<String, dynamic> m) =>
      StockUbicacionEntity(
        id: m['medicamento_id'] as String,
        nombre: m['nombre'] as String,
        principioActivo: m['principio_activo'] as String? ?? '',
        gtin: m['gtin'] as String? ?? '',
        presentacion: m['presentacion'] as String? ?? '',
        unidad: m['unidad'] as String? ?? 'unidades',
        almacen: (m['almacen_disponible'] as num).toInt(),
        farmacia: (m['farmacia_disponible'] as num).toInt(),
        transito: (m['en_transito'] as num).toInt(),
        almacenFisico: (m['almacen_fisico'] as num).toInt(),
        farmaciaFisico: (m['farmacia_fisico'] as num).toInt(),
        activo: m['activo'] as bool,
        pendienteConciliacion: m['pendiente_conciliacion'] as bool? ?? false,
      );
}

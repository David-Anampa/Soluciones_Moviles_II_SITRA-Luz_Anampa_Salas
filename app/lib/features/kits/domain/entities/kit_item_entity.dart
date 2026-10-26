class KitItemEntity {
  final String id;
  final String medicamentoId;
  final String medicamentoNombre;
  final String? principioActivo;
  final String? presentacion;
  final String? laboratorio;
  final int cantidad;

  const KitItemEntity({
    required this.id,
    required this.medicamentoId,
    required this.medicamentoNombre,
    this.principioActivo,
    this.presentacion,
    this.laboratorio,
    required this.cantidad,
  });

  /// Crea una copia inmutable con campos modificados
  KitItemEntity copyWith({
    String? id,
    String? medicamentoId,
    String? medicamentoNombre,
    String? principioActivo,
    String? presentacion,
    String? laboratorio,
    int? cantidad,
  }) {
    return KitItemEntity(
      id: id ?? this.id,
      medicamentoId: medicamentoId ?? this.medicamentoId,
      medicamentoNombre: medicamentoNombre ?? this.medicamentoNombre,
      principioActivo: principioActivo ?? this.principioActivo,
      presentacion: presentacion ?? this.presentacion,
      laboratorio: laboratorio ?? this.laboratorio,
      cantidad: cantidad ?? this.cantidad,
    );
  }

  factory KitItemEntity.fromMap(Map<String, dynamic> map) {
    return KitItemEntity(
      id: map['id']?.toString() ?? '',
      medicamentoId: map['medicamento_id']?.toString() ?? '',
      medicamentoNombre:
          map['nombre_comercial']?.toString() ??
          map['medicamento_nombre']?.toString() ??
          'Medicamento sin nombre',
      principioActivo: map['principio_activo']?.toString(),
      presentacion: map['presentacion']?.toString(),
      laboratorio: map['laboratorio']?.toString(),
      cantidad: (map['cantidad'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {'medicamento_id': medicamentoId, 'cantidad': cantidad};
  }
}

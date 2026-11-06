/// Entidad pura de Dominio que representa un Medicamento en SITRA-Luz
class MedicamentoEntity {
  final String id;
  final String gtin;
  final String nombreComercial;
  final String principioActivo;
  final String presentacion;
  final String? laboratorio;
  final String? codArt;
  final double? precioKairos;
  final String? registroSanitario;
  final String unidadPresentacion;
  final int cantidadPorPresentacion;
  final bool requiereCadenaFrio;
  final double temperaturaMin;
  final double temperaturaMax;
  final String categoria;
  final bool activo;

  const MedicamentoEntity({
    required this.id,
    required this.gtin,
    required this.nombreComercial,
    required this.principioActivo,
    required this.presentacion,
    this.laboratorio,
    this.codArt,
    this.precioKairos,
    this.registroSanitario,
    this.unidadPresentacion = 'unidad',
    this.cantidadPorPresentacion = 1,
    this.requiereCadenaFrio = false,
    this.temperaturaMin = 2.0,
    this.temperaturaMax = 8.0,
    this.categoria = 'MEDICAMENTO',
    this.activo = true,
  });

  /// Retorna un texto descriptivo del rango térmico permitido
  String get rangoTemperaturaTexto =>
      requiereCadenaFrio ? '$temperaturaMin °C a $temperaturaMax °C' : 'Ambiente (15-25 °C)';
}

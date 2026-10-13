import '../entities/medicamento_entity.dart';
import '../entities/lote_entity.dart';
import '../entities/pedido_abastecimiento_entity.dart';
import '../entities/stock_almacen_entity.dart';

/// Contrato del Repositorio de Almacén (Capa de Dominio)
abstract class AlmacenRepository {
  /// Obtiene la lista completa de stock disponible en el Almacén General
  Future<List<StockAlmacenEntity>> getInventarioAlmacen();

  /// Obtiene el catálogo maestro de medicamentos registrados
  Future<List<MedicamentoEntity>> getMedicamentos();

  /// Registra un nuevo medicamento maestro en el catálogo
  Future<MedicamentoEntity> registrarMedicamento({
    required String gtin,
    required String nombreComercial,
    required String principioActivo,
    required String presentacion,
    String? laboratorio,
    String? codArt,
    double? precioKairos,
    String? registroSanitario,
    String unidadPresentacion = 'unidad',
    int cantidadPorPresentacion = 1,
    bool requiereCadenaFrio = false,
    double temperaturaMin = 2.0,
    double temperaturaMax = 8.0,
  });

  /// Actualiza los datos técnicos de un medicamento existente en el catálogo (RF-016)
  Future<MedicamentoEntity> editarMedicamento({
    required String id,
    required String gtin,
    required String nombreComercial,
    required String principioActivo,
    required String presentacion,
    String? laboratorio,
    String? codArt,
    double? precioKairos,
    String? registroSanitario,
    String unidadPresentacion = 'unidad',
    int cantidadPorPresentacion = 1,
    bool requiereCadenaFrio = false,
    double temperaturaMin = 2.0,
    double temperaturaMax = 8.0,
    bool activo = true,
  });

  /// Registra una nueva solicitud de abastecimiento (RF-029)
  Future<PedidoAbastecimientoEntity> crearPedidoAbastecimiento({
    required String areaDestino,
    required String turno,
    required String justificacion,
    required String notas,
    required Map<String, int> items,
  });

  /// Registra un ingreso de lote y agrega el stock correspondiente en Almacén
  Future<LoteEntity> registrarIngresoLote({
    required String medicamentoId,
    required String numeroLote,
    required DateTime fechaVencimiento,
    DateTime? fechaFabricacion,
    String? laboratorio,
    String? proveedor,
    double? precioCompra,
    double? precioVenta,
    String? numBoleta,
    String? justificacion,
    double? temperaturaRecepcion,
    String? observaciones,
    required int cantidadInicial,
  });

  /// Transfiere stock de un lote específico desde Almacén hacia Farmacia Central (RF-025)
  Future<void> transferirStockAFarmacia({
    required String loteId,
    required String medicamentoId,
    required int cantidad,
    String? motivo,
  });

  /// Obtiene la lista de solicitudes de abastecimiento enviadas por Farmacia (RF-031)
  Future<List<PedidoAbastecimientoEntity>> getSolicitudesAbastecimiento();

  /// Pasa el estado a EN_PREPARACION (Almacén toma el pedido)
  Future<void> tomarPedidoAbastecimiento(String pedidoId);

  /// Pasa el estado a LISTO y define la modalidad de entrega
  Future<void> marcarPedidoListo(String pedidoId, String modalidad);

  /// Confirma la entrega por parte de Almacén y verifica si se completa
  Future<void> marcarConfirmacionAlmacen(String pedidoId);

  /// RF-030: Atiende y despacha la solicitud ajustando cantidades y realizando transferencia atómica de stock
  Future<void> despacharPedidoAbastecimiento({
    required String pedidoId,
    required Map<String, int> cantidadesDespachadas,
    required String modalidadEntrega,
    String? notasDespacho,
  });

  /// Farmacia cancela su propia solicitud mientras esté en estado PENDIENTE
  Future<void> cancelarPedidoAbastecimiento({
    required String pedidoId,
    required String motivo,
  });

  /// Almacén rechaza una solicitud (ej. quiebre de stock total)
  Future<void> rechazarPedidoAbastecimiento({
    required String pedidoId,
    required String motivo,
  });

  /// Farmacia confirma la recepción física y cierra el ciclo (COMPLETADO)
  Future<void> marcarConfirmacionFarmacia(String pedidoId);

  /// Farmacia confirma recepción física con observación / devolución inmediata de exceso
  Future<void> confirmarRecepcionConAjuste({
    required String pedidoId,
    required Map<String, int> cantidadesAceptadas,
    required String motivoObservacion,
  });

  /// Marca una solicitud de abastecimiento como atendida/despachada (Viejo flujo)
  Future<void> atenderSolicitudAbastecimiento({
    required String pedidoId,
    String? notasDespacho,
  });
}

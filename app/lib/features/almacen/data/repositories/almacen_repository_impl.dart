import '../../domain/entities/lote_entity.dart';
import '../../domain/entities/medicamento_entity.dart';
import '../../domain/entities/pedido_abastecimiento_entity.dart';
import '../../domain/entities/stock_almacen_entity.dart';
import '../../domain/repositories/almacen_repository.dart';
import '../datasources/almacen_remote_datasource.dart';
import '../models/medicamento_model.dart';

/// Implementación concreta del repositorio de Almacén
class AlmacenRepositoryImpl implements AlmacenRepository {
  final AlmacenRemoteDataSource _dataSource;

  AlmacenRepositoryImpl({AlmacenRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? AlmacenRemoteDataSource();

  @override
  Future<List<StockAlmacenEntity>> getInventarioAlmacen() async {
    return await _dataSource.getInventarioAlmacen();
  }

  @override
  Future<List<MedicamentoEntity>> getMedicamentos() async {
    return await _dataSource.getMedicamentos();
  }

  @override
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
  }) async {
    final model = MedicamentoModel(
      id: '', // Se autogenera en la BD
      gtin: gtin,
      nombreComercial: nombreComercial,
      principioActivo: principioActivo,
      presentacion: presentacion,
      laboratorio: laboratorio,
      codArt: codArt,
      precioKairos: precioKairos,
      registroSanitario: registroSanitario,
      unidadPresentacion: unidadPresentacion,
      cantidadPorPresentacion: cantidadPorPresentacion,
      requiereCadenaFrio: requiereCadenaFrio,
      temperaturaMin: temperaturaMin,
      temperaturaMax: temperaturaMax,
    );
    return await _dataSource.registrarMedicamento(model);
  }

  @override
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
  }) async {
    final model = MedicamentoModel(
      id: id,
      gtin: gtin,
      nombreComercial: nombreComercial,
      principioActivo: principioActivo,
      presentacion: presentacion,
      laboratorio: laboratorio,
      codArt: codArt,
      precioKairos: precioKairos,
      registroSanitario: registroSanitario,
      unidadPresentacion: unidadPresentacion,
      cantidadPorPresentacion: cantidadPorPresentacion,
      requiereCadenaFrio: requiereCadenaFrio,
      temperaturaMin: temperaturaMin,
      temperaturaMax: temperaturaMax,
      activo: activo,
    );
    return await _dataSource.editarMedicamento(model);
  }

  @override
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
  }) async {
    return await _dataSource.registrarIngresoLote(
      medicamentoId: medicamentoId,
      numeroLote: numeroLote,
      fechaVencimiento: fechaVencimiento,
      fechaFabricacion: fechaFabricacion,
      laboratorio: laboratorio,
      proveedor: proveedor,
      precioCompra: precioCompra,
      precioVenta: precioVenta,
      numBoleta: numBoleta,
      justificacion: justificacion,
      temperaturaRecepcion: temperaturaRecepcion,
      observaciones: observaciones,
      cantidadInicial: cantidadInicial,
    );
  }

  @override
  Future<void> transferirStockAFarmacia({
    required String loteId,
    required String medicamentoId,
    required int cantidad,
    String? motivo,
  }) async {
    await _dataSource.transferirStockAFarmacia(
      loteId: loteId,
      medicamentoId: medicamentoId,
      cantidad: cantidad,
      motivo: motivo,
    );
  }

  @override
  Future<PedidoAbastecimientoEntity> crearPedidoAbastecimiento({
    required String areaDestino,
    required String turno,
    required String justificacion,
    required String notas,
    required Map<String, int> items,
  }) async {
    return await _dataSource.crearPedidoAbastecimiento(
      areaDestino: areaDestino,
      turno: turno,
      justificacion: justificacion,
      notas: notas,
      items: items,
    );
  }

  @override
  Future<List<PedidoAbastecimientoEntity>> getSolicitudesAbastecimiento() async {
    return await _dataSource.getSolicitudesAbastecimiento();
  }

  @override
  Future<void> tomarPedidoAbastecimiento(String pedidoId) async {
    await _dataSource.tomarPedidoAbastecimiento(pedidoId);
  }

  @override
  Future<void> marcarPedidoListo(String pedidoId, String modalidad) async {
    await _dataSource.marcarPedidoListo(pedidoId, modalidad);
  }

  @override
  Future<void> marcarConfirmacionAlmacen(String pedidoId) async {
    await _dataSource.marcarConfirmacionAlmacen(pedidoId);
  }

  @override
  Future<void> despacharPedidoAbastecimiento({
    required String pedidoId,
    required Map<String, int> cantidadesDespachadas,
    required String modalidadEntrega,
    String? notasDespacho,
  }) async {
    await _dataSource.despacharPedidoAbastecimiento(
      pedidoId: pedidoId,
      cantidadesDespachadas: cantidadesDespachadas,
      modalidadEntrega: modalidadEntrega,
      notasDespacho: notasDespacho,
    );
  }

  @override
  Future<void> cancelarPedidoAbastecimiento({
    required String pedidoId,
    required String motivo,
  }) async {
    await _dataSource.cancelarPedidoAbastecimiento(
      pedidoId: pedidoId,
      motivo: motivo,
    );
  }

  @override
  Future<void> rechazarPedidoAbastecimiento({
    required String pedidoId,
    required String motivo,
  }) async {
    await _dataSource.rechazarPedidoAbastecimiento(
      pedidoId: pedidoId,
      motivo: motivo,
    );
  }

  @override
  Future<void> marcarConfirmacionFarmacia(String pedidoId) async {
    await _dataSource.marcarConfirmacionFarmacia(pedidoId);
  }

  @override
  Future<void> confirmarRecepcionConAjuste({
    required String pedidoId,
    required Map<String, int> cantidadesAceptadas,
    required String motivoObservacion,
  }) async {
    await _dataSource.confirmarRecepcionConAjuste(
      pedidoId: pedidoId,
      cantidadesAceptadas: cantidadesAceptadas,
      motivoObservacion: motivoObservacion,
    );
  }

  @override
  Future<void> atenderSolicitudAbastecimiento({
    required String pedidoId,
    String? notasDespacho,
  }) async {
    await _dataSource.atenderSolicitudAbastecimiento(
      pedidoId: pedidoId,
      notasDespacho: notasDespacho,
    );
  }
}

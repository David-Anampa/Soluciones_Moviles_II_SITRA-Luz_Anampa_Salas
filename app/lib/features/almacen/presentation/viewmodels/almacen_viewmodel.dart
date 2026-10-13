import 'package:flutter/foundation.dart';
import '../../domain/repositories/almacen_repository.dart';
import '../states/almacen_state.dart';

/// ViewModel que gestiona la lógica de presentación del Almacén General
class AlmacenViewModel extends ChangeNotifier {
  final AlmacenRepository _repository;

  AlmacenState _state = const AlmacenInitial();
  AlmacenState get state => _state;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  AlmacenViewModel({required AlmacenRepository repository})
      : _repository = repository;

  /// Carga el inventario y el catálogo de medicamentos desde Supabase
  Future<void> cargarInventario() async {
    _state = const AlmacenLoading();
    notifyListeners();

    try {
      final inventario = await _repository.getInventarioAlmacen();
      final catalogo = await _repository.getMedicamentos();
      final solicitudes = await _repository.getSolicitudesAbastecimiento();

      _state = AlmacenLoaded(
        inventario: inventario,
        catalogo: catalogo,
        solicitudes: solicitudes,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _state = AlmacenError('No se pudo cargar el inventario: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Registra un nuevo medicamento maestro y su lote inicial en Almacén
  Future<bool> registrarMedicamentoYPrimerLote({
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
    required String numeroLote,
    required DateTime fechaVencimiento,
    DateTime? fechaFabricacion,
    String? proveedor,
    double? precioCompra,
    double? precioVenta,
    String? numBoleta,
    String? justificacion,
    double? temperaturaRecepcion,
    String? observaciones,
    required int cantidadInicial,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Crear el medicamento maestro
      final nuevoMed = await _repository.registrarMedicamento(
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

      // 2. Crear el lote inicial con el stock en Almacén
      await _repository.registrarIngresoLote(
        medicamentoId: nuevoMed.id,
        numeroLote: numeroLote,
        fechaVencimiento: fechaVencimiento,
        fechaFabricacion: fechaFabricacion,
        proveedor: proveedor,
        precioCompra: precioCompra,
        precioVenta: precioVenta,
        numBoleta: numBoleta,
        justificacion: justificacion,
        temperaturaRecepcion: temperaturaRecepcion,
        observaciones: observaciones,
        cantidadInicial: cantidadInicial,
      );

      // 3. Recargar el inventario
      await cargarInventario();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// HU-016: Actualiza los datos técnicos de un medicamento existente en el catálogo.
  Future<bool> editarMedicamento({
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
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.editarMedicamento(
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

      // Recargar catálogo e inventario
      await cargarInventario();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Registra un nuevo ingreso de lote para un medicamento que ya existe en el catálogo
  Future<bool> registrarLoteParaMedicamentoExistente({
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
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.registrarIngresoLote(
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

      await cargarInventario();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// HU-029: Registra una nueva solicitud de abastecimiento desde Farmacia hacia Almacén.
  Future<bool> crearPedidoAbastecimiento({
    required String areaDestino,
    required String turno,
    required String justificacion,
    required String notas,
    required Map<String, int> items,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.crearPedidoAbastecimiento(
        areaDestino: areaDestino,
        turno: turno,
        justificacion: justificacion,
        notas: notas,
        items: items,
      );

      // Recargar para tener el nuevo pedido
      await cargarInventario();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Transfiere stock físico de un lote desde Almacén hacia Farmacia Central.
  Future<bool> transferirStockAFarmacia({
    required String loteId,
    required String medicamentoId,
    required int cantidad,
    String? motivo,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.transferirStockAFarmacia(
        loteId: loteId,
        medicamentoId: medicamentoId,
        cantidad: cantidad,
        motivo: motivo,
      );

      await cargarInventario();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Pasa el estado a EN_PREPARACION (Almacén toma el pedido)
  Future<bool> tomarPedidoAbastecimiento(String pedidoId) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.tomarPedidoAbastecimiento(pedidoId);
      await cargarInventario();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Pasa el estado a LISTO y define la modalidad de entrega
  Future<bool> marcarPedidoListo(String pedidoId, String modalidad) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.marcarPedidoListo(pedidoId, modalidad);
      await cargarInventario();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Confirma la entrega por parte de Almacén y verifica si se completa
  Future<bool> marcarConfirmacionAlmacen(String pedidoId) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.marcarConfirmacionAlmacen(pedidoId);
      await cargarInventario();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// HU-030: Atiende y despacha la solicitud ajustando cantidades y transfiriendo stock.
  Future<bool> despacharPedidoAbastecimiento({
    required String pedidoId,
    required Map<String, int> cantidadesDespachadas,
    required String modalidadEntrega,
    String? notasDespacho,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.despacharPedidoAbastecimiento(
        pedidoId: pedidoId,
        cantidadesDespachadas: cantidadesDespachadas,
        modalidadEntrega: modalidadEntrega,
        notasDespacho: notasDespacho,
      );
      await cargarInventario();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Farmacia confirma la recepción física de la mercadería (COMPLETADO)
  Future<bool> marcarConfirmacionFarmacia(String pedidoId) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.marcarConfirmacionFarmacia(pedidoId);
      await cargarInventario();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Farmacia cancela su propia solicitud mientras esté en estado PENDIENTE
  Future<bool> cancelarPedidoAbastecimiento({
    required String pedidoId,
    required String motivo,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.cancelarPedidoAbastecimiento(
        pedidoId: pedidoId,
        motivo: motivo,
      );
      await cargarInventario();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Almacén rechaza una solicitud (ej. quiebre de stock total)
  Future<bool> rechazarPedidoAbastecimiento({
    required String pedidoId,
    required String motivo,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.rechazarPedidoAbastecimiento(
        pedidoId: pedidoId,
        motivo: motivo,
      );
      await cargarInventario();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Farmacia confirma recepción física con observación / devolución de exceso inmediata
  Future<bool> confirmarRecepcionConAjuste({
    required String pedidoId,
    required Map<String, int> cantidadesAceptadas,
    required String motivoObservacion,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.confirmarRecepcionConAjuste(
        pedidoId: pedidoId,
        cantidadesAceptadas: cantidadesAceptadas,
        motivoObservacion: motivoObservacion,
      );
      await cargarInventario();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Marca una solicitud de abastecimiento como despachada / atendida (Viejo Flujo)
  Future<bool> atenderSolicitudAbastecimiento({
    required String pedidoId,
    String? notasDespacho,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.atenderSolicitudAbastecimiento(
        pedidoId: pedidoId,
        notasDespacho: notasDespacho,
      );

      await cargarInventario();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}

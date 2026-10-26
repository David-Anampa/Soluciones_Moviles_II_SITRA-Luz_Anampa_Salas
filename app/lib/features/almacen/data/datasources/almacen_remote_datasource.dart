import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/solicitud_id.dart';
import '../models/lote_model.dart';
import '../models/medicamento_model.dart';
import '../models/pedido_abastecimiento_model.dart';
import '../models/stock_almacen_model.dart';
import '../repositories/ingresos_repository.dart';

/// Excepción de operaciones en el módulo de Almacén
class AlmacenException implements Exception {
  final String message;
  const AlmacenException(this.message);

  @override
  String toString() => message;
}

/// Fuente de datos remota para Almacén conectada a Supabase (PostgreSQL)
class AlmacenRemoteDataSource {
  final SupabaseClient? _customClient;

  AlmacenRemoteDataSource({SupabaseClient? client}) : _customClient = client;

  SupabaseClient get _supabase => _customClient ?? Supabase.instance.client;
  late final _ingresos = IngresosRepository(client: _supabase);

  Future<void> registrarMedicamentoConIngreso({required Map<String,dynamic> medicamento,
    required Map<String,dynamic> ingreso}) async {
    await _ingresos.registrar(ingreso, medicamento: medicamento);
  }

  /// HU-029: una única transacción guarda solicitud, ítems y auditoría.
  /// La clave de envío permite recuperar el mismo pedido después de un corte de red.
  Future<PedidoAbastecimientoModel> crearPedidoAbastecimiento({
    required String areaDestino,
    required String turno,
    required String justificacion,
    required String notas,
    required Map<String, int> items,
    String? solicitudId,
    bool iniciadoPorAlmacen = false,
    String modalidadEntrega = 'ENTREGA',
  }) async {
    if (_supabase.auth.currentUser == null) {
      throw const AlmacenException(
        'Inicia sesión antes de crear una solicitud.',
      );
    }
    try {
      final response = await _supabase.rpc(
        iniciadoPorAlmacen
            ? 'iniciar_traslado_almacen'
            : 'crear_pedido_abastecimiento',
        params: {
          'p_solicitud_id': solicitudId ?? generarSolicitudId(),
          'p_area_destino': areaDestino,
          'p_turno': turno,
          'p_justificacion': justificacion,
          'p_notas': notas,
          'p_items': items,
          if (iniciadoPorAlmacen) 'p_modalidad': modalidadEntrega,
        },
      );
      return PedidoAbastecimientoModel.fromMap(
        Map<String, dynamic>.from(response as Map),
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' || e.code == '42883') {
        throw const AlmacenException(
          'Falta aplicar la migración de abastecimiento atómico HU-029/HU-030.',
        );
      }
      throw AlmacenException(e.message);
    } catch (e) {
      throw AlmacenException('No se pudo registrar la solicitud: $e');
    }
  }

  /// Obtiene el stock disponible en Almacén General con sus lotes y medicamentos asociados

  Future<List<StockAlmacenModel>> getInventarioAlmacen() async {
    try {
      final response = await _supabase
          .from('inventario_stock')
          .select('*, lote:lotes(*, medicamento:medicamentos(*))')
          .eq('area_codigo', 'ALMACEN')
          .order('cantidad', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map(
            (item) => StockAlmacenModel.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      if (e is PostgrestException && e.code == '42501') {
        throw const AlmacenException(
          'Tu rol no tiene permiso para consultar este inventario.',
        );
      }
      throw AlmacenException('No se pudo consultar el inventario real: $e');
    }
  }

  /// Obtiene el catálogo de medicamentos activos
  Future<List<MedicamentoModel>> getMedicamentos() async {
    try {
      final response = await _supabase
          .from('medicamentos')
          .select()
          .eq('activo', true)
          .order('nombre_comercial', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((item) => MedicamentoModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is PostgrestException && e.code == '42501') {
        throw const AlmacenException(
          'Tu rol no tiene permiso para consultar el catálogo.',
        );
      }
      throw AlmacenException('No se pudo consultar el catálogo real: $e');
    }
  }

  /// Registra un nuevo medicamento maestro en el catálogo
  Future<MedicamentoModel> registrarMedicamento(MedicamentoModel nuevo) async {
    try {
      final response = await _supabase
          .from('medicamentos')
          .insert(nuevo.toMap())
          .select()
          .single();

      debugPrint(
        '✅ Medicamento registrado exitosamente en Supabase: ${response['nombre_comercial']}',
      );
      return MedicamentoModel.fromMap(response);
    } on PostgrestException catch (e) {
      if (e.message.contains('gtin') || e.code == '23505') {
        throw const AlmacenException(
          'Ya existe un medicamento registrado con ese código de barras / GTIN.',
        );
      }
      throw AlmacenException(
        'Error al guardar en la base de datos: ${e.message}',
      );
    } catch (e) {
      if (e is AlmacenException) rethrow;
      throw AlmacenException('No se pudo registrar el medicamento: $e');
    }
  }

  /// HU-016: Actualiza los datos técnicos de un medicamento existente en el catálogo.
  Future<MedicamentoModel> editarMedicamento(
    MedicamentoModel medicamento,
  ) async {
    try {
      final response = await _supabase
          .from('medicamentos')
          .update(medicamento.toMap())
          .eq('id', medicamento.id)
          .select()
          .single();

      debugPrint(
        '✅ Medicamento actualizado exitosamente en Supabase: ${response['nombre_comercial']}',
      );
      return MedicamentoModel.fromMap(response);
    } on PostgrestException catch (e) {
      if (e.message.contains('gtin') || e.code == '23505') {
        throw const AlmacenException(
          'El código GTIN ya pertenece a otro medicamento registrado.',
        );
      }
      throw AlmacenException(
        'Error al actualizar en la base de datos: ${e.message}',
      );
    } catch (e) {
      if (e is AlmacenException) rethrow;
      throw AlmacenException('No se pudo actualizar el medicamento: $e');
    }
  }

  /// Registra un ingreso de lote y suma el stock físico en el Almacén General
  Future<LoteModel> registrarIngresoLote({
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
    try {
      // El servidor guarda lote, saldo inicial y auditoría juntos.
      final loteData = {
        'medicamento_id': medicamentoId,
        'numero_lote': numeroLote.trim().toUpperCase(),
        if (fechaFabricacion != null)
          'fecha_fabricacion': fechaFabricacion
              .toIso8601String()
              .split('T')
              .first,
        'fecha_vencimiento': fechaVencimiento
            .toIso8601String()
            .split('T')
            .first,
        if (laboratorio != null && laboratorio.isNotEmpty)
          'laboratorio': laboratorio.trim(),
        if (proveedor != null && proveedor.isNotEmpty)
          'proveedor': proveedor.trim(),
        if (precioCompra != null) 'precio_compra': precioCompra,
        if (precioVenta != null) 'precio_venta': precioVenta,
        if (numBoleta != null && numBoleta.isNotEmpty)
          'num_boleta': numBoleta.trim(),
        'justificacion': justificacion?.trim().isNotEmpty == true ? justificacion!.trim() : 'Compra',
        if (temperaturaRecepcion != null)
          'temperatura_recepcion': temperaturaRecepcion,
        if (observaciones != null && observaciones.isNotEmpty)
          'observaciones': observaciones.trim(),
        'activo': true,
        'cantidad': cantidadInicial,
      };
      return LoteModel.fromMap(await _ingresos.registrar(loteData));
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const AlmacenException(
          'Ese número de lote ya se encuentra registrado para este medicamento.',
        );
      }
      throw AlmacenException('Error al registrar el lote: ${e.message}');
    } catch (e) {
      if (e is AlmacenException) rethrow;
      throw AlmacenException('Error al procesar el ingreso de lote: $e');
    }
  }

  /// Ruta antigua retirada: toda salida a Farmacia debe pasar por una solicitud
  /// y su despacho transaccional, para mantener recepción y auditoría por lote.
  Future<void> transferirStockAFarmacia({
    required String loteId,
    required String medicamentoId,
    required int cantidad,
    String? motivo,
  }) async {
    throw const AlmacenException(
      'Abre Solicitudes de abastecimiento para despachar y confirmar la recepción.',
    );
  }

  /// HU-030: Obtiene la lista de solicitudes de abastecimiento enviadas por Farmacia.
  Future<List<PedidoAbastecimientoModel>> getSolicitudesAbastecimiento() async {
    try {
      final response = await _supabase
          .from('pedidos_abastecimiento')
          .select(
            '*, solicitante:profiles!pedidos_abastecimiento_solicitante_id_fkey(nombre, rol), cancelado_por_perfil:profiles!pedidos_abastecimiento_cancelado_por_fkey(nombre), rechazado_por_perfil:profiles!pedidos_abastecimiento_rechazado_por_fkey(nombre), items:pedidos_abastecimiento_items(*, medicamento:medicamentos(*))',
          )
          .order('fecha_solicitud', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map(
            (item) =>
                PedidoAbastecimientoModel.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw AlmacenException('No se pudieron consultar las solicitudes: $e');
    }
  }

  /// Cada acción valida rol y estado, bloquea el pedido y registra su auditoría.
  Future<void> _accionPedido(
    String pedidoId,
    String accion, {
    String? motivo,
    Map<String, int>? cantidades,
    String? modalidad,
    String? notas,
  }) async {
    try {
      await _supabase.rpc(
        'procesar_pedido_abastecimiento',
        params: {
          'p_pedido_id': pedidoId,
          'p_accion': accion,
          'p_motivo': motivo,
          'p_cantidades': cantidades ?? <String, int>{},
          'p_modalidad': modalidad,
          'p_notas': notas,
        },
      );
    } on PostgrestException catch (e) {
      throw AlmacenException(e.message);
    } catch (e) {
      throw AlmacenException('No se pudo procesar el pedido: $e');
    }
  }

  Future<void> tomarPedidoAbastecimiento(String pedidoId) =>
      _accionPedido(pedidoId, 'TOMAR');

  // Se conserva la interfaz antigua, pero LISTO requiere despacho real de stock.
  Future<void> marcarPedidoListo(String pedidoId, String modalidad) async {
    throw const AlmacenException(
      'Utiliza Atender y Despachar para marcar el pedido como listo.',
    );
  }

  Future<void> marcarConfirmacionAlmacen(String pedidoId) async {
    throw const AlmacenException(
      'Almacén confirma al despachar; Farmacia confirma la recepción.',
    );
  }

  Future<void> despacharPedidoAbastecimiento({
    required String pedidoId,
    required Map<String, int> cantidadesDespachadas,
    required String modalidadEntrega,
    String? notasDespacho,
  }) => _accionPedido(
    pedidoId,
    'DESPACHAR',
    cantidades: cantidadesDespachadas,
    modalidad: modalidadEntrega,
    notas: notasDespacho,
  );

  Future<void> cancelarPedidoAbastecimiento({
    required String pedidoId,
    required String motivo,
  }) => _accionPedido(pedidoId, 'CANCELAR', motivo: motivo);

  Future<void> rechazarPedidoAbastecimiento({
    required String pedidoId,
    required String motivo,
  }) => _accionPedido(pedidoId, 'RECHAZAR', motivo: motivo);

  Future<void> marcarConfirmacionFarmacia(String pedidoId) =>
      _accionPedido(pedidoId, 'RECIBIR');

  Future<void> confirmarRecepcionConAjuste({
    required String pedidoId,
    required Map<String, int> cantidadesAceptadas,
    required String motivoObservacion,
  }) => _accionPedido(
    pedidoId,
    'RECIBIR',
    cantidades: cantidadesAceptadas,
    motivo: motivoObservacion,
  );

  /// Compatibilidad: un despacho necesita cantidades y modalidad explícitas.
  Future<void> atenderSolicitudAbastecimiento({
    required String pedidoId,
    String? notasDespacho,
  }) async {
    throw const AlmacenException(
      'Utiliza Atender y Despachar para seleccionar cantidades y modalidad.',
    );
  }
}

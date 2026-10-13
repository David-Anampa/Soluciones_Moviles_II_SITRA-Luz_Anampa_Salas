import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lote_model.dart';
import '../models/medicamento_model.dart';
import '../models/pedido_abastecimiento_model.dart';
import '../models/stock_almacen_model.dart';

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

  /// HU-029: Registra una nueva solicitud de abastecimiento.
  Future<PedidoAbastecimientoModel> crearPedidoAbastecimiento({
    required String areaDestino,
    required String turno,
    required String justificacion,
    required String notas,
    required Map<String, int> items, // medicamentoId : cantidadSolicitada
  }) async {
    try {
      String? currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        final profile = await _supabase
            .from('profiles')
            .select('id')
            .limit(1)
            .maybeSingle();
        currentUserId = profile?['id'] as String?;
      }

      // 1. Crear la cabecera del pedido
      final response = await _supabase
          .from('pedidos_abastecimiento')
          .insert({
            'codigo': 'REQ-${DateTime.now().millisecondsSinceEpoch}',
            'area_origen': 'FARMACIA', // Desde donde se pide
            'area_destino': areaDestino, // A donde se pide (Almacen)
            'solicitante_id': currentUserId,
            'estado': 'PENDIENTE',
            'turno': turno,
            'justificacion': justificacion,
            'notas': notas.isEmpty ? null : notas,
          })
          .select()
          .single();

      final pedidoId = response['id'];

      // 2. Insertar los ítems
      final itemsToInsert = items.entries.map((entry) {
        return {
          'pedido_id': pedidoId,
          'medicamento_id': entry.key,
          'cantidad_solicitada': entry.value,
        };
      }).toList();

      await _supabase
          .from('pedidos_abastecimiento_items')
          .insert(itemsToInsert);

      // 3. Auditoría del pedido creado
      await _supabase.from('auditoria_trazabilidad').insert({
        'tipo_evento': 'CREACION_PEDIDO',
        'entidad_referencia_id': pedidoId,
        'tabla_referencia': 'pedidos_abastecimiento',
        'usuario_id': currentUserId,
        'area_origen': 'FARMACIA',
        'area_destino': areaDestino,
        'descripcion':
            'Se ha creado un pedido de abastecimiento ($turno) con ${items.length} ítems. Justificación: $justificacion',
      });

      return PedidoAbastecimientoModel.fromMap(response);
    } catch (e) {
      debugPrint('⚠️ Error al crear pedido de abastecimiento: $e');
      throw AlmacenException('Error al crear la solicitud: $e');
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
      debugPrint(
        '⚠️ Error al consultar inventario en Supabase: $e. Retornando datos base de contingencia.',
      );
      return _getMockInventario();
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
      debugPrint(
        '⚠️ Error al consultar catálogo de medicamentos: $e. Usando catálogo de contingencia.',
      );
      return _getMockMedicamentos();
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
      // 1. Insertar el lote en public.lotes
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
        if (justificacion != null && justificacion.isNotEmpty)
          'justificacion': justificacion.trim(),
        if (temperaturaRecepcion != null)
          'temperatura_recepcion': temperaturaRecepcion,
        if (observaciones != null && observaciones.isNotEmpty)
          'observaciones': observaciones.trim(),
        'activo': true,
      };

      final loteInsertResponse = await _supabase
          .from('lotes')
          .insert(loteData)
          .select()
          .single();

      final loteModel = LoteModel.fromMap(loteInsertResponse);

      // 2. Insertar el stock inicial en public.inventario_stock para Almacén General
      await _supabase.from('inventario_stock').insert({
        'lote_id': loteModel.id,
        'area_codigo': 'ALMACEN',
        'cantidad': cantidadInicial,
      });

      // 3. Registrar auditoría inmutable
      final currentUserId = _supabase.auth.currentUser?.id;
      await _supabase.from('auditoria_trazabilidad').insert({
        'tipo_evento': 'INGRESO_ALMACEN',
        'medicamento_id': medicamentoId,
        'lote_id': loteModel.id,
        'usuario_id': currentUserId,
        'area_destino': 'ALMACEN',
        'cantidad': cantidadInicial,
        'descripcion':
            'Ingreso de mercadería: Lote ${loteModel.numeroLote} con $cantidadInicial unidades. Proveedor: ${proveedor ?? "Directo"}',
      });

      debugPrint(
        '✅ Ingreso de lote registrado exitosamente: ${loteModel.numeroLote}',
      );
      return loteModel;
    } on PostgrestException catch (e) {
      if (e.message.contains('numero_lote') || e.code == '23505') {
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

  /// Transfiere stock de un lote específico desde Almacén hacia Farmacia Central.
  Future<void> transferirStockAFarmacia({
    required String loteId,
    required String medicamentoId,
    required int cantidad,
    String? motivo,
  }) async {
    try {
      // 1. Obtener el stock actual en Almacén
      final stockAlmacenResp = await _supabase
          .from('inventario_stock')
          .select('id, cantidad')
          .eq('lote_id', loteId)
          .eq('area_codigo', 'ALMACEN')
          .maybeSingle();

      if (stockAlmacenResp == null) {
        throw const AlmacenException(
          'No se encontró stock registrado para este lote en Almacén.',
        );
      }

      final int stockActual = stockAlmacenResp['cantidad'] as int? ?? 0;
      if (stockActual < cantidad) {
        throw AlmacenException(
          'Stock insuficiente en Almacén. Disponible: $stockActual, solicitado: $cantidad.',
        );
      }

      // 2. Decrementar stock en Almacén
      final nuevoStockAlmacen = stockActual - cantidad;
      await _supabase
          .from('inventario_stock')
          .update({
            'cantidad': nuevoStockAlmacen,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', stockAlmacenResp['id']);

      // 3. Incrementar o insertar stock en Farmacia
      final stockFarmaciaResp = await _supabase
          .from('inventario_stock')
          .select('id, cantidad')
          .eq('lote_id', loteId)
          .eq('area_codigo', 'FARMACIA')
          .maybeSingle();

      if (stockFarmaciaResp != null) {
        final int stockFarmaciaActual =
            stockFarmaciaResp['cantidad'] as int? ?? 0;
        await _supabase
            .from('inventario_stock')
            .update({
              'cantidad': stockFarmaciaActual + cantidad,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', stockFarmaciaResp['id']);
      } else {
        await _supabase.from('inventario_stock').insert({
          'lote_id': loteId,
          'area_codigo': 'FARMACIA',
          'cantidad': cantidad,
        });
      }

      // 4. Registrar en auditoría inmutable
      final currentUserId = _supabase.auth.currentUser?.id;
      await _supabase.from('auditoria_trazabilidad').insert({
        'tipo_evento': 'TRANSFERENCIA_FARMACIA',
        'medicamento_id': medicamentoId,
        'lote_id': loteId,
        'usuario_id': currentUserId,
        'area_origen': 'ALMACEN',
        'area_destino': 'FARMACIA',
        'cantidad': cantidad,
        'descripcion':
            'Transferencia de $cantidad unidades hacia Farmacia Central. ${motivo != null && motivo.isNotEmpty ? "Motivo: $motivo" : ""}',
      });

      debugPrint(
        '✅ Transferencia a Farmacia completada exitosamente: $cantidad unidades.',
      );
    } on PostgrestException catch (e) {
      throw AlmacenException(
        'Error al transferir stock en Supabase: ${e.message}',
      );
    } catch (e) {
      if (e is AlmacenException) rethrow;
      throw AlmacenException('Error al procesar la transferencia de stock: $e');
    }
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

  // --- Datos de contingencia / offline ---

  List<MedicamentoModel> _getMockMedicamentos() {
    return [
      const MedicamentoModel(
        id: 'mock-med-1',
        gtin: '7750215001234',
        nombreComercial: 'Amoxicilina 500mg',
        principioActivo: 'Amoxicilina',
        presentacion: 'Cápsula',
        codArt: 'M-001',
        registroSanitario: 'RS-EE-04812',
        unidadPresentacion: 'cápsulas',
        cantidadPorPresentacion: 100,
        requiereCadenaFrio: false,
      ),
      const MedicamentoModel(
        id: 'mock-med-2',
        gtin: '7750215005678',
        nombreComercial: 'Paracetamol 1g Inyectable',
        principioActivo: 'Paracetamol',
        presentacion: 'Ampolla',
        codArt: 'M-002',
        registroSanitario: 'RS-EN-01294',
        unidadPresentacion: 'ampollas',
        cantidadPorPresentacion: 1,
        requiereCadenaFrio: false,
      ),
      const MedicamentoModel(
        id: 'mock-med-3',
        gtin: '7750215003456',
        nombreComercial: 'Insulina NPH Humana 100 UI/ml',
        principioActivo: 'Insulina Humana',
        presentacion: 'Frasco',
        codArt: 'M-003',
        registroSanitario: 'RS-BE-01582',
        unidadPresentacion: 'frascos',
        cantidadPorPresentacion: 1,
        requiereCadenaFrio: true,
        temperaturaMin: 2.0,
        temperaturaMax: 8.0,
      ),
      const MedicamentoModel(
        id: 'mock-med-4',
        gtin: '7750215009012',
        nombreComercial: 'Fentanilo 0.5mg/10ml',
        principioActivo: 'Citrato de Fentanilo',
        presentacion: 'Ampolla',
        codArt: 'M-004',
        registroSanitario: 'RS-EE-09312',
        unidadPresentacion: 'ampollas',
        cantidadPorPresentacion: 5,
        requiereCadenaFrio: false,
      ),
    ];
  }

  List<StockAlmacenModel> _getMockInventario() {
    final meds = _getMockMedicamentos();
    final hoy = DateTime.now();

    return [
      StockAlmacenModel(
        id: 'mock-stock-1',
        loteId: 'mock-lote-1',
        areaCodigo: 'ALMACEN',
        cantidad: 120,
        updatedAt: hoy,
        medicamento: meds[0],
        lote: LoteModel(
          id: 'mock-lote-1',
          medicamentoId: meds[0].id,
          numeroLote: 'L2026-A15',
          fechaVencimiento: hoy.add(const Duration(days: 180)),
          proveedor: 'Distribuidora Médica Sur',
          activo: true,
        ),
      ),
      StockAlmacenModel(
        id: 'mock-stock-2',
        loteId: 'mock-lote-2',
        areaCodigo: 'ALMACEN',
        cantidad: 15,
        updatedAt: hoy,
        medicamento: meds[1],
        lote: LoteModel(
          id: 'mock-lote-2',
          medicamentoId: meds[1].id,
          numeroLote: 'L2025-P02',
          fechaVencimiento: hoy.add(
            const Duration(days: 20),
          ), // Crítico < 30 días
          proveedor: 'Laboratorios Roche / Perú',
          activo: true,
        ),
      ),
      StockAlmacenModel(
        id: 'mock-stock-3',
        loteId: 'mock-lote-3',
        areaCodigo: 'ALMACEN',
        cantidad: 30,
        updatedAt: hoy,
        medicamento: meds[2],
        lote: LoteModel(
          id: 'mock-lote-3',
          medicamentoId: meds[2].id,
          numeroLote: 'L2027-INS8',
          fechaVencimiento: hoy.add(const Duration(days: 300)),
          proveedor: 'Novo Nordisk',
          temperaturaRecepcion: 4.1,
          activo: true,
        ),
      ),
    ];
  }
}

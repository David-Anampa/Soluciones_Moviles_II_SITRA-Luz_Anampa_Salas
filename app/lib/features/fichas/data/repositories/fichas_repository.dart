import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/ficha_catalogo_entities.dart';
import '../../domain/ficha_borrador.dart';

/// Repositorio de datos para el ciclo completo de fichas de pedido:
/// - HU-003, HU-004 y HU-005 (Registro, selección con stock y aplicación de kits)
/// - HU-006 y HU-007 (Listado con filtros dinámicos, detalle completo e historial)
/// - HU-008, HU-009, HU-010 y HU-011 (Estados de preparación, despacho parcial, entrega FEFO y anulación con contra-asiento)
/// - Refinamiento de contrato HU-025 (Kardex por medicamento y lote)
class FichasRepository {
  final SupabaseClient _supabase;

  FichasRepository({SupabaseClient? cliente})
    : _supabase = cliente ?? Supabase.instance.client;

  /// Un fallo al refrescar nunca convierte un guardado confirmado en un error.
  Future<ResultadoGuardadoFicha> guardarFichaConActualizacion({
    required String solicitudId,
    required FichaBorrador borrador,
  }) async {
    final ficha = await guardarFicha(
      solicitudId: solicitudId,
      borrador: borrador,
    );
    try {
      final datos = await Future.wait([
        listarFichasRecientes(area: borrador.areaOrigen),
        buscarCatalogoConStock(limite: 300),
      ]);
      return ResultadoGuardadoFicha(
        ficha: ficha,
        recientes: datos[0] as List<FichaRegistrada>,
        catalogo: datos[1] as List<MedicamentoStockFicha>,
      );
    } catch (_) {
      return ResultadoGuardadoFicha(ficha: ficha);
    }
  }

  /// Obtiene áreas autorizadas, financiamientos, doctores, receptores y kits activos.
  Future<ContextoRegistroFicha> obtenerContexto({String? area}) async {
    final respuesta = await _supabase.rpc(
      'contexto_registro_ficha_hu003',
      params: {'p_area': area},
    );
    if (respuesta is! Map) {
      throw Exception(
        'No se pudo obtener el contexto de registro de fichas. Aplica migracion_hu003_hu004_hu005_fichas_2026_11_06.sql.',
      );
    }
    return ContextoRegistroFicha.fromMap(Map<String, dynamic>.from(respuesta));
  }

  /// Consulta el catálogo con stock disponible en Farmacia en tiempo real (HU-004).
  Future<List<MedicamentoStockFicha>> buscarCatalogoConStock({
    String busqueda = '',
    int desde = 0,
    int limite = 150,
  }) async {
    final respuesta = await _supabase.rpc(
      'catalogo_stock_ficha_hu004',
      params: {
        'p_busqueda': busqueda.trim(),
        'p_desde': desde,
        'p_limite': limite,
      },
    );
    if (respuesta is! List) return const [];
    return respuesta
        .whereType<Map>()
        .map((m) => MedicamentoStockFicha.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  /// Lista las fichas recientes del área para seguimiento y edición en estado SOLICITADO (RF-003).
  Future<List<FichaRegistrada>> listarFichasRecientes({
    String? area,
    int limite = 30,
  }) async {
    final respuesta = await _supabase.rpc(
      'listar_fichas_recientes_hu003',
      params: {'p_area': area, 'p_limite': limite},
    );
    if (respuesta is! List) return const [];
    return respuesta
        .whereType<Map>()
        .map((m) => FichaRegistrada.fromMap(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  /// Lista fichas de pedido con filtros dinámicos según permisos por rol y área (HU-006).
  Future<List<FichaRegistrada>> listarFichasConFiltros({
    FiltrosListadoFichas filtros = const FiltrosListadoFichas(),
    int limite = 80,
  }) async {
    try {
      final respuesta = await _supabase.rpc(
        'listar_fichas_hu006',
        params: {
          'p_area': filtros.area == 'TODAS' ? null : filtros.area,
          'p_estado': filtros.estado == 'TODOS' ? null : filtros.estado,
          'p_tipo_ficha': filtros.tipoFicha == 'TODOS'
              ? null
              : filtros.tipoFicha,
          'p_prioridad': filtros.prioridad == 'TODAS'
              ? null
              : filtros.prioridad,
          'p_turno': filtros.turno == 'TODOS' ? null : filtros.turno,
          'p_busqueda': filtros.busqueda.trim().isEmpty
              ? null
              : filtros.busqueda.trim(),
          'p_limite': limite,
        },
      );
      if (respuesta is! List) return const [];
      return respuesta
          .whereType<Map>()
          .map((m) => FichaRegistrada.fromMap(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      final texto = '${e.code} ${e.message} ${e.details}'.toLowerCase();
      if (e.code == 'PGRST202' || texto.contains('listar_fichas_hu006')) {
        // Respaldo compatible con listar_fichas_recientes_hu003 si aún no se aplicó el SQL de Sprint 7
        final base = await listarFichasRecientes(
          area: filtros.area == 'TODAS' ? null : filtros.area,
          limite: limite,
        );
        return _filtrarEnMemoria(base, filtros);
      }
      rethrow;
    }
  }

  List<FichaRegistrada> _filtrarEnMemoria(
    List<FichaRegistrada> lista,
    FiltrosListadoFichas filtros,
  ) {
    final q = filtros.busqueda.trim().toLowerCase();
    return lista
        .where((f) {
          if (filtros.area != 'TODAS' && f.areaOrigen != filtros.area) {
            return false;
          }
          if (filtros.estado != 'TODOS' && f.estado != filtros.estado) {
            return false;
          }
          if (filtros.tipoFicha != 'TODOS' &&
              f.tipoFicha != filtros.tipoFicha) {
            return false;
          }
          if (filtros.prioridad != 'TODAS' &&
              f.prioridad != filtros.prioridad) {
            return false;
          }
          if (filtros.turno != 'TODOS' && f.turno != filtros.turno) {
            return false;
          }
          if (q.isNotEmpty) {
            final texto = [
              f.numeroFicha,
              f.pacienteNombre,
              f.madreNombre ?? '',
              f.recienNacidoApellidos ?? '',
              f.doctorNombre ?? '',
              f.recibidoPor ?? '',
              f.diagnosticoMotivo ?? '',
              f.kitNombre ?? '',
            ].join(' ').toLowerCase();
            if (!texto.contains(q)) return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Obtiene el detalle completo de una ficha con sus ítems, lotes FEFO despachados e historial (HU-007).
  Future<FichaRegistrada> obtenerDetalleFicha(String fichaId) async {
    try {
      final respuesta = await _supabase.rpc(
        'obtener_detalle_ficha_hu007',
        params: {'p_ficha_id': fichaId},
      );
      if (respuesta is! Map) {
        throw Exception('No se encontró el detalle de la ficha solicitada.');
      }
      return FichaRegistrada.fromMap(Map<String, dynamic>.from(respuesta));
    } on PostgrestException catch (e) {
      final texto = '${e.code} ${e.message} ${e.details}'.toLowerCase();
      if (e.code == 'PGRST202' ||
          texto.contains('obtener_detalle_ficha_hu007')) {
        final recientes = await listarFichasRecientes(limite: 100);
        final encontrada = recientes.where((f) => f.id == fichaId).firstOrNull;
        if (encontrada != null) return encontrada;
      }
      rethrow;
    }
  }

  /// Ejecuta de manera transaccional e idempotente una acción de atención sobre la ficha
  /// (`INICIAR_PREPARACION`, `GUARDAR_PREPARACION`, `MARCAR_LISTO_RECOJO`, `CONFIRMAR_ENTREGA`, `ANULAR_FICHA`)
  /// para HU-008, HU-009, HU-010 y HU-011.
  Future<FichaRegistrada> procesarFicha({
    required String operacionId,
    required String fichaId,
    required String accion,
    List<ItemDespachoEdicion> items = const [],
    String? notas,
    String? motivo,
    String? receptorId,
    String? recibidoPor,
  }) async {
    final respuesta = await _supabase.rpc(
      'procesar_ficha_dispensacion_hu008_hu011',
      params: {
        'p_operacion_id': operacionId,
        'p_ficha_id': fichaId,
        'p_accion': accion,
        'p_items': items.map((i) => i.toMap()).toList(growable: false),
        'p_notas': (notas != null && notas.trim().isNotEmpty)
            ? notas.trim()
            : null,
        'p_motivo': (motivo != null && motivo.trim().isNotEmpty)
            ? motivo.trim()
            : null,
        'p_receptor_id': (receptorId != null && receptorId.trim().isNotEmpty)
            ? receptorId.trim()
            : null,
        'p_recibido_por': (recibidoPor != null && recibidoPor.trim().isNotEmpty)
            ? recibidoPor.trim()
            : null,
      },
    );
    if (respuesta is! Map) {
      throw Exception('Respuesta inesperada al procesar la ficha de pedido.');
    }
    return FichaRegistrada.fromMap(Map<String, dynamic>.from(respuesta));
  }

  /// Consulta el contrato refinado de Kardex de un medicamento por lote (HU-025 para Sprint 8).
  Future<List<MovimientoKardexContratoHu025>> consultarKardexMedicamentoHu025(
    String medicamentoId, {
    int limite = 150,
  }) async {
    final respuesta = await _supabase.rpc(
      'consultar_kardex_medicamento_hu025',
      params: {'p_medicamento_id': medicamentoId, 'p_limite': limite},
    );
    if (respuesta is! List) {
      throw const FormatException(
        'Respuesta inesperada al consultar el Kardex.',
      );
    }
    return respuesta
        .whereType<Map>()
        .map(
          (m) => MovimientoKardexContratoHu025.fromMap(
            Map<String, dynamic>.from(m),
          ),
        )
        .toList(growable: false);
  }

  /// Registra o actualiza de forma atómica una ficha y la copia de sus ítems (HU-003 / HU-004 / HU-005).
  Future<FichaRegistrada> guardarFicha({
    required String solicitudId,
    required FichaBorrador borrador,
  }) async {
    final respuesta = await _supabase.rpc(
      'registrar_ficha_hu003',
      params: {
        'p_solicitud_id': solicitudId,
        'p_id': borrador.id,
        'p_datos': borrador.toMap(),
      },
    );
    if (respuesta is! Map) {
      throw Exception('Respuesta inesperada al guardar la ficha de pedido.');
    }
    return FichaRegistrada.fromMap(Map<String, dynamic>.from(respuesta));
  }

  /// Traduce excepciones de red y PostgreSQL a mensajes claros para el usuario.
  static String mensajeError(
    Object error, [
    String respaldo = 'No se pudo completar la operación en fichas.',
  ]) {
    if (error is PostgrestException) {
      final msg = error.message.trim();
      final texto = '${error.code} $msg ${error.details} ${error.hint}'
          .toLowerCase();
      if (texto.contains('procesar_ficha_dispensacion_hu008_hu011') ||
          texto.contains('listar_fichas_hu006') ||
          texto.contains('obtener_detalle_ficha_hu007') ||
          texto.contains('consultar_kardex_medicamento_hu025')) {
        return 'Falta aplicar en Supabase la migración '
            'docs/supabase/migracion_hu006_a_hu011_atencion_fichas_2026_11_12.sql.';
      }
      if (error.code == 'PGRST202' ||
          texto.contains('contexto_registro_ficha_hu003') ||
          texto.contains('catalogo_stock_ficha_hu004') ||
          texto.contains('registrar_ficha_hu003')) {
        return 'Falta aplicar en Supabase la migración '
            'docs/supabase/migracion_hu003_hu004_hu005_fichas_2026_11_06.sql.';
      }
      if (msg.isNotEmpty) return msg;
    }
    final limpio = error.toString().replaceFirst('Exception: ', '').trim();
    return limpio.isEmpty ? respaldo : limpio;
  }
}

class ResultadoGuardadoFicha {
  final FichaRegistrada ficha;
  final List<FichaRegistrada>? recientes;
  final List<MedicamentoStockFicha>? catalogo;

  const ResultadoGuardadoFicha({
    required this.ficha,
    this.recientes,
    this.catalogo,
  });

  bool get actualizacionPendiente => recientes == null || catalogo == null;
}

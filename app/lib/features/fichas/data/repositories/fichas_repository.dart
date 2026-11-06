import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/ficha_catalogo_entities.dart';
import '../../domain/ficha_borrador.dart';

/// Repositorio de datos para HU-003, HU-004 y HU-005.
/// Consume únicamente RPCs atómicas y de lectura autorizada en Supabase.
class FichasRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

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
      params: {
        'p_area': area,
        'p_limite': limite,
      },
    );
    if (respuesta is! List) return const [];
    return respuesta
        .whereType<Map>()
        .map((m) => FichaRegistrada.fromMap(Map<String, dynamic>.from(m)))
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


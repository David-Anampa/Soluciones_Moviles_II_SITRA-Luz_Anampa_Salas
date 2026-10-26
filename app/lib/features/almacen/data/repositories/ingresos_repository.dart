import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/solicitud_id.dart';

/// HU-024: envíos repetidos conservan la clave y toda escritura pasa por una RPC.
class IngresosRepository {
  final SupabaseClient? client;
  String? _firma, _operacion;
  IngresosRepository({this.client});
  SupabaseClient get _db => client ?? Supabase.instance.client;
  Future<Map<String, dynamic>> registrar(
    Map<String, dynamic> datos, {
    Map<String, dynamic>? medicamento,
  }) async {
    final firma = jsonEncode([_db.auth.currentUser?.id, datos, medicamento]);
    if (_firma != firma) {
      _firma = firma;
      _operacion = generarSolicitudId();
    }
    final clave = _operacion!;
    final result = await _db.rpc(
      'registrar_ingreso_lote_hu024',
      params: {
        'p_operacion_id': clave,
        'p_datos': datos,
        'p_medicamento': medicamento,
      },
    );
    if (_operacion == clave) {
      _firma = null;
      _operacion = null;
    }
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> listar() async {
    final result = await _db.rpc('consultar_ingresos_hu024');
    return (result as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<void> corregir({
    required String loteId,
    required int total,
    required String ubicacion,
    required String motivo,
    required String version,
    required String operacion,
  }) async {
    await _db.rpc(
      'corregir_ingreso_lote_hu024',
      params: {
        'p_lote_id': loteId,
        'p_total': total,
        'p_ubicacion': ubicacion,
        'p_motivo': motivo,
        'p_version': version,
        'p_operacion_id': operacion,
      },
    );
  }
}

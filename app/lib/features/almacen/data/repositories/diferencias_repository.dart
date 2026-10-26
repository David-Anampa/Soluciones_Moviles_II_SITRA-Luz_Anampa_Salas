import 'package:supabase_flutter/supabase_flutter.dart';

/// La base decide permisos, versiones, cálculo y auditoría en una transacción.
class DiferenciasRepository {
  final SupabaseClient? client;
  const DiferenciasRepository({this.client});
  SupabaseClient get _db => client ?? Supabase.instance.client;
  Future<List<Map<String, dynamic>>> listar() async {
    final datos = await _db.rpc('consultar_diferencias_abastecimiento');
    return (datos as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> gestionar({
    required String pedidoId,
    required String accion,
    required String motivo,
    required String operacionId,
    Map<String, int> cantidades = const {},
    String? destino,
    int version = 0,
    String? saldoVersion,
  }) async {
    await _db.rpc(
      'gestionar_diferencia_abastecimiento',
      params: {
        'p_pedido_id': pedidoId,
        'p_accion': accion,
        'p_motivo': motivo,
        'p_cantidades': cantidades,
        'p_destino': destino,
        'p_version': version,
        'p_operacion_id': operacionId,
        'p_saldo_version': saldoVersion,
      },
    );
  }
}

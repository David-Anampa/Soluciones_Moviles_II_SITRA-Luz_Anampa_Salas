import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/stock_ubicacion_entity.dart';

/// Lee únicamente cantidades reales; una falta de conexión nunca genera stock ficticio.
class StockUbicacionesRepository {
  final SupabaseClient? client;
  const StockUbicacionesRepository({this.client});
  Future<List<StockUbicacionEntity>> cargar({
    bool incluirLaboratorio = false,
  }) async {
    final datos = <StockUbicacionEntity>[];
    final db = client ?? Supabase.instance.client;
    final laboratorios = <String, String>{};
    if (incluirLaboratorio) {
      for (var offset = 0; ; offset += 500) {
        final rows = await db
            .from('medicamentos')
            .select('id,laboratorio')
            .order('id')
            .range(offset, offset + 499);
        for (final row in rows) {
          laboratorios[row['id'] as String] =
              (row['laboratorio'] as String? ?? '').trim();
        }
        if (rows.length < 500) break;
      }
    }
    for (var desde = 0; ; desde += 200) {
      final rows = await db.rpc(
        'consultar_stock_ubicaciones',
        params: {'p_busqueda': '', 'p_desde': desde, 'p_limite': 200},
      );
      final page = (rows as List).cast<Map<String, dynamic>>();
      datos.addAll(
        page.map(
          (m) => StockUbicacionEntity.fromMap({
            ...m,
            'laboratorio': laboratorios[m['medicamento_id']] ?? '',
          }),
        ),
      );
      if (page.length < 200) break;
    }
    return datos;
  }
}

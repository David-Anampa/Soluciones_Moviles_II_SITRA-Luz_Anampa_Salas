import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/stock_ubicacion_entity.dart';

/// Lee únicamente cantidades reales; una falta de conexión nunca genera stock ficticio.
class StockUbicacionesRepository {
  final SupabaseClient? client;
  const StockUbicacionesRepository({this.client});
  Future<List<StockUbicacionEntity>> cargar() async {
    final datos = <StockUbicacionEntity>[];
    final db = client ?? Supabase.instance.client;
    for (var desde = 0; ; desde += 200) {
      final rows = await db.rpc(
        'consultar_stock_ubicaciones',
        params: {'p_busqueda': '', 'p_desde': desde, 'p_limite': 200},
      );
      final page = (rows as List).cast<Map<String, dynamic>>();
      datos.addAll(page.map(StockUbicacionEntity.fromMap));
      if (page.length < 200) break;
    }
    return datos;
  }
}

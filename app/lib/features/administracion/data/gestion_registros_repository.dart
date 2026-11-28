import 'package:supabase_flutter/supabase_flutter.dart';

class GestionRegistrosRepository {
  final _db = Supabase.instance.client;
  Future<Map<String, dynamic>> cargar() async => Map<String, dynamic>.from(
    await _db
            .rpc('relaciones_gestion_admin')
            .timeout(const Duration(seconds: 20))
        as Map,
  );
  Future<Map<String, dynamic>> detalle(String entidad, String id) async =>
      Map<String, dynamic>.from(
        await _db
                .rpc(
                  'referencias_gestion_admin',
                  params: {'p_entidad': entidad, 'p_id': id},
                )
                .timeout(const Duration(seconds: 20))
            as Map,
      );
  Future<void> eliminar(String entidad, String id, String? version) async {
    await _db
        .rpc(
          'eliminar_registro_gestion_admin',
          params: {'p_entidad': entidad, 'p_id': id, 'p_version': version},
        )
        .timeout(const Duration(seconds: 20));
  }

  static bool permite(Map<String, dynamic> datos, String entidad, String id) =>
      (datos['$entidad:$id'] as Map?)?['puede_eliminar'] == true;
  static String motivo(Map<String, dynamic> datos, String entidad, String id) =>
      (datos['$entidad:$id'] as Map?)?['motivo'] as String? ??
      'Consultando relaciones; usa Ver detalle';
}

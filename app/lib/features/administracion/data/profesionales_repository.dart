import 'package:supabase_flutter/supabase_flutter.dart';

class ProfesionalesRepository {
  final _db = Supabase.instance.client;
  Future<Map<String, dynamic>> cargar() async => Map<String, dynamic>.from(
    await _db
            .rpc('listar_profesionales_admin')
            .timeout(const Duration(seconds: 20))
        as Map,
  );
  Future<void> guardar({
    required String id,
    required String nombre,
    required String colegio,
    required String numero,
    required Set<String> areas,
    String? version,
  }) async {
    await _db
        .rpc(
          'guardar_profesional_admin',
          params: {
            'p_id': id,
            'p_nombre': nombre.trim(),
            'p_colegio': colegio,
            'p_numero': numero.trim(),
            'p_areas': areas.toList(),
            'p_version': version,
          },
        )
        .timeout(const Duration(seconds: 20));
  }

  Future<void> estado(Map<String, dynamic> registro) async {
    await _db
        .rpc(
          'estado_profesional_admin',
          params: {
            'p_id': registro['id'],
            'p_activo': registro['activo'] != true,
            'p_version': registro['updated_at'],
          },
        )
        .timeout(const Duration(seconds: 20));
  }

  Future<void> colegio(String nombre, String sigla) async {
    await _db
        .rpc(
          'agregar_colegio_admin',
          params: {'p_nombre': nombre.trim(), 'p_sigla': sigla.trim()},
        )
        .timeout(const Duration(seconds: 20));
  }

  static String error(Object error) => error is PostgrestException
      ? error.message
      : 'No se pudo confirmar la operación. Conserva los datos y actualiza la lista antes de reintentar.';
}

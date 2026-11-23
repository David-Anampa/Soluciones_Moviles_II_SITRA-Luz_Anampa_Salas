import 'package:supabase_flutter/supabase_flutter.dart';

/// Solo metadatos: ninguna consulta devuelve el valor de una credencial.
class ClaveIa {
  final String id, nombre;
  final bool activa;
  final DateTime creada, actualizada;
  ClaveIa.fromMap(Map<String, dynamic> m)
    : id = m['id'] as String,
      nombre = m['nombre'] as String,
      activa = m['activa'] == true,
      creada = DateTime.parse(m['creado_en'] as String).toLocal(),
      actualizada = DateTime.parse(m['actualizado_en'] as String).toLocal();
}

class ClavesIaRepository {
  final SupabaseClient _client;
  ClavesIaRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<List<ClaveIa>> listar() async {
    final data = await _client.rpc('listar_claves_ia') as List;
    return data
        .map((m) => ClaveIa.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> gestionar(
    String accion, {
    String? id,
    String? nombre,
    String? clave,
  }) async {
    await _client.rpc(
      'gestionar_clave_ia',
      params: {
        'p_accion': accion,
        'p_id': id,
        'p_nombre': nombre,
        'p_clave': clave,
      },
    );
  }

  static String mensajeError(Object error) {
    if (error is PostgrestException &&
        ['22023', '42501'].contains(error.code)) {
      return error.message;
    }
    return 'No se pudo completar la operación. Comprueba tu conexión y vuelve a intentar.';
  }
}

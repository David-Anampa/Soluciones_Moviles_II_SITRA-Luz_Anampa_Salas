import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../administracion/data/catalogos_repository.dart';
import '../../domain/entities/kit_entity.dart';
import '../../domain/kit_borrador.dart';

class AreaKit {
  final String id;
  final String codigo;
  final String codigoInterno;
  final String nombre;
  final bool activo;

  const AreaKit({
    required this.id,
    required this.codigo,
    required this.codigoInterno,
    required this.nombre,
    required this.activo,
  });

  factory AreaKit.fromMap(Map<String, dynamic> row) => AreaKit(
        id: row['id'] as String,
        codigo: row['codigo'] as String? ?? row['codigo_interno'] as String,
        codigoInterno: row['codigo_interno'] as String? ?? row['codigo'] as String,
        nombre: row['nombre'] as String,
        activo: row['activo'] as bool? ?? true,
      );
}

class KitsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Traduce excepciones de Supabase / PostgreSQL a mensajes comprensibles para el personal clínico.
  static String mensajeError(Object e) {
    if (e is PostgrestException) {
      if (e.code == 'PGRST202' || e.code == '42883') {
        return 'Falta actualizar las funciones de kits en Supabase. No se realizó una operación alternativa; aplica la migración del módulo y vuelve a intentar.';
      }
      final msg = e.message.trim();
      if (msg.contains('No tienes permisos')) {
        return 'No tienes permisos para realizar esta acción sobre los kits.';
      }
      if (msg.contains('Ya existe un kit con el nombre')) {
        return msg;
      }
      if (msg.contains('fichas y dispensaciones históricas asociadas')) {
        return 'El kit tiene fichas históricas asociadas. No se puede eliminar; desactívalo para conservarlo en el historial.';
      }
      if (msg.contains('debe contener al menos un medicamento')) {
        return 'El kit debe contener al menos un medicamento con su cantidad.';
      }
      if (msg.contains('no existe o se encuentra inactiva')) {
        return msg;
      }
      if (e.code == '42501') {
        return 'Permiso denegado por las políticas de seguridad RLS.';
      }
      return msg.isNotEmpty ? msg : 'Error de base de datos (${e.code}).';
    }
    return e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  /// HU-017: consulta kits reales mediante la RPC con sus reglas de acceso.
  /// Si falta la función, informa el problema; no presume relaciones FK ni
  /// reemplaza los resultados por consultas con permisos diferentes.
  Future<List<KitEntity>> listarKits({String? area, bool? soloActivos}) async {
    try {
      final data = await _client.rpc('listar_kits_hu017', params: {
        'p_area': area,
        'p_solo_activos': soloActivos,
      });
      final rows = (data as List<dynamic>).cast<Map<String, dynamic>>();
      return rows.map(KitEntity.fromMap).toList();
    } on PostgrestException catch (e) {
      throw Exception(mensajeError(e));
    } catch (e) {
      throw Exception(mensajeError(e));
    }
  }

  /// Carga el catálogo dinámico de áreas activas para el selector de área destino
  Future<List<AreaKit>> cargarAreasActivas() async {
    try {
      final rows = await _client
          .from('areas')
          .select('id, codigo, codigo_interno, nombre, activo')
          .eq('activo', true)
          .order('nombre');
      return (rows as List<dynamic>)
          .map((r) => AreaKit.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(mensajeError(e));
    }
  }

  /// Busca medicamentos reales en el catálogo maestro para agregar al kit
  Future<List<MedicamentoCobertura>> buscarMedicamentos({String query = ''}) async {
    try {
      var builder = _client
          .from('medicamentos')
          .select('id, nombre_comercial, presentacion, precio_kairos, activo')
          .eq('activo', true);

      if (query.trim().isNotEmpty) {
        builder = builder.ilike('nombre_comercial', '%${query.trim()}%');
      }

      final rows = await builder.order('nombre_comercial').limit(60);
      return (rows as List<dynamic>)
          .map((r) => MedicamentoCobertura.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(mensajeError(e));
    }
  }

  /// HU-018 (Crear kit) y HU-019 (Editar kit):
  /// Guarda atómicamente la plantilla de kit mediante la RPC transaccional.
  Future<String> guardarKit(KitBorrador borrador, {String? id}) async {
    try {
      final result = await _client.rpc('administrar_kit_hu018', params: {
        'p_accion': 'GUARDAR',
        'p_id': id,
        'p_datos': borrador.toMap(),
      });
      return result.toString();
    } on PostgrestException catch (e) {
      throw Exception(mensajeError(e));
    } catch (e) {
      throw Exception(mensajeError(e));
    }
  }

  /// HU-017: Habilita o inhabilita un kit para futuras dispensaciones conservando su historial.
  Future<void> cambiarEstado(String id, bool activo) async {
    try {
      await _client.rpc('administrar_kit_hu018', params: {
        'p_accion': 'ESTADO',
        'p_id': id,
        'p_datos': {'activo': activo},
      });
    } on PostgrestException catch (e) {
      throw Exception(mensajeError(e));
    } catch (e) {
      throw Exception(mensajeError(e));
    }
  }

  /// Eliminación controlada de un kit (solo si no tiene dispensaciones previas).
  Future<void> eliminarKit(String id) async {
    try {
      await _client.rpc('administrar_kit_hu018', params: {
        'p_accion': 'ELIMINAR',
        'p_id': id,
      });
    } on PostgrestException catch (e) {
      throw Exception(mensajeError(e));
    } catch (e) {
      throw Exception(mensajeError(e));
    }
  }
}

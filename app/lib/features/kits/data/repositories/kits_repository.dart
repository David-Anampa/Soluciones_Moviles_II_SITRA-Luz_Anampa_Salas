import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/kit_entity.dart';
import '../../domain/kit_borrador.dart';

class AreaKit {
  final String id;
  final String codigo;
  final String codigoInterno;
  final String nombre;
  final bool activo;
  final String temaColor;

  const AreaKit({
    required this.id,
    required this.codigo,
    required this.codigoInterno,
    required this.nombre,
    required this.activo,
    this.temaColor = 'ROJO',
  });

  factory AreaKit.fromMap(Map<String, dynamic> row) => AreaKit(
    id: row['id'] as String,
    codigo: row['codigo'] as String? ?? row['codigo_interno'] as String,
    codigoInterno: row['codigo_interno'] as String? ?? row['codigo'] as String,
    nombre: row['nombre'] as String,
    activo: row['activo'] as bool? ?? true,
    temaColor: row['tema_color'] as String? ?? 'ROJO',
  );
}

/// Áreas y permiso obtenidos del servidor, nunca deducidos del nombre del usuario.
class ContextoKits {
  final String rol;
  final bool puedeGestionar;
  final List<AreaKit> areas;
  const ContextoKits(this.rol, this.puedeGestionar, this.areas);
  factory ContextoKits.fromMap(Map<String, dynamic> datos) => ContextoKits(
    datos['rol'] as String,
    datos['puede_gestionar'] == true,
    (datos['areas'] as List)
        .map((a) => AreaKit.fromMap(Map<String, dynamic>.from(a)))
        .toList(),
  );
}

/// Cantidades disponibles en cada ubicación; un kit nunca consume este catálogo.
class MedicamentoKit {
  final String id, nombre, presentacion, laboratorio;
  final int farmacia, almacen, transito;
  final bool activo;
  const MedicamentoKit({
    required this.id,
    required this.nombre,
    required this.presentacion,
    required this.laboratorio,
    required this.farmacia,
    required this.almacen,
    required this.transito,
    required this.activo,
  });
  factory MedicamentoKit.fromMap(Map<String, dynamic> m) => MedicamentoKit(
    id: m['id'] as String,
    nombre: m['nombre'] as String,
    presentacion: m['presentacion'] as String? ?? '',
    laboratorio: m['laboratorio'] as String? ?? '',
    farmacia: (m['farmacia'] as num).toInt(),
    almacen: (m['almacen'] as num).toInt(),
    transito: (m['transito'] as num).toInt(),
    activo: m['activo'] == true,
  );
}

class KitsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Traduce excepciones de Supabase / PostgreSQL a mensajes comprensibles para el personal clínico.
  static String mensajeError(Object e) {
    if (e is PostgrestException) {
      if (e.code == 'PGRST202' || e.code == '42883') {
        return 'Aplica migracion_kits_por_area_2026_10_26.sql en Supabase y vuelve a intentar. No se guardaron datos mediante operaciones alternativas.';
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
      final data = await _client.rpc(
        'listar_kits_hu017',
        params: {'p_area': area, 'p_solo_activos': soloActivos},
      );
      final rows = (data as List<dynamic>).cast<Map<String, dynamic>>();
      return rows.map(KitEntity.fromMap).toList();
    } on PostgrestException catch (e) {
      throw Exception(mensajeError(e));
    } catch (e) {
      throw Exception(mensajeError(e));
    }
  }

  /// Consulta los permisos vigentes y las áreas propias; incluye asignaciones históricas.
  Future<ContextoKits> contexto() async {
    final datos = await _client.rpc('contexto_kits_por_area');
    return ContextoKits.fromMap(Map<String, dynamic>.from(datos));
  }

  /// Ofrece solo áreas habilitadas y autorizadas, sin consultar el catálogo global.
  Future<List<AreaKit>> cargarAreasActivas() async {
    return (await contexto()).areas.where((a) => a.activo).toList();
  }

  /// Busca medicamentos reales en el catálogo maestro para agregar al kit
  Future<List<MedicamentoKit>> buscarMedicamentos({String query = ''}) async {
    final resultado = <MedicamentoKit>[];
    for (var desde = 0; ; desde += 100) {
      final datos = await _client.rpc(
        'medicamentos_para_kits',
        params: {'p_busqueda': query.trim(), 'p_desde': desde, 'p_limite': 100},
      );
      final filas = (datos as List).cast<Map<String, dynamic>>();
      resultado.addAll(filas.map(MedicamentoKit.fromMap));
      if (filas.length < 100) break;
    }
    return resultado;
  }

  /// HU-018 (Crear kit) y HU-019 (Editar kit):
  /// Guarda atómicamente la plantilla de kit mediante la RPC transaccional.
  Future<String> guardarKit(
    KitBorrador borrador, {
    String? id,
    String? origenId,
  }) async {
    try {
      final result = await _client.rpc(
        'administrar_kit_hu018',
        params: {
          'p_accion': 'GUARDAR',
          'p_id': id,
          'p_datos': {
            ...borrador.toMap(),
            if (origenId != null) 'kit_origen_id': origenId,
          },
        },
      );
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
      await _client.rpc(
        'administrar_kit_hu018',
        params: {
          'p_accion': 'ESTADO',
          'p_id': id,
          'p_datos': {'activo': activo},
        },
      );
    } on PostgrestException catch (e) {
      throw Exception(mensajeError(e));
    } catch (e) {
      throw Exception(mensajeError(e));
    }
  }

  /// Eliminación controlada de un kit (solo si no tiene dispensaciones previas).
  Future<void> eliminarKit(String id) async {
    try {
      await _client.rpc(
        'administrar_kit_hu018',
        params: {'p_accion': 'ELIMINAR', 'p_id': id},
      );
    } on PostgrestException catch (e) {
      throw Exception(mensajeError(e));
    } catch (e) {
      throw Exception(mensajeError(e));
    }
  }
}

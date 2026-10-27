import 'package:supabase_flutter/supabase_flutter.dart';

class AreaCatalogo {
  final String id, codigo, nombre, descripcion;
  final bool activo, administraStock;
  final String temaColor;

  /// Construye el registro de área que utilizan la lista y el formulario de HU-012.
  const AreaCatalogo({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.activo,
    required this.administraStock,
    this.temaColor = 'ROJO',
  });

  /// Convierte una fila de areas al modelo de la interfaz.
  /// Usa codigo_interno como código visible; no expone el alias operativo codigo.
  factory AreaCatalogo.fromMap(Map<String, dynamic> row) => AreaCatalogo(
    id: row['id'] as String,
    codigo: row['codigo_interno'] as String,
    nombre: row['nombre'] as String,
    descripcion: row['descripcion'] as String? ?? '',
    activo: row['activo'] as bool,
    administraStock: row['administra_stock'] as bool,
    temaColor: row['tema_color'] as String? ?? 'ROJO',
  );
}

class FinanciamientoCatalogo {
  final String id, nombre, descripcion, tipo;
  final double porcentaje;
  final bool activo;
  final Set<String> medicamentos;

  /// Agrupa los datos del seguro/convenio y los IDs de medicamentos incluidos.
  const FinanciamientoCatalogo({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.tipo,
    required this.porcentaje,
    required this.activo,
    required this.medicamentos,
  });

  /// Convierte la consulta de financiamientos y su cobertura al modelo de edición.
  /// El conjunto de IDs evita repetir medicamentos seleccionados.
  factory FinanciamientoCatalogo.fromMap(Map<String, dynamic> row) =>
      FinanciamientoCatalogo(
        id: row['id'] as String,
        nombre: row['nombre'] as String,
        descripcion: row['descripcion'] as String? ?? '',
        tipo: row['tipo'] as String,
        porcentaje: (row['porcentaje_descuento'] as num).toDouble(),
        activo: row['activo'] as bool,
        medicamentos: (row['cobertura'] as List<dynamic>)
            .map((e) => (e as Map<String, dynamic>)['medicamento_id'] as String)
            .toSet(),
      );
}

class MedicamentoCobertura {
  final String id, nombre, presentacion;
  final double? kairos;
  final bool activo;

  /// Representa un medicamento seleccionable y su precio Kairos, si está registrado.
  const MedicamentoCobertura({
    required this.id,
    required this.nombre,
    required this.presentacion,
    this.kairos,
    required this.activo,
  });

  /// Lee los campos del medicamento usados para buscar cobertura y mostrar precios.
  /// Conserva Kairos ausente como null; no lo interpreta como un precio cero.
  factory MedicamentoCobertura.fromMap(Map<String, dynamic> row) =>
      MedicamentoCobertura(
        id: row['id'] as String,
        nombre: row['nombre_comercial'] as String,
        presentacion: row['presentacion'] as String? ?? '',
        kairos: (row['precio_kairos'] as num?)?.toDouble(),
        activo: row['activo'] as bool,
      );
}

/// HU-012: lecturas reales y escrituras atómicas; no utiliza datos de demostración.
class CatalogosRepository {
  /// Obtiene el cliente compartido de Supabase con la sesión activa del usuario.
  SupabaseClient get _client => Supabase.instance.client;

  /// Consulta areas ordenadas por nombre, incluyendo habilitadas y deshabilitadas.
  /// Devuelve los campos necesarios para tarjetas y edición, sin modificar datos.
  Future<List<AreaCatalogo>> areas() async {
    final rows = await _client
        .from('areas')
        .select(
          'id,codigo_interno,nombre,descripcion,activo,administra_stock,tema_color',
        )
        .order('nombre');
    return rows.map(AreaCatalogo.fromMap).toList();
  }

  /// Consulta seguros/convenios y sus medicamentos relacionados en una sola lectura.
  /// El alias cobertura corresponde a financiamiento_medicamentos.
  Future<List<FinanciamientoCatalogo>> financiamientos() async {
    final rows = await _client
        .from('financiamientos')
        .select('*,cobertura:financiamiento_medicamentos(medicamento_id)')
        .order('nombre');
    return rows.map(FinanciamientoCatalogo.fromMap).toList();
  }

  /// Consulta el catálogo en páginas de 500 filas para no truncar listas grandes.
  /// Incluye activos e inactivos; el editor conserva la cobertura anterior y decide
  /// cuáles se ofrecen como nuevas selecciones.
  Future<List<MedicamentoCobertura>> medicamentos() async {
    final result = <MedicamentoCobertura>[];
    const pagina = 500;
    for (var inicio = 0; ; inicio += pagina) {
      final rows = await _client
          .from('medicamentos')
          .select('id,nombre_comercial,presentacion,precio_kairos,activo')
          .order('nombre_comercial')
          .order('id')
          .range(inicio, inicio + pagina - 1);
      result.addAll(rows.map(MedicamentoCobertura.fromMap));
      if (rows.length < pagina) return result;
    }
  }

  /// Solicita crear o editar un área/financiamiento mediante la RPC administrativa.
  /// Sin id crea; con id edita. El servidor valida permisos y guarda datos,
  /// cobertura y auditoría de forma atómica.
  Future<void> guardar(
    String entidad,
    Map<String, dynamic> datos, {
    String? id,
  }) async {
    if (entidad == 'AREA') {
      await _client.rpc(
        'guardar_area_con_tema',
        params: {'p_id': id, 'p_datos': datos},
      );
      return;
    }
    await _client.rpc(
      'administrar_catalogo_hu012',
      params: {
        'p_entidad': entidad,
        'p_accion': 'GUARDAR',
        'p_id': id,
        'p_datos': datos,
      },
    );
  }

  /// Envía la nueva habilitación a la RPC; no elimina registros ni asociaciones.
  /// El bool activo representa el estado deseado, no una inversión en el servidor.
  Future<void> cambiarEstado(String entidad, String id, bool activo) async {
    await _client.rpc(
      'administrar_catalogo_hu012',
      params: {
        'p_entidad': entidad,
        'p_accion': 'ESTADO',
        'p_id': id,
        'p_datos': {'activo': activo},
      },
    );
  }

  /// Solicita eliminar el registro identificado por entidad e id.
  /// La RPC comprueba asociaciones y permisos; si existen, rechaza el borrado.
  Future<void> eliminar(String entidad, String id) async {
    await _client.rpc(
      'administrar_catalogo_hu012',
      params: {'p_entidad': entidad, 'p_accion': 'ELIMINAR', 'p_id': id},
    );
  }

  /// Traduce fallos de autenticación, permisos, estructura y asociaciones para la UI.
  /// Solo transforma el mensaje: no oculta el error con registros de demostración.
  static String mensajeError(Object error) {
    if (error is AuthException) return error.message;
    if (error is PostgrestException) {
      if (error.message.contains('tema_color') ||
          error.message.contains('guardar_area_con_tema')) {
        return 'Aplica migracion_temas_areas_2026_10_26.sql en Supabase para configurar los temas de las áreas.';
      }
      if (error.code == '42P01' ||
          error.code == '42703' ||
          (error.code?.startsWith('PGRST') ?? false)) {
        return 'No se pudo cargar el catálogo. Si es la primera vez, aplica la migración HU-012 en Supabase y vuelve a intentar.';
      }
      if (error.code == '42501') {
        return 'Tu sesión no tiene permisos para esta operación.';
      }
      if (error.code == '23503') {
        return 'Tiene registros asociados. Deshabilítalo para conservar el historial.';
      }
      if (error.code == '23505') {
        return 'Ya existe un registro con ese nombre o código.';
      }
      return error.message;
    }
    return 'No se pudo completar la operación. Revisa la conexión y vuelve a intentar.';
  }
}

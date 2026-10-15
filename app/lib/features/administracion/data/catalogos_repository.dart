import 'package:supabase_flutter/supabase_flutter.dart';

class AreaCatalogo {
  final String id, codigo, nombre, descripcion;
  final bool activo, administraStock;
  const AreaCatalogo({required this.id, required this.codigo,
    required this.nombre, required this.descripcion, required this.activo,
    required this.administraStock});
  factory AreaCatalogo.fromMap(Map<String, dynamic> row) => AreaCatalogo(
    id: row['id'] as String, codigo: row['codigo_interno'] as String,
    nombre: row['nombre'] as String, descripcion: row['descripcion'] as String? ?? '',
    activo: row['activo'] as bool, administraStock: row['administra_stock'] as bool);
}

class FinanciamientoCatalogo {
  final String id, nombre, descripcion, tipo;
  final double porcentaje;
  final bool activo;
  final Set<String> medicamentos;
  const FinanciamientoCatalogo({required this.id, required this.nombre,
    required this.descripcion, required this.tipo, required this.porcentaje,
    required this.activo, required this.medicamentos});
  factory FinanciamientoCatalogo.fromMap(Map<String, dynamic> row) => FinanciamientoCatalogo(
    id: row['id'] as String, nombre: row['nombre'] as String,
    descripcion: row['descripcion'] as String? ?? '', tipo: row['tipo'] as String,
    porcentaje: (row['porcentaje_descuento'] as num).toDouble(), activo: row['activo'] as bool,
    medicamentos: (row['cobertura'] as List<dynamic>).map((e) =>
      (e as Map<String, dynamic>)['medicamento_id'] as String).toSet());
}

class MedicamentoCobertura {
  final String id, nombre, presentacion;
  final double? kairos;
  final bool activo;
  const MedicamentoCobertura({required this.id, required this.nombre,
    required this.presentacion, this.kairos, required this.activo});
  factory MedicamentoCobertura.fromMap(Map<String, dynamic> row) => MedicamentoCobertura(
    id: row['id'] as String, nombre: row['nombre_comercial'] as String,
    presentacion: row['presentacion'] as String? ?? '',
    kairos: (row['precio_kairos'] as num?)?.toDouble(), activo: row['activo'] as bool);
}

/// HU-012: lecturas reales y escrituras atómicas; no utiliza datos de demostración.
class CatalogosRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<AreaCatalogo>> areas() async {
    final rows = await _client.from('areas').select(
      'id,codigo_interno,nombre,descripcion,activo,administra_stock').order('nombre');
    return rows.map(AreaCatalogo.fromMap).toList();
  }

  Future<List<FinanciamientoCatalogo>> financiamientos() async {
    final rows = await _client.from('financiamientos').select(
      '*,cobertura:financiamiento_medicamentos(medicamento_id)').order('nombre');
    return rows.map(FinanciamientoCatalogo.fromMap).toList();
  }

  Future<List<MedicamentoCobertura>> medicamentos() async {
    final result = <MedicamentoCobertura>[];
    const pagina = 500;
    for (var inicio = 0; ; inicio += pagina) {
      final rows = await _client.from('medicamentos').select(
        'id,nombre_comercial,presentacion,precio_kairos,activo')
        .order('nombre_comercial').order('id').range(inicio, inicio + pagina - 1);
      result.addAll(rows.map(MedicamentoCobertura.fromMap));
      if (rows.length < pagina) return result;
    }
  }

  Future<void> guardar(String entidad, Map<String, dynamic> datos, {String? id}) async {
    await _client.rpc('administrar_catalogo_hu012', params: {
      'p_entidad': entidad, 'p_accion': 'GUARDAR', 'p_id': id, 'p_datos': datos,
    });
  }

  Future<void> cambiarEstado(String entidad, String id, bool activo) async {
    await _client.rpc('administrar_catalogo_hu012', params: {
      'p_entidad': entidad, 'p_accion': 'ESTADO', 'p_id': id,
      'p_datos': {'activo': activo},
    });
  }

  Future<void> eliminar(String entidad, String id) async {
    await _client.rpc('administrar_catalogo_hu012', params: {
      'p_entidad': entidad, 'p_accion': 'ELIMINAR', 'p_id': id,
    });
  }

  static String mensajeError(Object error) {
    if (error is AuthException) return error.message;
    if (error is PostgrestException) {
      if (error.code == '42P01' || error.code == '42703' || (error.code?.startsWith('PGRST') ?? false)) {
        return 'No se pudo cargar el catálogo. Si es la primera vez, aplica la migración HU-012 en Supabase y vuelve a intentar.';
      }
      if (error.code == '42501') return 'Tu sesión no tiene permisos para esta operación.';
      if (error.code == '23503') return 'Tiene registros asociados. Deshabilítalo para conservar el historial.';
      if (error.code == '23505') return 'Ya existe un registro con ese nombre o código.';
      return error.message;
    }
    return 'No se pudo completar la operación. Revisa la conexión y vuelve a intentar.';
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../administracion/data/catalogos_repository.dart';
import '../../domain/entities/kit_entity.dart';
import '../../domain/entities/kit_item_entity.dart';
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

  /// HU-017: Consulta kits reales.
  /// Intenta primero la RPC `listar_kits_hu017`. Si aún no fue creada en el servidor,
  /// usa fallback nativo con SELECT relacional de Supabase para alta resiliencia.
  Future<List<KitEntity>> listarKits({String? area, bool? soloActivos}) async {
    try {
      final data = await _client.rpc('listar_kits_hu017', params: {
        'p_area': area,
        'p_solo_activos': soloActivos,
      });
      final rows = (data as List<dynamic>).cast<Map<String, dynamic>>();
      return rows.map(KitEntity.fromMap).toList();
    } on PostgrestException catch (e) {
      // Fallback a consulta relacional si la RPC no ha sido corrida aún en Supabase
      if (e.code == 'PGRST202' || e.code == '42883') {
        return _listarKitsFallback(area: area, soloActivos: soloActivos);
      }
      throw Exception(mensajeError(e));
    } catch (e) {
      throw Exception(mensajeError(e));
    }
  }

  /// Consulta relacional alternativa sin RPC
  Future<List<KitEntity>> _listarKitsFallback({String? area, bool? soloActivos}) async {
    var query = _client.from('kits').select('''
      id, nombre, descripcion, area_destino, activo, created_at, updated_at,
      areas!kits_area_destino_fkey (nombre, codigo_interno),
      kit_items (
        id, medicamento_id, cantidad,
        medicamentos (nombre_comercial, principio_activo, presentacion, laboratorio)
      )
    ''');

    if (area != null && area.isNotEmpty) {
      query = query.eq('area_destino', area);
    }
    if (soloActivos != null) {
      query = query.eq('activo', soloActivos);
    }

    final rows = await query.order('activo', ascending: false).order('nombre');

    return (rows as List<dynamic>).map((row) {
      final map = row as Map<String, dynamic>;
      final areaMap = map['areas'] as Map<String, dynamic>?;
      final itemsRaw = map['kit_items'] as List<dynamic>? ?? [];

      final items = itemsRaw.map((ki) {
        final kiMap = ki as Map<String, dynamic>;
        final medMap = kiMap['medicamentos'] as Map<String, dynamic>? ?? {};
        return KitItemEntity(
          id: kiMap['id']?.toString() ?? '',
          medicamentoId: kiMap['medicamento_id']?.toString() ?? '',
          medicamentoNombre: medMap['nombre_comercial']?.toString() ?? 'Medicamento',
          principioActivo: medMap['principio_activo']?.toString(),
          presentacion: medMap['presentacion']?.toString(),
          laboratorio: medMap['laboratorio']?.toString(),
          cantidad: (kiMap['cantidad'] as num?)?.toInt() ?? 1,
        );
      }).toList();

      return KitEntity(
        id: map['id']?.toString() ?? '',
        nombre: map['nombre']?.toString() ?? '',
        descripcion: map['descripcion']?.toString(),
        areaDestino: map['area_destino']?.toString() ?? '',
        areaNombre: areaMap?['nombre']?.toString() ?? map['area_destino']?.toString() ?? '',
        areaCodigoInterno: areaMap?['codigo_interno']?.toString() ?? map['area_destino']?.toString() ?? '',
        activo: map['activo'] as bool? ?? true,
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
        totalItems: items.length,
        items: items,
      );
    }).toList();
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
      // Si la RPC aún no fue creada en remoto, ejecutar guardado fallback en tablas directas
      if (e.code == 'PGRST202' || e.code == '42883') {
        return _guardarKitFallback(borrador, id: id);
      }
      throw Exception(mensajeError(e));
    } catch (e) {
      throw Exception(mensajeError(e));
    }
  }

  /// Guardado directo de respaldo si la RPC aún no está desplegada
  Future<String> _guardarKitFallback(KitBorrador borrador, {String? id}) async {
    String kitId = id ?? '';
    if (id == null) {
      final insertKit = await _client.from('kits').insert({
        'nombre': borrador.nombre.trim(),
        'descripcion': borrador.descripcion.trim().isEmpty ? null : borrador.descripcion.trim(),
        'area_destino': borrador.areaDestino.trim(),
        'activo': true,
      }).select('id').single();
      kitId = insertKit['id'].toString();
    } else {
      await _client.from('kits').update({
        'nombre': borrador.nombre.trim(),
        'descripcion': borrador.descripcion.trim().isEmpty ? null : borrador.descripcion.trim(),
        'area_destino': borrador.areaDestino.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);

      await _client.from('kit_items').delete().eq('kit_id', id);
    }

    if (borrador.items.isNotEmpty) {
      final itemsInsert = borrador.items.map((item) => {
            'kit_id': kitId,
            'medicamento_id': item.medicamentoId,
            'cantidad': item.cantidad,
          }).toList();
      await _client.from('kit_items').insert(itemsInsert);
    }

    return kitId;
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
      if (e.code == 'PGRST202' || e.code == '42883') {
        await _client.from('kits').update({
          'activo': activo,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', id);
        return;
      }
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
      if (e.code == 'PGRST202' || e.code == '42883') {
        // Verificar si tiene dispensaciones antes de borrar
        final disp = await _client.from('dispensaciones').select('id').eq('kit_id', id).limit(1);
        if (disp.isNotEmpty) {
          throw Exception('El kit tiene fichas históricas asociadas. No se puede eliminar; desactívalo.');
        }
        await _client.from('kit_items').delete().eq('kit_id', id);
        await _client.from('kits').delete().eq('id', id);
        return;
      }
      throw Exception(mensajeError(e));
    } catch (e) {
      throw Exception(mensajeError(e));
    }
  }
}

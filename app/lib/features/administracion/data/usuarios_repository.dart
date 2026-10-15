import 'package:supabase_flutter/supabase_flutter.dart';

class AreaUsuario {
  final String id, codigo, nombre;
  final bool activo;
  const AreaUsuario({required this.id, required this.codigo,
    required this.nombre, required this.activo});
}

class UsuarioAdministrativo {
  final String id, usuario, nombres, apellidos, nombreAnterior, correo, cargo, correoDrive, rol;
  final List<String> areas;
  final bool activo;
  final DateTime? creado, actualizado;
  const UsuarioAdministrativo({required this.id, required this.usuario,
    required this.nombres, required this.apellidos, required this.nombreAnterior,
    required this.correo, required this.cargo, required this.correoDrive,
    required this.rol, required this.areas, required this.activo, this.creado, this.actualizado});
  String get nombreCompleto {
    final separado = '$nombres $apellidos'.trim();
    return separado.isNotEmpty ? separado : nombreAnterior.isNotEmpty ? nombreAnterior : correo;
  }
  String get iniciales {
    final palabras = nombreCompleto.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    return palabras.take(2).map((p) => p.substring(0,1)).join().toUpperCase();
  }
  static const roles = {
    'ADMINISTRADOR': 'Administrador', 'JEFATURA_FARMACIA': 'Jefatura de Farmacia',
    'FARMACIA': 'Farmacia', 'ALMACEN': 'Almacén', 'ENFERMERIA': 'Enfermería / Técnico',
  };
  String get rolVisible => roles[rol] ?? 'Rol sin definir';
  factory UsuarioAdministrativo.fromMap(Map<String, dynamic> m) => UsuarioAdministrativo(
    id: m['id'] as String, usuario: m['nombre_usuario'] as String? ?? '',
    nombres: m['nombres'] as String? ?? '', apellidos: m['apellidos'] as String? ?? '',
    nombreAnterior: m['nombre'] as String? ?? '', correo: m['email'] as String? ?? '',
    cargo: m['cargo'] as String? ?? '', correoDrive: m['correo_drive'] as String? ?? '',
    rol: m['rol'] as String? ?? '',
    areas: (m['areas_asignadas'] as List<dynamic>? ?? []).map((a) => a.toString()).toList(),
    activo: m['activo'] as bool? ?? false,
    creado: DateTime.tryParse(m['created_at']?.toString() ?? ''),
    actualizado: DateTime.tryParse(m['updated_at']?.toString() ?? ''));
}

class UsuariosConsulta {
  final List<UsuarioAdministrativo> usuarios;
  final List<AreaUsuario> areas;
  final bool estructuraPendiente;
  const UsuariosConsulta(this.usuarios, this.areas, this.estructuraPendiente);
}

class UsuariosRepository {
  SupabaseClient get _client => Supabase.instance.client;
  Future<UsuariosConsulta> cargar() async {
    // La vista también puede mostrar los perfiles antiguos antes de aplicar HU-020.
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AuthException('Inicia sesión.');
    final perfil = await _client.from('profiles').select('rol,activo').eq('id',uid).single();
    if (perfil['rol'] != 'ADMINISTRADOR' || perfil['activo'] != true) {
      throw const AuthException('Solo Administrador puede consultar esta pantalla.');
    }
    var pendiente = false;
    final usuarios = <UsuarioAdministrativo>[];
    try {
      for (var desde = 0; ; desde += 200) {
        final data = await _client.rpc('listar_usuarios_hu020', params: {'p_desde': desde, 'p_limite': 200});
        final rows = (data as List<dynamic>).cast<Map<String, dynamic>>();
        usuarios.addAll(rows.map(UsuarioAdministrativo.fromMap));
        if (rows.length < 200) break;
      }
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202' && e.code != '42883') rethrow;
      pendiente = true;
      usuarios.clear();
      for (var desde = 0; ; desde += 500) {
        final rows = await _client.from('profiles')
          .select('id,nombre,email,rol,areas_asignadas,activo,created_at,updated_at')
          .order('nombre').order('id').range(desde,desde+499);
        usuarios.addAll(rows.map(UsuarioAdministrativo.fromMap));
        if (rows.length < 500) break;
      }
    }
    final areas = <AreaUsuario>[];
    for (var desde = 0; ; desde += 500) {
      final rows = await _client.from('areas').select('id,codigo,nombre,activo')
        .order('nombre').order('id').range(desde,desde+499);
      areas.addAll(rows.map((a) => AreaUsuario(id: a['id'] as String,
        codigo: a['codigo'] as String, nombre: a['nombre'] as String, activo: a['activo'] as bool)));
      if (rows.length < 500) break;
    }
    return UsuariosConsulta(usuarios,areas,pendiente);
  }
}

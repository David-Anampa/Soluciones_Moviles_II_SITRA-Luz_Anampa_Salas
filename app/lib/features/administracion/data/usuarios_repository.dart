import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../../core/network/diagnostico_red.dart';
import '../domain/usuario_borrador.dart';
import '../domain/catalogos_profesionales.dart';
import 'catalogos_repository.dart';

class AreaUsuario {
  final String id, codigo, nombre;
  final bool activo;

  /// Construye el área de referencia usada para resolver nombres y filtrar usuarios.
  const AreaUsuario({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.activo,
  });
}

class UsuarioAdministrativo {
  final String id,
      usuario,
      nombres,
      apellidos,
      nombreAnterior,
      correo,
      cargo,
      rol;
  final List<String> areas;
  final bool activo;
  final DateTime? creado, actualizado;
  final bool puedeGestionarKits;
  final String colegioCodigo,
      numeroColegiatura,
      especialidadCodigo,
      colegioNombre,
      especialidadNombre;

  /// Conserva los datos públicos del perfil para la consulta administrativa.
  /// No recibe ni almacena contraseñas o tokens de autenticación.
  const UsuarioAdministrativo({
    required this.id,
    required this.usuario,
    required this.nombres,
    required this.apellidos,
    required this.nombreAnterior,
    required this.correo,
    required this.cargo,
    required this.rol,
    required this.areas,
    required this.activo,
    this.puedeGestionarKits = false,
    this.creado,
    this.actualizado,
    this.colegioCodigo = '',
    this.numeroColegiatura = '',
    this.especialidadCodigo = '',
    this.colegioNombre = '',
    this.especialidadNombre = '',
  });

  /// Prioriza nombres/apellidos separados y conserva el nombre completo anterior
  /// como alternativa para perfiles aún no actualizados; al final utiliza el correo.
  String get nombreCompleto {
    final separado = '$nombres $apellidos'.trim();
    return separado.isNotEmpty
        ? separado
        : nombreAnterior.isNotEmpty
        ? nombreAnterior
        : correo;
  }

  /// Extrae las iniciales de las primeras dos palabras para el avatar de la tarjeta.
  String get iniciales {
    final palabras = nombreCompleto
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    return palabras.take(2).map((p) => p.substring(0, 1)).join().toUpperCase();
  }

  static const roles = {
    'ADMINISTRADOR': 'Administrador',
    'JEFATURA_FARMACIA': 'Jefatura de Farmacia',
    'FARMACIA': 'Farmacia',
    'ALMACEN': 'Almacén',
    'ENFERMERIA': 'Enfermería / Técnico',
  };

  /// Traduce el código del rol a su etiqueta visible sin asignar un rol por defecto.
  String get rolVisible => roles[rol] ?? 'Rol sin definir';

  /// Convierte la fila devuelta por Supabase, admitiendo campos nuevos aún ausentes.
  /// Las fechas se interpretan sin inventar una fecha cuando el campo está vacío.
  factory UsuarioAdministrativo.fromMap(Map<String, dynamic> m) =>
      UsuarioAdministrativo(
        id: m['id'] as String,
        usuario: m['nombre_usuario'] as String? ?? '',
        nombres: m['nombres'] as String? ?? '',
        apellidos: m['apellidos'] as String? ?? '',
        nombreAnterior: m['nombre'] as String? ?? '',
        correo: m['email'] as String? ?? '',
        cargo: m['cargo'] as String? ?? '',
        rol: m['rol'] as String? ?? '',
        colegioCodigo: m['colegio_codigo'] as String? ?? '',
        numeroColegiatura: m['numero_colegiatura'] as String? ?? '',
        especialidadCodigo: m['especialidad_codigo'] as String? ?? '',
        colegioNombre: m['colegio_nombre'] as String? ?? '',
        especialidadNombre: m['especialidad_nombre'] as String? ?? '',
        areas: (m['areas_asignadas'] as List<dynamic>? ?? [])
            .map((a) => a.toString())
            .toList(),
        activo: m['activo'] as bool? ?? false,
        puedeGestionarKits: m['puede_gestionar_kits'] == true,
        creado: DateTime.tryParse(m['created_at']?.toString() ?? ''),
        actualizado: DateTime.tryParse(m['updated_at']?.toString() ?? ''),
      );
}

class UsuariosConsulta {
  final List<UsuarioAdministrativo> usuarios;
  final List<AreaUsuario> areas;
  final bool estructuraPendiente;

  /// Devuelve juntos los perfiles, las áreas de referencia y el aviso de esquema pendiente.
  const UsuariosConsulta(this.usuarios, this.areas, this.estructuraPendiente);
}

class UsuariosRepository {
  final SupabaseClient? _customClient;
  UsuariosRepository({SupabaseClient? client}) : _customClient = client;

  /// Lee catálogos reales, incluidos deshabilitados para conservar valores históricos.
  /// Una migración ausente se comunica; no se sustituyen datos por listas ficticias.
  Future<CatalogosProfesionales> cargarCatalogosProfesionales() =>
      DiagnosticoRed.medir(
        'Usuarios.catalogosProfesionales',
        _cargarCatalogosProfesionales,
      );

  Future<CatalogosProfesionales> _cargarCatalogosProfesionales() async {
    final colegios = await _client
        .from('colegios_profesionales')
        .select('codigo,nombre,activo')
        .order('nombre');
    final especialidades = <EspecialidadProfesional>[];
    for (var desde = 0; ; desde += 200) {
      final filas = await _client
          .from('especialidades_profesionales')
          .select('codigo,colegio_codigo,nombre,tipo,activo')
          .order('nombre')
          .order('codigo')
          .range(desde, desde + 199);
      especialidades.addAll(
        filas.map(
          (r) => EspecialidadProfesional(
            r['codigo'] as String,
            r['colegio_codigo'] as String,
            r['nombre'] as String,
            r['tipo'] as String,
            r['activo'] as bool,
          ),
        ),
      );
      if (filas.length < 200) break;
    }
    return CatalogosProfesionales(
      colegios
          .map(
            (r) => ColegioProfesional(
              r['codigo'] as String,
              r['nombre'] as String,
              r['activo'] as bool,
            ),
          )
          .toList(),
      especialidades,
    );
  }

  /// Accede al cliente de Supabase que comparte la sesión autenticada de la aplicación.
  SupabaseClient get _client => _customClient ?? Supabase.instance.client;

  /// Consulta perfiles reales para Gestión de usuarios, previa comprobación de
  /// Administrador activo. Pagina la RPC y luego carga las áreas para los filtros.
  /// Solo si falta la RPC utiliza el esquema anterior y señala estructuraPendiente;
  /// los errores de permiso o red siguen propagándose a la vista.
  Future<UsuariosConsulta> cargar() => DiagnosticoRed.medir(
    'Usuarios.listado',
    () => _cargar().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException(
        'La consulta de usuarios tardó demasiado. Revisa la conexión y pulsa Reintentar.',
      ),
    ),
  );

  /// Verifica el rol antes de iniciar en paralelo las tres lecturas independientes.
  Future<UsuariosConsulta> _cargar() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AuthException('Inicia sesión.');
    final perfil = await _client
        .from('profiles')
        .select('rol,activo')
        .eq('id', uid)
        .single();
    if (perfil['rol'] != 'ADMINISTRADOR' || perfil['activo'] != true) {
      throw const AuthException(
        'Solo Administrador puede consultar esta pantalla.',
      );
    }
    final resultados = await Future.wait<Object>([
      DiagnosticoRed.medir('Usuarios.listarPermisos', _consultarPermisos),
      DiagnosticoRed.medir('Usuarios.listarPerfiles', _consultarPerfiles),
      DiagnosticoRed.medir('Usuarios.listarAreas', _consultarAreas),
    ], eagerError: true);
    if (_client.auth.currentUser?.id != uid) {
      throw const AuthException('La sesión cambió. Vuelve a ingresar.');
    }
    final permisos = resultados[0] as Map<String, bool>;
    final perfiles =
        resultados[1] as ({List<Map<String, dynamic>> filas, bool pendiente});
    final areas = resultados[2] as List<AreaUsuario>;
    return UsuariosConsulta(
      perfiles.filas
          .map(
            (fila) => UsuarioAdministrativo.fromMap({
              ...fila,
              'puede_gestionar_kits': permisos[fila['id']] == true,
            }),
          )
          .toList(),
      areas,
      perfiles.pendiente,
    );
  }

  /// Pagina los permisos sin depender de la lectura de perfiles ni del catálogo.
  Future<Map<String, bool>> _consultarPermisos() async {
    final permisos = <String, bool>{};
    for (var desde = 0; ; desde += 200) {
      final filas =
          (await _client.rpc(
                    'listar_permisos_kits',
                    params: {'p_desde': desde, 'p_limite': 200},
                  )
                  as List)
              .cast<Map<String, dynamic>>();
      for (final fila in filas) {
        permisos[fila['id'] as String] = fila['puede_gestionar_kits'] == true;
      }
      if (filas.length < 200) break;
    }
    return permisos;
  }

  /// Conserva la compatibilidad de solo lectura únicamente si falta la RPC.
  Future<({List<Map<String, dynamic>> filas, bool pendiente})>
  _consultarPerfiles() async {
    final perfiles = <Map<String, dynamic>>[];
    try {
      for (var desde = 0; ; desde += 200) {
        final filas =
            (await _client.rpc(
                      'listar_usuarios_hu020',
                      params: {'p_desde': desde, 'p_limite': 200},
                    )
                    as List)
                .cast<Map<String, dynamic>>();
        perfiles.addAll(filas);
        if (filas.length < 200) break;
      }
      return (filas: perfiles, pendiente: false);
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202' && error.code != '42883') rethrow;
      perfiles.clear();
      for (var desde = 0; ; desde += 500) {
        final filas = await _client
            .from('profiles')
            .select(
              'id,nombre,email,rol,areas_asignadas,activo,created_at,updated_at',
            )
            .order('nombre')
            .order('id')
            .range(desde, desde + 499);
        perfiles.addAll(filas);
        if (filas.length < 500) break;
      }
      return (filas: perfiles, pendiente: true);
    }
  }

  /// Pagina áreas para resolver nombres y filtros; mantiene referencias históricas.
  Future<List<AreaUsuario>> _consultarAreas() async {
    final areas = <AreaUsuario>[];
    for (var desde = 0; ; desde += 500) {
      final filas = await _client
          .from('areas')
          .select('id,codigo,nombre,activo')
          .order('nombre')
          .order('id')
          .range(desde, desde + 499);
      areas.addAll(
        filas.map(
          (a) => AreaUsuario(
            id: a['id'] as String,
            codigo: a['codigo'] as String,
            nombre: a['nombre'] as String,
            activo: a['activo'] as bool,
          ),
        ),
      );
      if (filas.length < 500) break;
    }
    return areas;
  }

  /// UUID del usuario con sesión iniciada; permite impedir autoacciones peligrosas
  /// (deshabilitarse o cambiarse el rol). Es null si no hay sesión.
  String? get idSesion => _client.auth.currentUser?.id;

  /// Crea la cuenta de acceso y su perfil mediante la Edge Function `crear-usuario`.
  /// La función valida que quien llama sea Administrador y usa la clave service-role
  /// en el servidor. La contraseña solo viaja en esta solicitud; no se guarda.
  Future<void> crear(
    UsuarioBorrador datos, {
    required String correo,
    required String contrasena,
  }) async {
    await _verificarContratoProfesional();
    final respuesta = await _client.functions.invoke(
      'crear-usuario',
      body: {
        'email': correo.trim().toLowerCase(),
        'password': contrasena,
        'perfil': datos.toJson(),
      },
    );
    if (respuesta.status != 200) {
      throw StateError('No se pudo crear el usuario.');
    }
  }

  /// Restablece Auth desde el servidor; devuelve una advertencia si Auth cambió
  /// pero no se pudo registrar el resultado final. Nunca retorna la contraseña.
  Future<String?> restablecerClave(String id, String contrasena) async {
    try {
      final respuesta = await _client.functions.invoke(
        'restablecer-clave',
        body: {'id': id, 'password': contrasena},
      );
      if (respuesta.status != 200 ||
          respuesta.data is! Map ||
          respuesta.data['actualizado'] != true) {
        throw StateError('No se pudo confirmar el cambio de contraseña.');
      }
      return respuesta.data['advertencia'] as String?;
    } on FunctionException catch (error) {
      if (error.status == 404) {
        final detalle = error.details;
        if (detalle is Map && detalle['error'] is String) {
          throw StateError(detalle['error'] as String);
        }
        throw StateError(
          'Falta desplegar la función restablecer-clave en Supabase.',
        );
      }
      final detalle = error.details;
      throw StateError(
        detalle is Map && detalle['error'] is String
            ? detalle['error'] as String
            : 'No se pudo confirmar el cambio. Verifica la conexión antes de reintentar.',
      );
    }
  }

  /// Actualiza los datos del perfil mediante la RPC atómica y auditada.
  /// El correo de acceso no se modifica aquí: pertenece a Supabase Auth.
  Future<void> editar(String id, UsuarioBorrador datos) =>
      _administrar('EDITAR', id, datos.toJson());

  /// Habilita o deshabilita al usuario. `activo` es el estado deseado, no una inversión.
  /// Nunca elimina: deshabilitar conserva su historial y bloquea el acceso.
  Future<void> cambiarEstado(String id, {required bool activo}) =>
      _administrar('ESTADO', id, {'activo': activo});

  /// Punto único de llamada a `administrar_usuario_hu020` para no repetir sus parámetros.
  Future<void> _administrar(
    String accion,
    String id,
    Map<String, dynamic> datos,
  ) => DiagnosticoRed.medir('Usuarios.$accion', () async {
    if (accion == 'EDITAR') await _verificarContratoProfesional();
    await DiagnosticoRed.medir(
      'Usuarios.actualizarPerfilRPC',
      () => _client.rpc(
        'administrar_usuario_con_kits',
        params: {'p_accion': accion, 'p_id': id, 'p_datos': datos},
      ),
    );
  });

  /// Evita que las RPC antiguas ignoren silenciosamente la colegiatura enviada.
  /// El Administrador autenticado debe aparecer al menos en una fila del listado.
  Future<void> _verificarContratoProfesional() async {
    // Evita que una función antigua ignore silenciosamente el permiso enviado.
    await DiagnosticoRed.medir(
      'Usuarios.verificarPermisosKits',
      () => _client.rpc(
        'listar_permisos_kits',
        params: {'p_desde': 0, 'p_limite': 1},
      ),
    );
    final filas = await DiagnosticoRed.medir(
      'Usuarios.verificarContratoPerfil',
      () => _client.rpc(
        'listar_usuarios_hu020',
        params: {'p_desde': 0, 'p_limite': 1},
      ),
    );
    if (filas is! List ||
        filas.isEmpty ||
        filas.first is! Map ||
        !(filas.first as Map).containsKey('colegio_codigo') ||
        !(filas.first as Map).containsKey('numero_colegiatura') ||
        !(filas.first as Map).containsKey('especialidad_codigo')) {
      throw const PostgrestException(
        code: 'SITRA_CONTRATO_PROFESIONAL',
        message:
            'Falta aplicar la migración de colegiatura HU-020/HU-021/HU-022 en Supabase.',
      );
    }
  }

  /// Traduce errores de escritura a un mensaje para el usuario. Reconoce los
  /// rechazos de la Edge Function (HTTP 4xx con `error`) y la migración pendiente;
  /// el resto lo resuelve el traductor general del módulo de administración.
  static String mensajeError(Object error) {
    if (error is TimeoutException) {
      return 'La consulta tardó demasiado. Revisa la conexión y vuelve a intentar.';
    }
    if (error is PostgrestException &&
        error.code == 'SITRA_CONTRATO_PROFESIONAL') {
      return error.message;
    }
    if (error is PostgrestException &&
        (error.code == '42P01' || error.code == 'PGRST205')) {
      return 'Falta aplicar la migración de colegios y especialidades profesionales en Supabase.';
    }
    if (error is FunctionException) {
      final detalle = error.details;
      if (error.status == 404) {
        return 'Falta desplegar la función crear-usuario en Supabase. Revisa la guía HU-021/HU-022.';
      }
      if (detalle is Map && detalle['error'] is String) {
        return detalle['error'] as String;
      }
      return 'No se pudo crear el usuario. Revisa los datos y la conexión.';
    }
    if (error is PostgrestException &&
        (error.code == 'PGRST202' || error.code == '42883')) {
      if (error.message.contains('listar_permisos_kits') ||
          error.message.contains('administrar_usuario_con_kits')) {
        return 'Aplica migracion_kits_por_area_2026_10_26.sql en Supabase para gestionar los permisos de kits.';
      }
      return 'Falta aplicar la migración HU-021/HU-022 en Supabase.';
    }
    return CatalogosRepository.mensajeError(error);
  }
}

import 'package:flutter/material.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../widgets/restablecer_clave_dialog.dart';
import '../widgets/areas_usuario_selector.dart';
import '../../data/usuarios_repository.dart';
import '../../domain/usuario_borrador.dart';
import '../../domain/usuario_validadores.dart';
import '../../domain/catalogos_profesionales.dart';
import '../../domain/permiso_kits.dart';
import '../../domain/areas_por_rol.dart';
import '../widgets/catalogo_estilo.dart';

/// HU-021 (crear) y HU-022 (editar): formulario de usuario.
///
/// Si [usuario] es null crea una cuenta nueva; si no, edita ese perfil. Al guardar
/// con éxito cierra devolviendo `true` para que el listado se actualice. La vista
/// solo captura y valida datos: el acceso a Supabase está en [UsuariosRepository].
class UsuarioFormularioView extends StatefulWidget {
  final UsuarioAdministrativo? usuario;
  final List<AreaUsuario> areas;
  final UsuariosRepository repositorio;

  /// Recibe el repositorio por parámetro (inyección de dependencias) para que la
  /// vista no cree su propio acceso a datos y pueda sustituirse en pruebas.
  const UsuarioFormularioView({
    super.key,
    required this.areas,
    required this.repositorio,
    this.usuario,
  });

  /// Crea el estado con los controladores y la selección de áreas.
  @override
  State<UsuarioFormularioView> createState() => _UsuarioFormularioViewState();
}

class _UsuarioFormularioViewState extends State<UsuarioFormularioView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombres,
      _apellidos,
      _usuario,
      _correo,
      _clave,
      _cargo,
      _colegiatura;
  CatalogosProfesionales? _catalogos;
  bool _cargandoCatalogos = true;
  String? _errorCatalogos;
  late String _colegioCodigo, _especialidadCodigo;
  late String? _rol;
  late final Set<String> _areasSeleccionadas;
  bool _verClave = false, _guardando = false;
  bool _puedeGestionarKits = false;
  bool get _cargoConKits => cargoPermiteKits(_cargo.text);
  String? _error;
  bool _areasAjustadas = false;

  /// Indica si el formulario edita un perfil existente.
  bool get _edita => widget.usuario != null;

  /// Indica si se edita la propia cuenta, caso en que el rol queda bloqueado
  /// para no perder el acceso administrativo por accidente.
  bool get _esCuentaPropia =>
      _edita && widget.usuario!.id == widget.repositorio.idSesion;

  /// Precarga los datos del usuario (o valores vacíos al crear).
  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nombres = TextEditingController(text: u?.nombres ?? '');
    _apellidos = TextEditingController(text: u?.apellidos ?? '');
    _usuario = TextEditingController(text: u?.usuario ?? '');
    _correo = TextEditingController(text: u?.correo ?? '');
    _clave = TextEditingController();
    _cargo = TextEditingController(text: u?.cargo ?? '');
    _puedeGestionarKits = u?.puedeGestionarKits ?? false;
    _cargo.addListener(_actualizarPermisoCargo);
    _colegiatura = TextEditingController(text: u?.numeroColegiatura ?? '');
    _colegioCodigo = u?.colegioCodigo ?? '';
    _especialidadCodigo = u?.especialidadCodigo ?? '';
    _rol = u?.rol.isEmpty ?? true ? null : u!.rol;
    _areasSeleccionadas = {
      for (final token in u?.areas ?? <String>[]) _codigoDeArea(token),
    };
    _aplicarAreasDelRol();
    _cargarCatalogos();
  }

  /// Carga referencias del servidor antes de permitir guardar la colegiatura.
  Future<void> _cargarCatalogos() async {
    setState(() {
      _cargandoCatalogos = true;
      _errorCatalogos = null;
    });
    try {
      final datos = await widget.repositorio.cargarCatalogosProfesionales();
      if (mounted) {
        setState(() {
          _catalogos = datos;
          _cargandoCatalogos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargandoCatalogos = false;
          _errorCatalogos = UsuariosRepository.mensajeError(e);
        });
      }
    }
  }

  /// Retira el permiso al cambiar a un cargo no elegible y actualiza el checkbox.
  void _actualizarPermisoCargo() {
    setState(() {
      if (!_cargoConKits) _puedeGestionarKits = false;
    });
  }

  /// Libera todos los controladores de texto.
  @override
  void dispose() {
    _cargo.removeListener(_actualizarPermisoCargo);
    for (final c in [
      _nombres,
      _apellidos,
      _usuario,
      _correo,
      _clave,
      _cargo,
      _colegiatura,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Convierte un código o nombre histórico de área en `areas.codigo`.
  /// Si no coincide con ninguna área conocida conserva el texto original.
  String _codigoDeArea(String token) {
    final valor = token.trim().toLowerCase();
    for (final a in widget.areas) {
      if (a.codigo.toLowerCase() == valor || a.nombre.toLowerCase() == valor) {
        return a.codigo;
      }
    }
    return token;
  }

  /// Áreas ofrecidas: solo habilitadas, más las ya asignadas aunque estén
  /// deshabilitadas para no quitarlas en silencio. Devuelve código → nombre.
  Map<String, String> get _opcionesAreas {
    final opciones = <String, String>{
      for (final a in widget.areas)
        if (!areaReservadaPorRol(a.codigo, a.nombre) &&
            (a.activo || _areasSeleccionadas.contains(a.codigo)))
          a.codigo: a.nombre,
    };
    for (final codigo in _areasSeleccionadas) {
      if (!areaReservadaPorRol(codigo, codigo)) {
        opciones.putIfAbsent(codigo, () => codigo);
      }
    }
    return opciones;
  }

  /// Ajusta solo el borrador al cambiar de rol; avisa antes de guardar perfiles antiguos.
  void _aplicarAreasDelRol() {
    final anteriores = {..._areasSeleccionadas};
    if (_rol == 'ENFERMERIA') {
      _areasSeleccionadas.retainWhere((codigo) {
        final area = widget.areas.where((a) => a.codigo == codigo).firstOrNull;
        return !areaReservadaPorRol(codigo, area?.nombre ?? codigo);
      });
    } else if (_rol != null) {
      _areasSeleccionadas.clear();
      final fija = areaFijaPorRol(_rol);
      if (fija != null) _areasSeleccionadas.add(fija);
    }
    _areasAjustadas =
        _edita &&
        (anteriores.length != _areasSeleccionadas.length ||
            !anteriores.containsAll(_areasSeleccionadas));
  }

  /// Construye el borrador a partir de los campos del formulario.
  UsuarioBorrador _borrador() => UsuarioBorrador(
    nombres: _nombres.text,
    apellidos: _apellidos.text,
    nombreUsuario: _usuario.text,
    cargo: _cargo.text,
    rol: _rol!,
    areas: _areasSeleccionadas.toList()..sort(),
    puedeGestionarKits:
        _cargoConKits && _rol == 'ENFERMERIA' && _puedeGestionarKits,
    colegioCodigo: _colegioCodigo,
    numeroColegiatura: _colegiatura.text,
    especialidadCodigo: _especialidadCodigo,
  );

  /// Valida el formulario y lo envía; muestra el error del servidor si lo hay.
  /// Ignora pulsaciones repetidas mientras hay un guardado en curso.
  Future<void> _guardar() async {
    if (_guardando ||
        _cargandoCatalogos ||
        _catalogos == null ||
        !_formKey.currentState!.validate()) {
      return;
    }
    if (_cargoConKits &&
        _rol == 'ENFERMERIA' &&
        _puedeGestionarKits &&
        _areasSeleccionadas.isEmpty) {
      setState(
        () => _error =
            'Asigna al menos un área para habilitar la gestión de kits.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final datos = _borrador();
      if (_edita) {
        await widget.repositorio.editar(widget.usuario!.id, datos);
      } else {
        await widget.repositorio.crear(
          datos,
          correo: _correo.text,
          contrasena: _clave.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = UsuariosRepository.mensajeError(e);
          _guardando = false;
        });
      }
    }
  }

  /// Construye la pantalla: cabecera roja, campos agrupados y botones de acción.
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CatalogoEstilo.tema(context),
      child: Scaffold(
        backgroundColor: CatalogoEstilo.fondo,
        appBar: AppBar(
          toolbarHeight: DisenoAdaptable.altoCabecera(
            context,
            base: kToolbarHeight,
          ),
          title: Text(
            _edita ? 'Editar usuario' : 'Nuevo usuario',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            tooltip: 'Cancelar',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _guardando ? null : () => Navigator.pop(context, false),
          ),
        ),
        body: SafeArea(
          child: ContenidoAdaptable(
            anchoMaximo: 650,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.zero,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _seccion('Datos personales', [
                    _campo(
                      _nombres,
                      'Nombres',
                      Icons.badge_outlined,
                      validador: (v) =>
                          UsuarioValidadores.nombre(v, etiqueta: 'los nombres'),
                      capitalizacion: TextCapitalization.words,
                    ),
                    _campo(
                      _apellidos,
                      'Apellidos',
                      Icons.badge_outlined,
                      validador: (v) => UsuarioValidadores.nombre(
                        v,
                        etiqueta: 'los apellidos',
                      ),
                      capitalizacion: TextCapitalization.words,
                    ),
                    _campo(
                      _cargo,
                      'Cargo / ocupación (opcional)',
                      Icons.work_outline_rounded,
                      validador: UsuarioValidadores.cargo,
                      capitalizacion: TextCapitalization.sentences,
                    ),
                  ], icono: Icons.person_outline_rounded),
                  _seccion(
                    'Colegiatura y especialidad',
                    _camposProfesionales(),
                    icono: Icons.verified_outlined,
                  ),
                  _seccion('Acceso', [
                    _campo(
                      _usuario,
                      'Nombre de usuario',
                      Icons.alternate_email_rounded,
                      validador: UsuarioValidadores.nombreUsuario,
                      ayuda:
                          'Mayúsculas y minúsculas, números; al menos una letra. También punto, guion y guion bajo.',
                    ),
                    _campo(
                      _correo,
                      'Correo electrónico',
                      Icons.mail_outline_rounded,
                      validador: UsuarioValidadores.correoAcceso,
                      teclado: TextInputType.emailAddress,
                      soloLectura: _edita,
                      ayuda: _edita
                          ? 'Se usa para el acceso y la vinculación con Drive. No se modifica desde aquí.'
                          : 'Se usa para el acceso y la vinculación con Drive, previa autorización de Google.',
                    ),
                    if (!_edita) _campoContrasena(),
                    if (_edita) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'La contraseña actual no se muestra. Puedes asignar una nueva sin modificar el perfil.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _guardando ? null : _restablecerClave,
                        icon: const Icon(Icons.lock_reset_rounded),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Restablecer contraseña'),
                        ),
                      ),
                    ],
                  ]),
                  _seccion('Rol y áreas', [
                    _selectorRol(),
                    _selectorAreas(),
                    if (_rol == 'ENFERMERIA')
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: CatalogoEstilo.rojo,
                          title: const Text(
                            'Puede gestionar kits',
                            style: TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            _cargoConKits
                                ? 'Solo en sus áreas asignadas. Requiere al menos un área.'
                                : 'Completa Cargo / ocupación como Técnica, Técnico, Enfermera o Enfermero para habilitar este permiso.',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: _cargoConKits && _puedeGestionarKits,
                          onChanged: _guardando || !_cargoConKits
                              ? null
                              : (valor) => setState(
                                  () => _puedeGestionarKits = valor == true,
                                ),
                        ),
                      ),
                  ], icono: Icons.admin_panel_settings_outlined),
                  if (_error != null) ...[
                    CatalogoEstilo.nota(
                      _error!,
                      icono: Icons.error_outline_rounded,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _acciones(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Muestra solo los campos aplicables, sin añadir otro campo de profesión.
  List<Widget> _camposProfesionales() {
    if (_cargandoCatalogos) return [const LinearProgressIndicator()];
    if (_errorCatalogos != null) {
      return [
        CatalogoEstilo.nota(
          _errorCatalogos!,
          icono: Icons.error_outline_rounded,
        ),
        TextButton(
          onPressed: _cargarCatalogos,
          child: const Text('Reintentar'),
        ),
      ];
    }
    final colegios = <String, String>{'': 'No aplica / sin registrar'};
    for (final c in _catalogos!.colegios) {
      if (c.activo || c.codigo == _colegioCodigo) {
        colegios[c.codigo] =
            '${c.codigo} — ${c.nombre}${c.activo ? '' : ' (deshabilitado)'}';
      }
    }
    if (_colegioCodigo.isNotEmpty) {
      colegios.putIfAbsent(_colegioCodigo, () => _colegioCodigo);
    }
    final especialidades = <String, String>{'': 'Sin especialidad registrada'};
    for (final e in _catalogos!.especialidades) {
      if (e.colegioCodigo == _colegioCodigo &&
          (e.activo || e.codigo == _especialidadCodigo)) {
        especialidades[e.codigo] =
            '${e.nombre}${e.activo ? '' : ' (deshabilitada)'}';
      }
    }
    if (_especialidadCodigo.isNotEmpty) {
      especialidades.putIfAbsent(
        _especialidadCodigo,
        () => _especialidadCodigo,
      );
    }
    return [
      const Text(
        'Completa estos datos cuando correspondan a su ocupación.',
        style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF64646D)),
      ),
      _selectorProfesional('Colegio profesional', _colegioCodigo, colegios, (
        valor,
      ) {
        if (valor == _colegioCodigo) return;
        setState(() {
          _colegioCodigo = valor;
          _especialidadCodigo = '';
          _colegiatura.clear();
        });
      }, icono: Icons.account_balance_outlined),
      if (_colegioCodigo.isNotEmpty) ...[
        _campo(
          _colegiatura,
          'Número de colegiatura ($_colegioCodigo)',
          Icons.badge_outlined,
          validador: (v) =>
              UsuarioValidadores.colegiatura(v, tieneColegio: true),
          teclado: TextInputType.number,
        ),
        _selectorProfesional(
          _colegioCodigo == 'CTMP'
              ? 'Área profesional (opcional)'
              : 'Especialidad (opcional)',
          _especialidadCodigo,
          especialidades,
          (valor) => setState(() => _especialidadCodigo = valor),
          icono: Icons.medical_services_outlined,
        ),
      ],
    ];
  }

  /// Menús expandidos con altura limitada y etiquetas legibles en teléfono.
  Widget _selectorProfesional(
    String etiqueta,
    String valor,
    Map<String, String> opciones,
    ValueChanged<String> cambiar, {
    required IconData icono,
  }) => DropdownButtonFormField<String>(
    isDense: false,
    key: ValueKey('$etiqueta:$valor'),
    value: valor,
    isExpanded: true,
    menuMaxHeight: 360,
    itemHeight: 72,
    decoration: InputDecoration(
      labelText: etiqueta,
      filled: true,
      prefixIcon: Icon(icono, color: CatalogoEstilo.rojo),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    selectedItemBuilder: (context) => opciones.values
        .map(
          (nombre) => Align(
            alignment: Alignment.centerLeft,
            child: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    items: opciones.entries
        .map(
          (e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value, maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: _guardando
        ? null
        : (v) {
            if (v != null) cambiar(v);
          },
  );

  /// Agrupa campos relacionados bajo un título dentro de una tarjeta blanca.
  Widget _seccion(
    String titulo,
    List<Widget> hijos, {
    IconData icono = Icons.lock_outline_rounded,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: CatalogoEstilo.pastel,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: CatalogoEstilo.rojo, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CatalogoEstilo.texto,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          for (var i = 0; i < hijos.length; i++) ...[
            hijos[i],
            if (i < hijos.length - 1) const SizedBox(height: 20),
          ],
        ],
      ),
    ),
  );

  /// Campo de texto con icono, validación y estilo comunes; evita repetir la
  /// decoración en cada campo del formulario.
  Widget _campo(
    TextEditingController controlador,
    String etiqueta,
    IconData icono, {
    required String? Function(String?) validador,
    TextInputType? teclado,
    TextCapitalization capitalizacion = TextCapitalization.none,
    bool soloLectura = false,
    String? ayuda,
  }) => TextFormField(
    controller: controlador,
    validator: validador,
    keyboardType: teclado,
    textCapitalization: capitalizacion,
    readOnly: soloLectura,
    enabled: !_guardando,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: etiqueta,
      helperText: ayuda,
      helperMaxLines: 2,
      prefixIcon: Icon(icono, color: CatalogoEstilo.rojo),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );

  /// Contraseña inicial oculta con opción de mostrarla mientras se escribe.
  /// Solo existe al crear: HU-022 nunca precarga ni muestra contraseñas.
  Widget _campoContrasena() => TextFormField(
    controller: _clave,
    validator: UsuarioValidadores.contrasena,
    obscureText: !_verClave,
    enabled: !_guardando,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: 'Contraseña inicial',
      helperText: 'Mínimo 8 caracteres. Puede contener solo números o solo letras.',
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      suffixIcon: IconButton(
        tooltip: _verClave ? 'Ocultar contraseña' : 'Mostrar contraseña',
        icon: Icon(
          _verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
        onPressed: () => setState(() => _verClave = !_verClave),
      ),
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );

  /// Lista desplegable de roles. Se bloquea al editar la cuenta propia.
  Widget _selectorRol() => DropdownButtonFormField<String>(
    itemHeight: null,
    isDense: false,
    value: _rol,
    isExpanded: true,
    validator: UsuarioValidadores.rol,
    decoration: InputDecoration(
      labelText: 'Rol de permisos',
      helperText: _ayudaRol,
      helperMaxLines: 2,
      prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    items: [
      for (final e in UsuarioAdministrativo.roles.entries)
        DropdownMenuItem(
          value: e.key,
          child: Text(e.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (_guardando || _esCuentaPropia)
        ? null
        : (v) => setState(() {
            _rol = v;
            if (v != 'ENFERMERIA') _puedeGestionarKits = false;
            _aplicarAreasDelRol();
          }),
  );

  /// Mensaje de ayuda del selector de rol, según el contexto.
  String? get _ayudaRol =>
      _esCuentaPropia ? 'No puedes cambiar el rol de tu propia cuenta.' : null;

  /// Selección múltiple buscable del catálogo HU-012 con etiquetas de resumen.
  Widget _selectorAreas() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_areasAjustadas) ...[
        MensajesApp.nota(
          'Las áreas se ajustarán al rol seleccionado cuando guardes los cambios.',
          tipo: TipoMensaje.advertencia,
        ),
        const SizedBox(height: 12),
      ],
      if (_rol == 'ENFERMERIA')
        AreasUsuarioSelector(
          opciones: _opcionesAreas,
          seleccionadas: _areasSeleccionadas,
          inactivas: {
            for (final area in widget.areas)
              if (!area.activo) area.codigo,
          },
          habilitado: !_guardando,
          onChanged: (seleccion) => setState(() {
            _areasSeleccionadas
              ..clear()
              ..addAll(seleccion);
          }),
        )
      else
        MensajesApp.nota(
          _rol == 'ADMINISTRADOR'
              ? 'Administrador: acceso global según sus permisos. No requiere asignación de áreas.'
              : _rol == null
              ? 'Selecciona un rol para definir las áreas de trabajo.'
              : 'Área asignada por el rol: ${areaFijaPorRol(_rol) == 'ALMACEN' ? 'Almacén' : 'Farmacia'}.',
        ),
    ],
  );

  /// Abre una acción independiente y bloquea el formulario mientras está abierta.
  Future<void> _restablecerClave() async {
    if (_guardando || !_edita) return;
    setState(() => _guardando = true);
    final resultado = await showDialog<({String mensaje, bool advertencia})>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: CatalogoEstilo.tema(ctx),
        child: RestablecerClaveDialog(
          usuario: widget.usuario!,
          repositorio: widget.repositorio,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _guardando = false);
    if (resultado != null) {
      MensajesApp.mostrar(
        context,
        resultado.mensaje,
        tipo: resultado.advertencia
            ? TipoMensaje.advertencia
            : TipoMensaje.exito,
      );
    }
  }

  /// Botones Cancelar y Guardar; Guardar muestra progreso y se bloquea al enviar.
  Widget _acciones() => AccionesAdaptables(
    acciones: [
      TextButton(
        onPressed: _guardando ? null : () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      FilledButton.icon(
        onPressed: (_guardando || _cargandoCatalogos || _catalogos == null)
            ? null
            : _guardar,
        icon: _guardando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_rounded),
        label: Text(_edita ? 'Guardar cambios' : 'Crear usuario'),
      ),
    ],
  );
}

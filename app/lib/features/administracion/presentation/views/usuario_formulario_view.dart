import 'package:flutter/material.dart';
import '../../data/usuarios_repository.dart';
import '../../domain/usuario_borrador.dart';
import '../../domain/usuario_validadores.dart';
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
  late final TextEditingController _nombres, _apellidos, _usuario, _correo, _clave, _cargo, _drive;
  late String? _rol;
  late final Set<String> _areasSeleccionadas;
  bool _verClave = false, _guardando = false;
  String? _error;

  /// Indica si el formulario edita un perfil existente.
  bool get _edita => widget.usuario != null;

  /// Indica si se edita la propia cuenta, caso en que el rol queda bloqueado
  /// para no perder el acceso administrativo por accidente.
  bool get _esCuentaPropia => _edita && widget.usuario!.id == widget.repositorio.idSesion;

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
    _drive = TextEditingController(text: u?.correoDrive ?? '');
    _rol = u?.rol.isEmpty ?? true ? null : u!.rol;
    _areasSeleccionadas = {for (final token in u?.areas ?? <String>[]) _codigoDeArea(token)};
  }

  /// Libera todos los controladores de texto.
  @override
  void dispose() {
    for (final c in [_nombres, _apellidos, _usuario, _correo, _clave, _cargo, _drive]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Convierte un código o nombre histórico de área en `areas.codigo`.
  /// Si no coincide con ninguna área conocida conserva el texto original.
  String _codigoDeArea(String token) {
    final valor = token.trim().toLowerCase();
    for (final a in widget.areas) {
      if (a.codigo.toLowerCase() == valor || a.nombre.toLowerCase() == valor) return a.codigo;
    }
    return token;
  }

  /// Áreas ofrecidas: solo habilitadas, más las ya asignadas aunque estén
  /// deshabilitadas para no quitarlas en silencio. Devuelve código → nombre.
  Map<String, String> get _opcionesAreas {
    final opciones = <String, String>{
      for (final a in widget.areas)
        if (a.activo || _areasSeleccionadas.contains(a.codigo)) a.codigo: a.nombre,
    };
    for (final codigo in _areasSeleccionadas) {
      opciones.putIfAbsent(codigo, () => codigo);
    }
    return opciones;
  }

  /// Construye el borrador a partir de los campos del formulario.
  UsuarioBorrador _borrador() => UsuarioBorrador(
        nombres: _nombres.text,
        apellidos: _apellidos.text,
        nombreUsuario: _usuario.text,
        cargo: _cargo.text,
        correoDrive: _drive.text,
        rol: _rol!,
        areas: _areasSeleccionadas.toList()..sort(),
      );

  /// Valida el formulario y lo envía; muestra el error del servidor si lo hay.
  /// Ignora pulsaciones repetidas mientras hay un guardado en curso.
  Future<void> _guardar() async {
    if (_guardando || !_formKey.currentState!.validate()) return;
    setState(() { _guardando = true; _error = null; });
    try {
      final datos = _borrador();
      if (_edita) {
        await widget.repositorio.editar(widget.usuario!.id, datos);
      } else {
        await widget.repositorio.crear(datos, correo: _correo.text, contrasena: _clave.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() { _error = UsuariosRepository.mensajeError(e); _guardando = false; });
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
          title: Text(_edita ? 'Editar usuario' : 'Nuevo usuario',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          leading: IconButton(
            tooltip: 'Cancelar',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _guardando ? null : () => Navigator.pop(context, false),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _seccion('Datos personales', [
                    _campo(_nombres, 'Nombres', Icons.badge_outlined,
                        validador: (v) => UsuarioValidadores.nombre(v, etiqueta: 'los nombres'),
                        capitalizacion: TextCapitalization.words),
                    _campo(_apellidos, 'Apellidos', Icons.badge_outlined,
                        validador: (v) => UsuarioValidadores.nombre(v, etiqueta: 'los apellidos'),
                        capitalizacion: TextCapitalization.words),
                    _campo(_cargo, 'Cargo (opcional)', Icons.work_outline_rounded,
                        validador: UsuarioValidadores.cargo,
                        capitalizacion: TextCapitalization.sentences),
                  ]),
                  _seccion('Acceso', [
                    _campo(_usuario, 'Nombre de usuario', Icons.alternate_email_rounded,
                        validador: UsuarioValidadores.nombreUsuario,
                        ayuda: 'Minúsculas, números, punto, guion o guion bajo.'),
                    _campo(_correo, 'Correo de acceso', Icons.mail_outline_rounded,
                        validador: UsuarioValidadores.correoAcceso,
                        teclado: TextInputType.emailAddress,
                        soloLectura: _edita,
                        ayuda: _edita ? 'El correo de acceso no se modifica desde aquí.' : null),
                    if (!_edita) _campoContrasena(),
                    _campo(_drive, 'Correo para Drive (opcional)', Icons.cloud_outlined,
                        validador: UsuarioValidadores.correoDrive,
                        teclado: TextInputType.emailAddress,
                        ayuda: 'Es configuración; no concede permisos de Drive por sí mismo.'),
                  ]),
                  _seccion('Rol y áreas', [_selectorRol(), _selectorAreas()]),
                  if (_error != null) ...[
                    CatalogoEstilo.nota(_error!, icono: Icons.error_outline_rounded),
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

  /// Agrupa campos relacionados bajo un título dentro de una tarjeta blanca.
  Widget _seccion(String titulo, List<Widget> hijos) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6E6E6)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: CatalogoEstilo.texto)),
            const SizedBox(height: 14),
            for (final h in hijos) ...[h, const SizedBox(height: 14)],
          ]),
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
  }) =>
      TextFormField(
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
          prefixIcon: Icon(icono),
          filled: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
          helperText: 'Mínimo 8 caracteres, con letras y números.',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: _verClave ? 'Ocultar contraseña' : 'Mostrar contraseña',
            icon: Icon(_verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _verClave = !_verClave),
          ),
          filled: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      );

  /// Lista desplegable de roles. Se bloquea al editar la cuenta propia.
  Widget _selectorRol() => DropdownButtonFormField<String>(
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
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        items: [
          for (final e in UsuarioAdministrativo.roles.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (_guardando || _esCuentaPropia) ? null : (v) => setState(() => _rol = v),
      );

  /// Mensaje de ayuda del selector de rol, según el contexto.
  String? get _ayudaRol =>
      _esCuentaPropia ? 'No puedes cambiar el rol de tu propia cuenta.' : null;

  /// Chips seleccionables con las áreas del catálogo HU-012.
  Widget _selectorAreas() {
    final opciones = _opcionesAreas.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Áreas asignadas',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CatalogoEstilo.texto)),
      const SizedBox(height: 4),
      const Text('Un usuario puede rotar entre varias áreas.', style: TextStyle(fontSize: 12)),
      const SizedBox(height: 10),
      if (opciones.isEmpty)
        const Text('No hay áreas habilitadas. Créalas en Financiamientos, seguros y áreas.',
            style: TextStyle(fontSize: 13))
      else
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in opciones)
            FilterChip(
              label: Text(o.value),
              selected: _areasSeleccionadas.contains(o.key),
              selectedColor: CatalogoEstilo.pastel,
              checkmarkColor: CatalogoEstilo.rojo,
              onSelected: _guardando
                  ? null
                  : (marcado) => setState(() {
                        marcado
                            ? _areasSeleccionadas.add(o.key)
                            : _areasSeleccionadas.remove(o.key);
                      }),
            ),
        ]),
    ]);
  }

  /// Botones Cancelar y Guardar; Guardar muestra progreso y se bloquea al enviar.
  Widget _acciones() => Row(children: [
        Expanded(
          child: TextButton(
            onPressed: _guardando ? null : () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            label: Text(_edita ? 'Guardar cambios' : 'Crear usuario'),
          ),
        ),
      ]);
}

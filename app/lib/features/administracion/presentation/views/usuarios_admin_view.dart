import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/usuarios_repository.dart';
import '../../data/catalogos_repository.dart';
import '../widgets/catalogo_estilo.dart';
import 'usuario_formulario_view.dart';

/// HU-020/HU-021/HU-022: consulta, alta, edición y habilitación de usuarios.
class UsuariosAdminView extends StatefulWidget {
  /// Entrada a la consulta administrativa de usuarios existentes.
  const UsuariosAdminView({super.key});

  /// Crea el estado del listado y sus filtros, sin funciones de alta o edición.
  @override
  State<UsuariosAdminView> createState() => _UsuariosAdminViewState();
}

class _UsuariosAdminViewState extends State<UsuariosAdminView> {
  final _repository = UsuariosRepository();
  final _buscador = TextEditingController();
  List<UsuarioAdministrativo> _usuarios = [];
  List<AreaUsuario> _areas = [];
  bool _cargando = true, _filtrosAbiertos = false, _estructuraPendiente = false;
  String _estado = 'TODOS', _rol = 'TODOS', _area = 'TODAS', _orden = 'NOMBRE';
  String? _error;
  int _revision = 0;

  /// Id del usuario cuyo cambio de estado está en curso; bloquea pulsaciones repetidas.
  String? _cambiandoEstadoId;

  /// Carga los perfiles reales al entrar a Gestión de usuarios.
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Libera el controlador del buscador al abandonar la vista.
  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  /// Solicita usuarios y áreas al repositorio, y conserva filtros todavía válidos.
  /// Descarta respuestas anteriores y actualizaciones posteriores al cierre de la vista.
  Future<void> _cargar() async {
    final revision = ++_revision;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _repository.cargar();
      if (!mounted || revision != _revision) return;
      setState(() {
        _usuarios = datos.usuarios;
        _areas = datos.areas;
        _estructuraPendiente = datos.estructuraPendiente;
        if (_rol != 'TODOS' && !_usuarios.any((u) => u.rol == _rol)) {
          _rol = 'TODOS';
        }
        if (_area != 'TODAS' && !_opcionesAreas.containsKey(_area)) {
          _area = 'TODAS';
        }
        _cargando = false;
      });
    } catch (e) {
      if (mounted && revision == _revision) {
        setState(() {
          _error = CatalogosRepository.mensajeError(e);
          _cargando = false;
        });
      }
    }
  }

  /// Resuelve un código/nombre histórico del perfil contra las áreas ya cargadas.
  /// No consulta la base; si no existe coincidencia conserva el texto original.
  AreaUsuario? _resolverArea(String token) {
    final valor = token.trim().toLowerCase();
    for (final a in _areas) {
      if (a.codigo.toLowerCase() == valor || a.nombre.toLowerCase() == valor) {
        return a;
      }
    }
    return null;
  }

  /// Obtiene una clave estable para el filtro: UUID del área o texto histórico normalizado.
  String _claveArea(String token) =>
      _resolverArea(token)?.id ?? 'texto:${token.trim().toLowerCase()}';

  /// Devuelve el nombre visible del área sin perder asignaciones históricas desconocidas.
  String _nombreArea(String token) => _resolverArea(token)?.nombre ?? token;

  /// Genera las opciones del filtro con las áreas realmente asignadas a usuarios,
  /// agrupando coincidencias por UUID para evitar opciones duplicadas.
  Map<String, String> get _opcionesAreas {
    final opciones = <String, String>{};
    for (final u in _usuarios) {
      for (final token in u.areas) {
        opciones[_claveArea(token)] = _nombreArea(token);
      }
    }
    return opciones;
  }

  /// Cuenta filtros de estado, rol y área activos para la etiqueta del botón Filtros.
  int get _numeroFiltros =>
      (_estado == 'TODOS' ? 0 : 1) +
      (_rol == 'TODOS' ? 0 : 1) +
      (_area == 'TODAS' ? 0 : 1);

  /// Restablece búsqueda, filtros y ordenación; reutiliza los datos ya cargados.
  void _limpiar() => setState(() {
    _buscador.clear();
    _estado = 'TODOS';
    _rol = 'TODOS';
    _area = 'TODAS';
    _orden = 'NOMBRE';
  });

  /// Abre el formulario de alta. Si se guardó un usuario, recarga el listado.
  Future<void> _nuevo() => _abrirFormulario(null);

  /// Abre el formulario precargado con [u]. Si hubo cambios, recarga el listado.
  Future<void> _editar(UsuarioAdministrativo u) => _abrirFormulario(u);

  /// Navega al formulario compartido por HU-021 y HU-022 y refresca al volver con éxito.
  Future<void> _abrirFormulario(UsuarioAdministrativo? u) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UsuarioFormularioView(
          usuario: u,
          areas: _areas,
          repositorio: _repository,
        ),
      ),
    );
    if (guardado != true || !mounted) return;
    _mensaje(u == null ? 'Usuario creado.' : 'Cambios guardados.');
    await _cargar();
  }

  /// Habilita o deshabilita a [u] tras confirmación. No elimina: conserva el historial.
  /// El servidor rechaza deshabilitarse a sí mismo o dejar sin administradores.
  Future<void> _alternarEstado(UsuarioAdministrativo u) async {
    if (_cambiandoEstadoId != null) return;
    final destino = !u.activo;
    if (!await _confirmarEstado(u, destino) || !mounted) return;
    setState(() => _cambiandoEstadoId = u.id);
    try {
      await _repository.cambiarEstado(u.id, activo: destino);
      if (!mounted) return;
      _mensaje(destino ? 'Usuario habilitado.' : 'Usuario deshabilitado.');
      await _cargar();
    } catch (e) {
      if (mounted) _mensaje(UsuariosRepository.mensajeError(e));
    } finally {
      if (mounted) setState(() => _cambiandoEstadoId = null);
    }
  }

  /// Pide confirmar el cambio de estado explicando su efecto; devuelve true si acepta.
  Future<bool> _confirmarEstado(UsuarioAdministrativo u, bool destino) async {
    final acepta = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(destino ? 'Habilitar usuario' : 'Deshabilitar usuario'),
        content: Text(
          destino
              ? '${u.nombreCompleto} podrá iniciar sesión nuevamente.'
              : '${u.nombreCompleto} no podrá iniciar sesión. Su historial se conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(destino ? 'Habilitar' : 'Deshabilitar'),
          ),
        ],
      ),
    );
    return acepta ?? false;
  }

  /// Muestra un aviso breve en la parte inferior de la pantalla.
  void _mensaje(String texto) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));

  /// Combina estado, rol, área y todas las palabras del buscador, y ordena el resultado.
  /// Todo se realiza en memoria: escribir o cambiar filtros no envía consultas nuevas.
  List<UsuarioAdministrativo> get _filtrados {
    final palabras = _buscador.text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final lista = _usuarios.where((u) {
      if (_estado != 'TODOS' && u.activo != (_estado == 'ACTIVOS')) {
        return false;
      }
      if (_rol != 'TODOS' && u.rol != _rol) return false;
      if (_area != 'TODAS' && !u.areas.any((a) => _claveArea(a) == _area)) {
        return false;
      }
      final texto =
          '${u.usuario} ${u.nombreCompleto} ${u.nombreAnterior} ${u.correo} ${u.cargo} ${u.rolVisible} ${u.areas.map(_nombreArea).join(' ')}'
              .toLowerCase();
      return palabras.every(texto.contains);
    }).toList();
    lista.sort((a, b) {
      if (_orden == 'RECIENTES') {
        final fecha = (b.creado ?? DateTime(1970)).compareTo(
          a.creado ?? DateTime(1970),
        );
        if (fecha != 0) return fecha;
      }
      final nombre = a.nombreCompleto.toLowerCase().compareTo(
        b.nombreCompleto.toLowerCase(),
      );
      return _orden == 'INVERSO' ? -nombre : nombre;
    });
    return lista;
  }

  /// Construye resumen táctil, buscador, filtros y tarjetas con creación visual diferida.
  /// La actualización al deslizar llama a _cargar; esta vista no modifica perfiles.
  @override
  Widget build(BuildContext context) {
    final lista = _filtrados;
    return Theme(
      data: CatalogoEstilo.tema(context),
      child: Scaffold(
        backgroundColor: CatalogoEstilo.fondo,
        floatingActionButton: _cargando || _error != null
            ? null
            : FloatingActionButton(
                tooltip: 'Nuevo usuario',
                backgroundColor: CatalogoEstilo.rojo,
                foregroundColor: Colors.white,
                onPressed: _nuevo,
                child: const Icon(Icons.person_add_alt_1_rounded),
              ),
        appBar: AppBar(
          backgroundColor: CatalogoEstilo.rojo,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            tooltip: 'Volver al menú',
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.go('/admin'),
          ),
          title: const Text(
            'Gestión de usuarios',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: CatalogoEstilo.rojo),
              )
            : _error != null
            ? _pantallaError()
            : RefreshIndicator(
                color: CatalogoEstilo.rojo,
                onRefresh: _cargar,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: _centrado(
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Equipo y accesos',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: CatalogoEstilo.texto,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Consulta al personal, sus roles y áreas asignadas.',
                                style: TextStyle(fontSize: 13, height: 1.5),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: _contador(
                                      'Todos',
                                      _usuarios.length,
                                      'TODOS',
                                      Icons.groups_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _contador(
                                      'Habilitados',
                                      _usuarios.where((u) => u.activo).length,
                                      'ACTIVOS',
                                      Icons.person_outline_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _contador(
                                      'Deshabilitados',
                                      _usuarios.where((u) => !u.activo).length,
                                      'INACTIVOS',
                                      Icons.person_off_outlined,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: _buscador,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Buscar nombre, usuario o correo',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: _buscador.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Limpiar búsqueda',
                                          onPressed: () =>
                                              setState(() => _buscador.clear()),
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${lista.length} de ${_usuarios.length} usuarios',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (_numeroFiltros > 0 ||
                                      _buscador.text.isNotEmpty)
                                    TextButton(
                                      onPressed: _limpiar,
                                      child: const Text('Limpiar'),
                                    ),
                                  Tooltip(
                                    message: _filtrosAbiertos
                                        ? 'Ocultar filtros'
                                        : 'Filtrar por rol, área y orden',
                                    child: OutlinedButton.icon(
                                      onPressed: () => setState(
                                        () => _filtrosAbiertos =
                                            !_filtrosAbiertos,
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: CatalogoEstilo.rojo,
                                        side: const BorderSide(
                                          color: Color(0xFFEBCBCB),
                                        ),
                                        minimumSize: const Size(44, 48),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(
                                        _filtrosAbiertos
                                            ? Icons.expand_less_rounded
                                            : Icons.tune_rounded,
                                        size: 19,
                                      ),
                                      label: Text(
                                        _numeroFiltros > 0
                                            ? 'Filtros ($_numeroFiltros)'
                                            : 'Filtros',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                alignment: Alignment.topCenter,
                                child: _filtrosAbiertos
                                    ? _panelFiltros()
                                    : const SizedBox.shrink(),
                              ),
                              if (_estructuraPendiente) ...[
                                const SizedBox(height: 12),
                                CatalogoEstilo.nota(
                                  'Los perfiles actuales están disponibles. Aplica la actualización de estructura de usuarios para disponer de usuario, nombres y apellidos separados.',
                                ),
                              ],
                              const SizedBox(height: 16),
                              if (lista.isEmpty) _sinResultados(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _centrado(
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: _tarjeta(lista[index]),
                          ),
                        ),
                        childCount: lista.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 90)),
                  ],
                ),
              ),
      ),
    );
  }

  /// Limita el ancho del contenido en pantallas amplias, conservando el margen móvil.
  Widget _centrado(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 850),
      child: child,
    ),
  );

  /// Dibuja un contador cuyo toque filtra por habilitación; no cambia el estado de usuarios.
  Widget _contador(
    String etiqueta,
    int cantidad,
    String filtro,
    IconData icono,
  ) {
    final seleccionado = _estado == filtro;
    return Semantics(
      selected: seleccionado,
      child: Material(
        color: seleccionado ? CatalogoEstilo.pastel : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: seleccionado
                ? const Color(0xFFE8BDBD)
                : const Color(0xFFE7E7E7),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          hoverColor: const Color(0xFFFFE5E5),
          onTap: () => setState(() => _estado = filtro),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Column(
              children: [
                Icon(icono, size: 22, color: CatalogoEstilo.rojo),
                const SizedBox(height: 8),
                Text(
                  '$cantidad',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: CatalogoEstilo.texto,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Construye selectores de rol, área y orden con opciones derivadas de los registros.
  Widget _panelFiltros() {
    final roles = _usuarios.map((u) => u.rol).toSet().toList()..sort();
    final areas = _opcionesAreas.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7E7E7)),
        ),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _rol,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: [
                const DropdownMenuItem(
                  value: 'TODOS',
                  child: Text('Todos los roles'),
                ),
                ...roles.map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(
                      UsuarioAdministrativo.roles[r] ?? 'Rol sin definir',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _rol = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _area,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Área asignada'),
              items: [
                const DropdownMenuItem(
                  value: 'TODAS',
                  child: Text('Todas las áreas'),
                ),
                ...areas.map(
                  (a) => DropdownMenuItem(
                    value: a.key,
                    child: Text(a.value, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _area = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _orden,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ordenar por'),
              items: const [
                DropdownMenuItem(value: 'NOMBRE', child: Text('Nombre: A–Z')),
                DropdownMenuItem(value: 'INVERSO', child: Text('Nombre: Z–A')),
                DropdownMenuItem(
                  value: 'RECIENTES',
                  child: Text('Registro más reciente'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _orden = v);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Resume un usuario con avatar, cargo/rol, correo y áreas.
  /// Tocar la tarjeta o el ojo abre sus datos completos; el lápiz edita y el icono
  /// de persona habilita o deshabilita (con confirmación).
  Widget _tarjeta(UsuarioAdministrativo u) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE6E6E6)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _detalle(u),
      hoverColor: const Color(0xFFFFF7F7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: CatalogoEstilo.pastel,
                  child: Text(
                    u.iniciales,
                    style: const TextStyle(
                      color: CatalogoEstilo.rojo,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.nombreCompleto,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: CatalogoEstilo.texto,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        u.cargo.isEmpty ? u.rolVisible : u.cargo,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _etiquetaEstado(u.activo),
              ],
            ),
            const SizedBox(height: 14),
            _linea(
              Icons.alternate_email_rounded,
              u.usuario.isEmpty ? 'Usuario por definir' : u.usuario,
            ),
            const SizedBox(height: 8),
            _linea(Icons.mail_outline_rounded, u.correo),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(u.rolVisible, icono: Icons.badge_outlined),
                ...u.areas
                    .take(2)
                    .map(
                      (a) =>
                          _chip(_nombreArea(a), icono: Icons.apartment_rounded),
                    ),
                if (u.areas.length > 2) _chip('+${u.areas.length - 2} áreas'),
                if (u.areas.isEmpty) _chip('Sin áreas asignadas'),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFEEEEEE)),
            Row(
              children: [
                const Expanded(
                  child: Text('Acciones', style: TextStyle(fontSize: 12)),
                ),
                _accion(
                  'Ver detalle del usuario',
                  Icons.visibility_outlined,
                  CatalogoEstilo.rojo,
                  () => _detalle(u),
                ),
                _accion(
                  'Editar usuario',
                  Icons.edit_outlined,
                  CatalogoEstilo.rojo,
                  () => _editar(u),
                ),
                _accionEstado(u),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  /// Botón de icono de tarjeta con tooltip, hover y objetivo táctil de 48 px.
  /// Con `alPresionar` nulo aparece deshabilitado.
  Widget _accion(
    String ayuda,
    IconData icono,
    Color color,
    VoidCallback? alPresionar,
  ) => IconButton(
    tooltip: ayuda,
    onPressed: alPresionar,
    color: color,
    hoverColor: CatalogoEstilo.pastel,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    icon: Icon(icono, size: 22),
  );

  /// Botón de habilitación: verde si el usuario está habilitado, rojo si no.
  /// Se bloquea en la cuenta propia y mientras otro cambio de estado está en curso.
  Widget _accionEstado(UsuarioAdministrativo u) {
    final propia = u.id == _repository.idSesion;
    final ocupado = _cambiandoEstadoId != null;
    final ayuda = propia
        ? 'No puedes deshabilitar tu propia cuenta'
        : u.activo
        ? 'Deshabilitar usuario'
        : 'Habilitar usuario';
    return _accion(
      ayuda,
      u.activo ? Icons.person_rounded : Icons.person_off_rounded,
      u.activo ? const Color(0xFF2E7D32) : CatalogoEstilo.rojo,
      propia || ocupado ? null : () => _alternarEstado(u),
    );
  }

  /// Dibuja una línea compacta de icono/texto; el detalle conserva el valor completo.
  Widget _linea(IconData icono, String texto) => Row(
    children: [
      Icon(icono, color: const Color(0xFF84848C), size: 17),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    ],
  );

  /// Muestra una etiqueta informativa de habilitación, sin acción de cambio.
  Widget _etiquetaEstado(bool activo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: activo ? CatalogoEstilo.pastel : const Color(0xFFEEEEEE),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      activo ? 'Habilitado' : 'Deshabilitado',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: activo ? CatalogoEstilo.rojo : const Color(0xFF66666E),
      ),
    ),
  );

  /// Construye una etiqueta compacta de rol o área para las tarjetas y el detalle.
  Widget _chip(String texto, {IconData? icono}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icono != null) ...[
          Icon(icono, size: 14, color: CatalogoEstilo.rojo),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  /// Abre un panel inferior desplazable con los datos del usuario ya cargado.
  /// No realiza otra consulta ni muestra contraseñas; los valores ausentes se indican.
  void _detalle(UsuarioAdministrativo u) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Theme(
        data: CatalogoEstilo.tema(ctx),
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * .88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: CatalogoEstilo.rojo,
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Datos del usuario',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.nombreCompleto,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _etiquetaEstado(u.activo),
                        const SizedBox(height: 20),
                        _dato('Nombre de usuario', u.usuario),
                        _dato('Nombres', u.nombres),
                        _dato('Apellidos', u.apellidos),
                        if (u.nombres.isEmpty && u.apellidos.isEmpty)
                          _dato('Nombre completo registrado', u.nombreAnterior),
                        _dato('Correo electrónico', u.correo),
                        _dato('Cargo / ocupación', u.cargo),
                        _dato('Rol', u.rolVisible),
                        if (u.colegioCodigo.isNotEmpty) ...[
                          _dato(
                            'Colegio profesional',
                            u.colegioNombre.isEmpty
                                ? u.colegioCodigo
                                : u.colegioNombre,
                          ),
                          _dato(
                            'Número de colegiatura (${u.colegioCodigo})',
                            u.numeroColegiatura,
                          ),
                          if (u.especialidadCodigo.isNotEmpty)
                            _dato(
                              'Especialidad / área profesional',
                              u.especialidadNombre.isEmpty
                                  ? u.especialidadCodigo
                                  : u.especialidadNombre,
                            ),
                        ],
                        const Text(
                          'Áreas asignadas',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF777780),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (u.areas.isEmpty)
                          const Text(
                            'Sin áreas asignadas',
                            style: TextStyle(fontSize: 14),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: u.areas
                                .map(
                                  (a) => _chip(
                                    _nombreArea(a),
                                    icono: Icons.apartment_rounded,
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 20),
                        _dato('Registrado', _fecha(u.creado)),
                        _dato('Última actualización', _fecha(u.actualizado)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Muestra etiqueta y valor seleccionable, usando Sin registrar cuando está vacío.
  Widget _dato(String etiqueta, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 12, color: Color(0xFF777780)),
        ),
        const SizedBox(height: 6),
        SelectableText(
          valor.isEmpty ? 'Sin registrar' : valor,
          style: const TextStyle(fontSize: 14, color: CatalogoEstilo.texto),
        ),
      ],
    ),
  );

  /// Formatea una fecha en la zona horaria del dispositivo como día/mes/año y hora.
  /// Si el dato no existe devuelve vacío para que la vista indique Sin registrar.
  String _fecha(DateTime? valor) {
    if (valor == null) return '';
    final f = valor.toLocal();
    return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} '
        '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
  }

  /// Distingue ausencia de usuarios de un filtro sin coincidencias y permite limpiar filtros.
  Widget _sinResultados() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Center(
      child: Column(
        children: [
          const Icon(
            Icons.person_search_outlined,
            size: 42,
            color: CatalogoEstilo.rojo,
          ),
          const SizedBox(height: 12),
          Text(
            _usuarios.isEmpty
                ? 'Todavía no hay usuarios registrados'
                : 'No hay usuarios con estos filtros',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (_usuarios.isNotEmpty)
            TextButton(onPressed: _limpiar, child: const Text('Mostrar todos')),
        ],
      ),
    ),
  );

  /// Muestra el fallo de consulta y ofrece reintentar la carga de datos reales.
  Widget _pantallaError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 42,
            color: CatalogoEstilo.rojo,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../../../core/theme/tema_area.dart';
import '../../data/catalogos_repository.dart';
import '../widgets/catalogo_editores.dart';
import '../widgets/catalogo_estilo.dart';

class CatalogosAdminView extends StatefulWidget {
  /// Entrada de Administrador para gestionar áreas y seguros/convenios.
  const CatalogosAdminView({super.key});

  /// Crea el estado de listas, filtros y operaciones administrativas.
  @override
  State<CatalogosAdminView> createState() => _CatalogosAdminViewState();
}

class _CatalogosAdminViewState extends State<CatalogosAdminView> {
  final _repository = CatalogosRepository();
  final _busqueda = TextEditingController();
  List<AreaCatalogo> _areas = [];
  List<FinanciamientoCatalogo> _financiamientos = [];
  List<MedicamentoCobertura> _medicamentos = [];
  bool _cargando = true, _operando = false;
  String? _error;
  String _estado = 'TODOS', _tipo = 'TODOS';
  int _pestana = 0, _revision = 0;

  /// Inicia la primera carga de los catálogos al abrir la pantalla.
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Libera el controlador del buscador cuando se abandona la pantalla.
  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  /// Consulta áreas, financiamientos y medicamentos en paralelo mediante el repositorio.
  /// La revisión descarta respuestas antiguas si comenzó otra carga o se cerró la vista;
  /// los errores se muestran sin reemplazar la información por datos ficticios.
  Future<void> _cargar() async {
    final revision = ++_revision;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final result = await Future.wait<Object>([
        _repository.areas(),
        _repository.financiamientos(),
        _repository.medicamentos(),
      ]);
      if (!mounted || revision != _revision) return;
      setState(() {
        _areas = result[0] as List<AreaCatalogo>;
        _financiamientos = result[1] as List<FinanciamientoCatalogo>;
        _medicamentos = result[2] as List<MedicamentoCobertura>;
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

  /// Abre el editor correspondiente a la pestaña actual, vacío o precargado.
  /// Al regresar con true recarga los datos guardados; cancelar no escribe cambios.
  Future<void> _editar({
    AreaCatalogo? area,
    FinanciamientoCatalogo? financiamiento,
  }) async {
    if (_operando || _cargando) return;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: CatalogoEstilo.tema(ctx),
        child: _pestana == 0
            ? AreaEditor(area: area, repository: _repository)
            : FinanciamientoEditor(
                registro: financiamiento,
                medicamentos: _medicamentos,
                repository: _repository,
              ),
      ),
    );
    if (result == true && mounted) {
      _mensaje('Cambios guardados.');
      await _cargar();
    }
  }

  /// Procesa habilitación o eliminación y bloquea pulsaciones simultáneas.
  /// Solo eliminar pide confirmación. Después llama a la RPC mediante el repositorio,
  /// muestra el resultado y recarga la lista; el servidor decide si se puede borrar.
  Future<void> _accion({
    required String entidad,
    required String id,
    required String nombre,
    required bool activo,
    required bool eliminar,
  }) async {
    if (_operando || _cargando) return;
    setState(() => _operando = true);
    try {
      if (eliminar) {
        final confirmado = await MensajesApp.confirmar(
          context,
          titulo: 'Eliminar registro',
          mensaje:
              '¿Eliminar «$nombre»? Solo se permite si no tiene registros asociados. Esta acción no se puede deshacer.',
          accion: 'Eliminar registro',
          destructivo: true,
        );
        if (confirmado != true || !mounted) return;
      }
      if (eliminar) {
        await _repository.eliminar(entidad, id);
      } else {
        await _repository.cambiarEstado(entidad, id, !activo);
      }
      if (!mounted) return;
      _mensaje(
        eliminar
            ? 'Registro eliminado.'
            : activo
            ? 'Registro deshabilitado.'
            : 'Registro habilitado.',
      );
      await _cargar();
    } catch (e) {
      if (mounted) _mensaje(CatalogosRepository.mensajeError(e), error: true);
    } finally {
      if (mounted) setState(() => _operando = false);
    }
  }

  /// Presenta el resultado de una operación mediante un aviso temporal.
  void _mensaje(String texto, {bool error = false}) => MensajesApp.mostrar(
    context,
    texto,
    tipo: error ? TipoMensaje.error : TipoMensaje.exito,
  );

  /// Comprueba el filtro Todos/Habilitados/Deshabilitados sobre una fila ya cargada.
  bool _cumpleEstado(bool activo) =>
      _estado == 'TODOS' || (_estado == 'ACTIVOS' ? activo : !activo);

  /// Construye las dos pestañas, buscador, filtros, listado y botón Agregar.
  /// La búsqueda y los filtros operan en memoria; deslizar hacia abajo sí vuelve
  /// a consultar Supabase mediante _cargar.
  @override
  Widget build(BuildContext context) {
    final q = _busqueda.text.trim().toLowerCase();
    final areas = _areas
        .where(
          (a) =>
              _cumpleEstado(a.activo) &&
              '${a.codigo} ${a.nombre} ${a.descripcion}'.toLowerCase().contains(
                q,
              ),
        )
        .toList();
    final financiamientos = _financiamientos
        .where(
          (f) =>
              _cumpleEstado(f.activo) &&
              (_tipo == 'TODOS' || _tipo == f.tipo) &&
              '${f.nombre} ${f.descripcion}'.toLowerCase().contains(q),
        )
        .toList();
    final count = _pestana == 0 ? areas.length : financiamientos.length;
    return Theme(
      data: CatalogoEstilo.tema(context),
      child: Builder(
        builder: (localContext) => Scaffold(
          backgroundColor: CatalogoEstilo.fondo,
          appBar: AppBar(
            toolbarHeight: DisenoAdaptable.altoCabecera(
              context,
              base: kToolbarHeight,
            ),
            backgroundColor: CatalogoEstilo.rojo,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            actionsIconTheme: const IconThemeData(color: Colors.white),
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              tooltip: 'Volver al menú',
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.go('/admin'),
            ),
            title: const Text(
              'Gestión administrativa',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          body: ContenidoAdaptable(
            anchoMaximo: 1100,
            padding: EdgeInsets.zero,
            child: SafeArea(
              child: PanelListaAdaptable(
                children: [
                  Material(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                _tab(0, 'Áreas', Icons.apartment_rounded),
                                const SizedBox(width: 4),
                                _tab(
                                  1,
                                  'Seguros y convenios',
                                  Icons.handshake_rounded,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _busqueda,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: _pestana == 0
                                  ? 'Buscar área o código'
                                  : 'Buscar seguro o convenio',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _busqueda.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Limpiar búsqueda',
                                      onPressed: () =>
                                          setState(() => _busqueda.clear()),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _filtroEstado('TODOS', 'Todos'),
                                _filtroEstado('ACTIVOS', 'Habilitados'),
                                _filtroEstado('INACTIVOS', 'Deshabilitados'),
                              ],
                            ),
                          ),
                          if (_pestana == 1)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  for (final t in [
                                    'TODOS',
                                    'SEGURO',
                                    'CONVENIO',
                                  ])
                                    ChoiceChip(
                                      label: Text(
                                        t == 'TODOS'
                                            ? 'Ambos tipos'
                                            : t == 'SEGURO'
                                            ? 'Seguros'
                                            : 'Convenios',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      selected: _tipo == t,
                                      selectedColor: CatalogoEstilo.pastel,
                                      onSelected: (_) =>
                                          setState(() => _tipo = t),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_operando)
                    const LinearProgressIndicator(
                      color: CatalogoEstilo.rojo,
                      backgroundColor: CatalogoEstilo.pastel,
                    ),
                  Expanded(
                    child: _cargando
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: CatalogoEstilo.rojo,
                            ),
                          )
                        : _error != null
                        ? _estadoVacio(
                            Icons.cloud_off_rounded,
                            'No se pudo cargar',
                            _error!,
                            reintentar: true,
                          )
                        : RefreshIndicator(
                            color: CatalogoEstilo.rojo,
                            onRefresh: _cargar,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                96,
                              ),
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 850,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$count ${_pestana == 0 ? 'áreas' : 'registros'}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF66666F),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        if (count == 0)
                                          _estadoVacio(
                                            _pestana == 0
                                                ? Icons.apartment_rounded
                                                : Icons.handshake_rounded,
                                            'No hay resultados',
                                            'Agrega un registro o cambia los filtros de búsqueda.',
                                          ),
                                        if (_pestana == 0)
                                          ...areas.map(_tarjetaArea)
                                        else
                                          ...financiamientos.map(
                                            _tarjetaFinanciamiento,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: _cargando || _operando || _error != null
              ? null
              : FloatingActionButton(
                  tooltip: _pestana == 0
                      ? 'Agregar área'
                      : 'Agregar seguro o convenio',
                  backgroundColor: CatalogoEstilo.rojo,
                  foregroundColor: Colors.white,
                  hoverColor: const Color(0xFFA61E1E),
                  onPressed: () => _editar(),
                  child: const Icon(Icons.add_rounded),
                ),
        ),
      ),
    );
  }

  /// Construye una pestaña con icono, selección y hover; cambiarla limpia la búsqueda.
  Widget _tab(int index, String texto, IconData icon) => Expanded(
    child: Material(
      color: _pestana == index ? CatalogoEstilo.rojo : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        hoverColor: _pestana == index ? Colors.white12 : CatalogoEstilo.pastel,
        onTap: _operando
            ? null
            : () => setState(() {
                _pestana = index;
                _busqueda.clear();
              }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: _pestana == index ? Colors.white : CatalogoEstilo.texto,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _pestana == index
                        ? Colors.white
                        : CatalogoEstilo.texto,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  /// Construye un chip que cambia el filtro local de habilitación.
  Widget _filtroEstado(String value, String label) => ChoiceChip(
    label: Text(label, style: const TextStyle(fontSize: 12)),
    selected: _estado == value,
    selectedColor: CatalogoEstilo.pastel,
    onSelected: (_) => setState(() => _estado = value),
  );

  /// Muestra una lista vacía o un error y, si corresponde, permite reintentar la carga.
  Widget _estadoVacio(
    IconData icon,
    String titulo,
    String detalle, {
    bool reintentar = false,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: CatalogoEstilo.rojo),
          const SizedBox(height: 14),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          if (reintentar) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    ),
  );

  /// Adapta los datos de un área y enlaza sus acciones con el componente común.
  Widget _tarjetaArea(AreaCatalogo a) => _tarjeta(
    nombre: a.nombre,
    subtitulo: a.codigo,
    descripcion: a.descripcion,
    icono: Icons.apartment_rounded,
    activo: a.activo,
    detalle:
        'Tema: ${TemaArea.desde(a.temaColor).nombre} · ${a.administraStock ? 'Administra stock propio' : 'Solicita productos o kits'}',
    editar: () => _editar(area: a),
    estado: () => _accion(
      entidad: 'AREA',
      id: a.id,
      nombre: a.nombre,
      activo: a.activo,
      eliminar: false,
    ),
    eliminar: () => _accion(
      entidad: 'AREA',
      id: a.id,
      nombre: a.nombre,
      activo: a.activo,
      eliminar: true,
    ),
  );

  /// Adapta tipo, porcentaje y número de medicamentos incluidos a una tarjeta.
  /// El icono distingue Seguro de Convenio sin cambiar las reglas de escritura.
  Widget _tarjetaFinanciamiento(FinanciamientoCatalogo f) => _tarjeta(
    nombre: f.nombre,
    subtitulo: f.tipo == 'SEGURO' ? 'Seguro' : 'Convenio',
    descripcion: f.descripcion,
    icono: f.tipo == 'SEGURO' ? Icons.shield_outlined : Icons.handshake_rounded,
    activo: f.activo,
    detalle:
        '${f.porcentaje.toStringAsFixed(2)} % sobre Kairos · ${f.medicamentos.length} medicamentos incluidos',
    editar: () => _editar(financiamiento: f),
    estado: () => _accion(
      entidad: 'FINANCIAMIENTO',
      id: f.id,
      nombre: f.nombre,
      activo: f.activo,
      eliminar: false,
    ),
    eliminar: () => _accion(
      entidad: 'FINANCIAMIENTO',
      id: f.id,
      nombre: f.nombre,
      activo: f.activo,
      eliminar: true,
    ),
  );

  /// Compone el contenido del registro, la etiqueta de estado y su botón debajo.
  /// La fila inferior reparte el ancho entre Editar y Eliminar; no hace consultas.
  Widget _tarjeta({
    required String nombre,
    required String subtitulo,
    required String descripcion,
    required IconData icono,
    required bool activo,
    required String detalle,
    required VoidCallback editar,
    required VoidCallback estado,
    required VoidCallback eliminar,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE7E7E7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _operando ? null : editar,
        hoverColor: const Color(0xFFFFF8F8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilaDetalleAdaptable(
                principales: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: CatalogoEstilo.pastel,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                icono,
                                color: CatalogoEstilo.rojo,
                                size: 23,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: CatalogoEstilo.texto,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    subtitulo,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF72727A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (descripcion.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            descripcion,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: Color(0xFF65656F),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          detalle,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: CatalogoEstilo.rojo,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                detalle: SizedBox(
                  width: 100,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: activo
                              ? CatalogoEstilo.pastel
                              : const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          activo ? 'Habilitado' : 'Deshabilitado',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: activo
                                ? CatalogoEstilo.rojo
                                : const Color(0xFF707078),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        toggled: activo,
                        child: SizedBox(
                          width: 52,
                          child: _botonAccion(
                            activo
                                ? 'Habilitado · Toca para deshabilitar'
                                : 'Deshabilitado · Toca para habilitar',
                            icono,
                            activo
                                ? const Color(0xFF2E7D32)
                                : CatalogoEstilo.rojo,
                            estado,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Color(0xFFEEEEEE)),
              const SizedBox(height: 6),
              AccionesAdaptables(
                anchoMinimo: 150,
                acciones: [
                  _botonAccion(
                    'Editar',
                    Icons.edit_outlined,
                    CatalogoEstilo.rojo,
                    editar,
                  ),
                  _botonAccion(
                    'Eliminar',
                    Icons.delete_outline_rounded,
                    CatalogoEstilo.rojo,
                    eliminar,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  /// Dibuja un botón de icono con tooltip, borde, hover y objetivo táctil de 48 px.
  /// Durante una operación queda deshabilitado para evitar solicitudes repetidas.
  Widget _botonAccion(
    String tooltip,
    IconData icono,
    Color color,
    VoidCallback accion,
  ) => Tooltip(
    message: tooltip,
    child: OutlinedButton(
      onPressed: _operando ? null : accion,
      style:
          OutlinedButton.styleFrom(
            foregroundColor: color,
            backgroundColor: color.withOpacity(.04),
            side: BorderSide(color: color.withOpacity(.20)),
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith(
              (states) =>
                  states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.pressed) ||
                      states.contains(WidgetState.focused)
                  ? color.withOpacity(.10)
                  : null,
            ),
          ),
      child: Icon(icono, size: 23, semanticLabel: tooltip),
    ),
  );
}

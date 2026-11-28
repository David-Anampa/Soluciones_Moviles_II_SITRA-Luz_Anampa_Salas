import '../../../../core/widgets/accion_gestion.dart';
import '../../data/gestion_registros_repository.dart';
import '../widgets/detalle_registro_gestion.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/tema_pedidos.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../../../core/widgets/selector_catalogo.dart';
import '../../../../core/widgets/opcion_multiple.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../almacen/domain/solicitud_id.dart';
import '../../data/profesionales_repository.dart';

List<Map<String, dynamic>> _filas(dynamic value) =>
    (value as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();

class ProfesionalesAdminView extends StatefulWidget {
  const ProfesionalesAdminView({super.key});
  @override
  State<ProfesionalesAdminView> createState() => _ProfesionalesAdminViewState();
}

class _ProfesionalesAdminViewState extends State<ProfesionalesAdminView> {
  final _repo = ProfesionalesRepository();
  final _gestion = GestionRegistrosRepository();
  Map<String, dynamic> _relaciones = {};
  final _buscar = TextEditingController();
  List<Map<String, dynamic>> _personas = [], _colegios = [], _areas = [];
  String _filtro = 'TODOS';
  String? _error;
  bool _cargando = true, _operando = false;
  int _limite = 20;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _repo.cargar();
      final relaciones = await _gestion.cargar();
      if (!mounted) return;
      setState(() {
        _relaciones = relaciones;
        _personas = _filas(datos['profesionales']);
        _colegios = _filas(datos['colegios']);
        _areas = _filas(datos['areas']);
      });
    } catch (e) {
      if (mounted) setState(() => _error = ProfesionalesRepository.error(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar([Map<String, dynamic>? persona]) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditorProfesional(
        persona: persona,
        colegios: _colegios,
        areas: _areas,
        repo: _repo,
      ),
    );
    if (guardado == true && mounted) {
      MensajesApp.mostrar(context, 'Profesional guardado.');
      await _cargar();
    }
  }

  Future<void> _estado(Map<String, dynamic> persona) async {
    final activo = persona['activo'] == true;
    final acepta = await MensajesApp.confirmar(
      context,
      titulo: activo ? 'Desactivar profesional' : 'Activar profesional',
      mensaje: activo
          ? 'Dejará de aparecer en nuevos pedidos. Sus fichas anteriores conservarán el historial.'
          : 'Volverá a estar disponible en sus áreas asignadas.',
      accion: activo ? 'Desactivar' : 'Activar',
    );
    if (!acepta || !mounted) return;
    setState(() => _operando = true);
    try {
      await _repo.estado(persona);
      if (!mounted) return;
      MensajesApp.mostrar(context, 'Estado actualizado.');
      await _cargar();
    } catch (e) {
      if (mounted) {
        MensajesApp.mostrar(
          context,
          ProfesionalesRepository.error(e),
          tipo: TipoMensaje.error,
        );
      }
    } finally {
      if (mounted) setState(() => _operando = false);
    }
  }

  Future<void> _detalle(Map<String, dynamic> p, {bool eliminar = false}) async {
    final borrado = await mostrarRegistroGestion(
      context,
      entidad: 'PROFESIONAL',
      id: p['id'] as String,
      nombre: p['nombre'] as String,
      eliminar: eliminar,
      datos: {
        'Colegio': _colegio(p),
        'Colegiatura':
            '${p['numero_colegiatura'] ?? p['colegiatura'] ?? 'Pendiente'}',
        'Áreas': (p['areas'] as List)
            .map((a) => _nombreArea(a as String))
            .join(', '),
      },
    );
    if (borrado && mounted) {
      MensajesApp.mostrar(
        context,
        'Profesional eliminado; auditoría conservada.',
      );
      await _cargar();
    }
  }

  String _nombreArea(String codigo) =>
      _areas.where((a) => a['codigo'] == codigo).firstOrNull?['nombre']
          as String? ??
      codigo;
  String _colegio(Map<String, dynamic> p) =>
      _colegios
              .where((c) => c['codigo'] == p['colegio_codigo'])
              .firstOrNull?['nombre']
          as String? ??
      'Colegio pendiente de completar';
  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthViewModel>().currentUser?.rol !=
        UserRole.administrador) {
      return const Scaffold(
        body: Center(child: Text('Acceso exclusivo de Administración.')),
      );
    }
    final q = _buscar.text.trim().toLowerCase();
    final lista = _personas
        .where(
          (p) =>
              '${p['nombre']} ${p['numero_colegiatura'] ?? p['colegiatura'] ?? ''} ${_colegio(p)}'
                  .toLowerCase()
                  .contains(q) &&
              (_filtro == 'TODOS' ||
                  (_filtro == 'ACTIVOS'
                      ? p['activo'] == true
                      : p['activo'] != true)),
        )
        .toList();
    return Theme(
      data: TemaPedidos.aplicar(context, 'ADMINISTRADOR'),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestionar profesionales'),
          leading: IconButton(
            tooltip: 'Volver al menú',
            onPressed: () => context.go('/admin'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _cargando || _operando ? null : _cargar,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFFC62828),
          foregroundColor: Colors.white,
          onPressed: _cargando || _operando ? null : () => _editar(),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Añadir profesional'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: ContenidoAdaptable(
              anchoMaximo: 900,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FranjaPedidos(
                      titulo: 'Buscar profesionales',
                      icono: Icons.manage_search_rounded,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _buscar,
                      onChanged: (_) => setState(() => _limite = 20),
                      decoration: const InputDecoration(
                        labelText: 'Nombre o colegiatura',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectorCatalogo(
                      value: _filtro,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        prefixIcon: Icon(Icons.filter_alt_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'TODOS', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'ACTIVOS',
                          child: Text('Activos'),
                        ),
                        DropdownMenuItem(
                          value: 'INACTIVOS',
                          child: Text('Inactivos'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _filtro = v;
                            _limite = 20;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      MensajesApp.nota(_error!, tipo: TipoMensaje.error),
                      const SizedBox(height: 12),
                    ],
                    if (_cargando)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      FranjaPedidos(
                        titulo: 'Profesionales (${lista.length})',
                        icono: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 12),
                      if (lista.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No hay profesionales que coincidan.'),
                        ),
                      for (final p in lista.take(_limite))
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: Color(0xFFFFF0F0),
                                      child: Icon(
                                        Icons.person_outline_rounded,
                                        color: Color(0xFFC62828),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        p['nombre'] as String,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    AccionGestion(
                                      ayuda: p['activo'] == true
                                          ? 'Desactivar profesional'
                                          : 'Activar profesional',
                                      icono: p['activo'] == true
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.block_rounded,
                                      activa: p['activo'] == true,
                                      onPressed: _operando
                                          ? null
                                          : () => _estado(p),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(_colegio(p)),
                                const SizedBox(height: 6),
                                Text(
                                  'Colegiatura: ${p['numero_colegiatura'] ?? p['colegiatura'] ?? 'Pendiente'}',
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final codigo in (p['areas'] as List))
                                      Chip(
                                        label: Text(
                                          _nombreArea(codigo as String),
                                        ),
                                      ),
                                  ],
                                ),
                                if (p['colegio_codigo'] == null ||
                                    (p['areas'] as List).isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Completa la colegiatura y las áreas para usarlo en nuevos pedidos.',
                                      style: TextStyle(
                                        color: Color(0xFF855300),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                AccionesAdaptables(
                                  anchoMinimo: 70,
                                  acciones: [
                                    AccionGestion(
                                      ayuda: 'Ver detalle',
                                      icono: Icons.visibility_outlined,
                                      onPressed: _operando
                                          ? null
                                          : () => _detalle(p),
                                    ),
                                    AccionGestion(
                                      ayuda: 'Editar profesional',
                                      icono: Icons.edit_outlined,
                                      onPressed: _operando
                                          ? null
                                          : () => _editar(p),
                                    ),
                                    AccionGestion(
                                      ayuda:
                                          GestionRegistrosRepository.permite(
                                            _relaciones,
                                            'PROFESIONAL',
                                            p['id'] as String,
                                          )
                                          ? 'Eliminar profesional'
                                          : GestionRegistrosRepository.motivo(
                                              _relaciones,
                                              'PROFESIONAL',
                                              p['id'] as String,
                                            ),
                                      icono: Icons.delete_outline_rounded,
                                      onPressed:
                                          _operando ||
                                              !GestionRegistrosRepository.permite(
                                                _relaciones,
                                                'PROFESIONAL',
                                                p['id'] as String,
                                              )
                                          ? null
                                          : () => _detalle(p, eliminar: true),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (lista.length > _limite)
                        TextButton(
                          onPressed: () => setState(() => _limite += 20),
                          child: const Text('Ver más profesionales'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }
}

class _EditorProfesional extends StatefulWidget {
  final Map<String, dynamic>? persona;
  final List<Map<String, dynamic>> colegios, areas;
  final ProfesionalesRepository repo;
  const _EditorProfesional({
    this.persona,
    required this.colegios,
    required this.areas,
    required this.repo,
  });
  @override
  State<_EditorProfesional> createState() => _EditorProfesionalState();
}

class _EditorProfesionalState extends State<_EditorProfesional> {
  // Áreas asistenciales acordadas; excluir dependencias logísticas del formulario.
  static const _areasAtencion = {
    'HOSPITALIZACION',
    'SOP',
    'EMERGENCIA',
    'NEONATOLOGIA',
    'COCHE_PAROS',
  };
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nombre, _numero;
  late final String _id;
  late Set<String> _areas;
  late List<Map<String, dynamic>> _colegios;
  String? _colegio, _error;
  bool _guardando = false;
  @override
  void initState() {
    super.initState();
    final p = widget.persona;
    _id = p?['id'] as String? ?? generarSolicitudId();
    _nombre = TextEditingController(text: p?['nombre'] as String? ?? '');
    _numero = TextEditingController(
      text: (p?['numero_colegiatura'] ?? p?['colegiatura'] ?? '')
          .toString()
          .replaceFirst(RegExp(r'^CMP[\s-]*', caseSensitive: false), ''),
    );
    _colegio = p?['colegio_codigo'] as String?;
    _areas = (p?['areas'] as List? ?? [])
        .cast<String>()
        .where(_areasAtencion.contains)
        .toSet();
    _colegios = List.of(widget.colegios);
  }

  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) return;
    if (_areas.isEmpty) {
      setState(() => _error = 'Selecciona una o varias áreas.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repo.guardar(
        id: _id,
        nombre: _nombre.text,
        colegio: _colegio!,
        numero: _numero.text,
        areas: _areas,
        version: widget.persona?['updated_at'] as String?,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = ProfesionalesRepository.error(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _otroColegio() async {
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: TemaPedidos.aplicar(ctx, 'ADMINISTRADOR'),
        child: _EditorColegio(repo: widget.repo),
      ),
    );
    if (resultado != true || !mounted) return;
    try {
      final datos = await widget.repo.cargar();
      if (mounted) setState(() => _colegios = _filas(datos['colegios']));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Colegio guardado. No se pudo actualizar la lista; vuelve a abrir el formulario.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: TemaPedidos.aplicar(context, 'ADMINISTRADOR'),
    child: PopScope(
      canPop: !_guardando,
      child: DialogoAdaptable(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FranjaPedidos(
                  titulo: widget.persona == null
                      ? 'Añadir profesional'
                      : 'Editar profesional',
                  icono: Icons.badge_outlined,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nombre,
                  enabled: !_guardando,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v ?? '').trim().length < 3
                      ? 'Ingresa el nombre completo.'
                      : null,
                ),
                const SizedBox(height: 16),
                SelectorCatalogo(
                  key: ValueKey(_colegio),
                  value: _colegios.any((c) => c['codigo'] == _colegio)
                      ? _colegio
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Colegio profesional',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                  items: _colegios
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c['codigo'] as String,
                          child: Text(
                            '${c['nombre']} (${c['sigla']})',
                            softWrap: true,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _guardando
                      ? null
                      : (v) => setState(() => _colegio = v),
                  validator: (v) => v == null ? 'Selecciona el colegio.' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _guardando ? null : _otroColegio,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Añadir otro colegio'),
                  ),
                ),
                TextFormField(
                  controller: _numero,
                  enabled: !_guardando,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Número de colegiatura',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                  validator: (v) =>
                      !RegExp(
                            r'^[A-Za-z0-9 ./-]{1,40}$',
                          ).hasMatch((v ?? '').trim()) ||
                          !RegExp(r'[A-Za-z0-9]').hasMatch(v ?? '')
                      ? 'Ingresa un número válido.'
                      : null,
                ),
                const SizedBox(height: 20),
                const FranjaPedidos(
                  titulo: 'Áreas de atención',
                  icono: Icons.apartment_rounded,
                ),
                const SizedBox(height: 12),
                for (final a in widget.areas.where(
                  (a) =>
                      _areasAtencion.contains(a['codigo']) &&
                      (a['activo'] == true || _areas.contains(a['codigo'])),
                ))
                  OpcionMultiple(
                    titulo:
                        '${a['nombre']}${a['activo'] == true ? '' : ' · Inactiva'}',
                    seleccionada: _areas.contains(a['codigo']),
                    onChanged: _guardando
                        ? null
                        : (v) => setState(() {
                            if (v == true) {
                              _areas.add(a['codigo'] as String);
                            } else {
                              _areas.remove(a['codigo']);
                            }
                          }),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  MensajesApp.nota(_error!, tipo: TipoMensaje.error),
                ],
                const SizedBox(height: 20),
                AccionesAdaptables(
                  acciones: [
                    OutlinedButton(
                      onPressed: _guardando
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_guardando ? 'Guardando…' : 'Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    _nombre.dispose();
    _numero.dispose();
    super.dispose();
  }
}

class _EditorColegio extends StatefulWidget {
  final ProfesionalesRepository repo;
  const _EditorColegio({required this.repo});
  @override
  State<_EditorColegio> createState() => _EditorColegioState();
}

class _EditorColegioState extends State<_EditorColegio> {
  final _nombre = TextEditingController(), _sigla = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _guardando = false;
  String? _error;
  Future<void> _guardar() async {
    if (_guardando || !_form.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repo.colegio(_nombre.text, _sigla.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = ProfesionalesRepository.error(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: DialogoAdaptable(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FranjaPedidos(
                titulo: 'Añadir colegio',
                icono: Icons.account_balance_outlined,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombre,
                enabled: !_guardando,
                minLines: 1,
                maxLines: 3,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Nombre oficial del colegio',
                ),
                validator: (v) => (v ?? '').trim().length < 5
                    ? 'Ingresa el nombre oficial.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sigla,
                enabled: !_guardando,
                maxLength: 12,
                decoration: const InputDecoration(labelText: 'Sigla'),
                validator: (v) =>
                    RegExp(r'^[A-Za-z0-9]{2,12}$').hasMatch((v ?? '').trim())
                    ? null
                    : 'Ingresa la sigla (2 a 12 letras o números).',
              ),
              if (_error != null)
                MensajesApp.nota(_error!, tipo: TipoMensaje.error),
              const SizedBox(height: 16),
              AccionesAdaptables(
                acciones: [
                  OutlinedButton(
                    onPressed: _guardando ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: Text(_guardando ? 'Guardando…' : 'Guardar colegio'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    _nombre.dispose();
    _sigla.dispose();
    super.dispose();
  }
}

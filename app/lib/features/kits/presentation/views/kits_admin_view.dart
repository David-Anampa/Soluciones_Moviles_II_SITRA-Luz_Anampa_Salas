import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/tema_area.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../../administracion/presentation/widgets/catalogo_estilo.dart';
import '../../data/repositories/kits_repository.dart';
import '../../domain/entities/kit_entity.dart';
import '../widgets/kit_card.dart';
import 'kit_formulario_view.dart';

class KitsAdminView extends StatefulWidget {
  const KitsAdminView({super.key});

  @override
  State<KitsAdminView> createState() => _KitsAdminViewState();
}

class _KitsAdminViewState extends State<KitsAdminView> {
  final KitsRepository _repository = KitsRepository();
  final TextEditingController _searchCtrl = TextEditingController();

  List<KitEntity> _todosLosKits = [];
  List<AreaKit> _areas = [];
  ContextoKits? _contexto;
  Map<String, MedicamentoKit> _disponibilidad = {};
  bool _operando = false;
  bool get _puedeGestionar => _contexto?.puedeGestionar == true;
  bool _cargando = true;
  String? _error;

  // Filtros
  String _filtroTexto = '';
  String? _filtroEstado; // null: Todos, 'ACTIVOS', 'INACTIVOS'
  String? _filtroArea; // null: Todas las áreas

  /// Resuelve el tema desde el área, conservando Administración en rojo sin selección.
  TemaArea _temaDeArea(String? codigo) {
    for (final area in _areas) {
      if (area.codigo == codigo) return TemaArea.desde(area.temaColor);
    }
    return TemaArea.opciones.first;
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Consulta los kits y las áreas disponibles para alimentar la lista y sus filtros.
  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final contexto = await _repository.contexto();
      final kits = await _repository.listarKits();
      final disponibilidad = await _repository.buscarMedicamentos();

      if (mounted) {
        setState(() {
          _todosLosKits = kits;
          _contexto = contexto;
          _areas = contexto.areas;
          _disponibilidad = {for (final m in disponibilidad) m.id: m};
          if (!_areas.any((a) => a.codigo == _filtroArea)) _filtroArea = null;
          // Solo una asignación permite preselección sin ambigüedad.
          if (contexto.rol == 'ENFERMERIA' &&
              _filtroArea == null &&
              _areas.length == 1) {
            _filtroArea = _areas.single.codigo;
          }
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = KitsRepository.mensajeError(e);
        });
      }
    }
  }

  /// Guarda disponibilidad con protección contra pulsaciones simultáneas.
  Future<void> _cambiarEstado(KitEntity kit, bool nuevoEstado) async {
    if (_operando || _cargando || !_puedeGestionar) return;
    setState(() => _operando = true);
    try {
      await _repository.cambiarEstado(kit.id, nuevoEstado);
      if (!mounted) return;
      MensajesApp.mostrar(
        context,
        nuevoEstado
            ? 'Kit habilitado.'
            : 'Kit inhabilitado; historial conservado.',
      );
      await _cargarDatos();
    } catch (error) {
      if (mounted) {
        MensajesApp.mostrar(
          context,
          KitsRepository.mensajeError(error),
          tipo: TipoMensaje.error,
        );
      }
    } finally {
      if (mounted) setState(() => _operando = false);
    }
  }

  /// El servidor decide si se puede eliminar; el resultado utiliza un aviso semántico.
  Future<void> _eliminarKit(KitEntity kit) async {
    if (_operando || _cargando || !_puedeGestionar) return;
    setState(() => _operando = true);
    try {
      await _repository.eliminarKit(kit.id);
      if (!mounted) return;
      MensajesApp.mostrar(context, 'Borrador de kit eliminado.');
      await _cargarDatos();
    } catch (error) {
      if (mounted) {
        MensajesApp.mostrar(
          context,
          KitsRepository.mensajeError(error),
          tipo: TipoMensaje.error,
        );
      }
    } finally {
      if (mounted) setState(() => _operando = false);
    }
  }

  /// Abre el formulario y actualiza la lista únicamente cuando se guardó un kit.
  void _abrirFormulario({KitEntity? kit, bool duplicar = false}) async {
    if (!_puedeGestionar || _operando || _cargando || _error != null) return;
    if (duplicar &&
        !_areas.any((area) => area.codigo == kit?.areaDestino && area.activo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Habilita primero el área original para crear una variante.',
          ),
        ),
      );
      return;
    }
    if (kit == null && _contexto?.rol == 'ENFERMERIA' && _filtroArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona tu área de trabajo.')),
      );
      return;
    }
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => KitFormularioView(
          repository: _repository,
          kitExistente: duplicar ? null : kit,
          duplicarDe: duplicar ? kit : null,
          areaInicial: _filtroArea,
          temaInicial: _temaDeArea(kit?.areaDestino ?? _filtroArea),
        ),
      ),
    );

    if (guardado == true && mounted) {
      _cargarDatos();
    }
  }

  /// Combina búsqueda, estado y área sobre los kits obtenidos de la base de datos.
  List<KitEntity> get _kitsFiltrados {
    if (_contexto?.rol == 'ENFERMERIA' && _filtroArea == null) return [];
    return _todosLosKits.where((kit) {
      // Filtro de texto
      if (_filtroTexto.isNotEmpty) {
        final q = _filtroTexto.toLowerCase();
        final matchNombre = kit.nombre.toLowerCase().contains(q);
        final matchDesc = (kit.descripcion ?? '').toLowerCase().contains(q);
        final matchArea =
            kit.areaNombre.toLowerCase().contains(q) ||
            kit.areaDestino.toLowerCase().contains(q);
        if (!matchNombre && !matchDesc && !matchArea) return false;
      }

      // Filtro de estado
      if (_filtroEstado == 'ACTIVOS' && !kit.activo) return false;
      if (_filtroEstado == 'INACTIVOS' && kit.activo) return false;

      // Filtro de área
      if (_filtroArea != null && kit.areaDestino != _filtroArea) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final kits = _kitsFiltrados;
    final tema = _temaDeArea(_filtroArea);
    final rojo = tema.principal;

    return Theme(
      data: CatalogoEstilo.tema(context, area: tema),
      child: Scaffold(
        backgroundColor: CatalogoEstilo.fondo,
        appBar: AppBar(
          backgroundColor: rojo,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            tooltip: 'Volver al menú',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              final rol = _contexto?.rol;
              context.go(
                rol == 'ENFERMERIA'
                    ? '/enfermeria'
                    : rol == 'JEFATURA_FARMACIA'
                    ? '/jefatura'
                    : rol == 'FARMACIA'
                    ? '/farmacia'
                    : '/admin',
              );
            },
          ),
          title: const Text(
            'Gestión de kits',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        floatingActionButton: !_puedeGestionar || _cargando || _error != null
            ? null
            : FloatingActionButton.extended(
                backgroundColor: rojo,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Nuevo Kit',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed:
                    _operando ||
                        !_areas.any((a) => a.activo) ||
                        (_contexto?.rol == 'ENFERMERIA' && _filtroArea == null)
                    ? null
                    : () => _abrirFormulario(),
              ),
        body: RefreshIndicator(
          color: rojo,
          onRefresh: _cargarDatos,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resumen breve: el contenido y las acciones quedan cerca del pulgar.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [rojo, Color.lerp(rojo, Colors.white, .08)!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: rojo.withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Kits por área',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Organiza medicamentos e insumos en plantillas para cada área. Consulta su composición antes de editar.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Buscador y filtros
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E2E2)),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchCtrl,
                            onChanged: (val) {
                              setState(() {
                                _filtroTexto = val.trim();
                              });
                            },
                            decoration: InputDecoration(
                              hintText:
                                  'Buscar por nombre, descripción o área...',
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: rojo,
                              ),
                              suffixIcon: _filtroTexto.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() {
                                          _filtroTexto = '';
                                        });
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: const Color(0xFFF9F9F9),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Filtros de estado y áreas
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                const Text(
                                  'Estado:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF616161),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Todos'),
                                  selected: _filtroEstado == null,
                                  onSelected: (_) {
                                    setState(() {
                                      _filtroEstado = null;
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                ChoiceChip(
                                  label: const Text('Activos'),
                                  selected: _filtroEstado == 'ACTIVOS',
                                  selectedColor: tema.suave,
                                  onSelected: (_) {
                                    setState(() {
                                      _filtroEstado = 'ACTIVOS';
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                ChoiceChip(
                                  label: const Text('Inactivos'),
                                  selected: _filtroEstado == 'INACTIVOS',
                                  selectedColor: tema.suave,
                                  onSelected: (_) {
                                    setState(() {
                                      _filtroEstado = 'INACTIVOS';
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                const Text(
                                  'Área:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF616161),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: Text(
                                    _contexto?.rol == 'ENFERMERIA'
                                        ? 'Seleccionar área'
                                        : 'Todas',
                                  ),
                                  selected: _filtroArea == null,
                                  onSelected: (_) {
                                    setState(() {
                                      _filtroArea = null;
                                    });
                                  },
                                ),
                                ..._areas.map((area) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: ChoiceChip(
                                      label: Text(
                                        '${area.nombre}${area.activo ? '' : ' (deshabilitada)'}',
                                      ),
                                      selected: _filtroArea == area.codigo,
                                      onSelected: (_) {
                                        setState(() {
                                          _filtroArea =
                                              _contexto?.rol == 'ENFERMERIA'
                                              ? area.codigo
                                              : _filtroArea == area.codigo
                                              ? null
                                              : area.codigo;
                                        });
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Contenido de la lista
                    if (_cargando) ...[
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ] else if (_error != null) ...[
                      MensajesApp.nota(_error!, tipo: TipoMensaje.error),
                      const SizedBox(height: 12),
                      Center(
                        child: FilledButton.icon(
                          onPressed: _cargarDatos,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar conexión'),
                        ),
                      ),
                    ] else if (kits.isEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(36),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.medical_services_outlined,
                              size: 48,
                              color: Color(0xFFBDBDBD),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Selecciona un área o ajusta los filtros para consultar sus kits.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF616161),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'La consulta conserva las plantillas deshabilitadas y sus componentes.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9E9E9E),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            if (_puedeGestionar && _areas.any((a) => a.activo))
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: rojo,
                                ),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Crear Primer Kit'),
                                onPressed: () => _abrirFormulario(),
                              ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        '${kits.length} kits registrados',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF616161),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: kits.length,
                        itemBuilder: (context, index) {
                          final kit = kits[index];
                          return KitCard(
                            key: ValueKey(kit.id),
                            kit: kit,
                            tema: _temaDeArea(kit.areaDestino),
                            puedeGestionar: _puedeGestionar,
                            bloqueada: _operando || _cargando,
                            disponibilidad: _disponibilidad,
                            onDuplicar: () =>
                                _abrirFormulario(kit: kit, duplicar: true),
                            onEditar: () => _abrirFormulario(kit: kit),
                            onCambiarEstado: (nuevoEstado) =>
                                _cambiarEstado(kit, nuevoEstado),
                            onEliminar: () => _eliminarKit(kit),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 80), // espacio para FAB
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

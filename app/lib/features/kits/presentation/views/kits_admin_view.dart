import 'package:flutter/material.dart';
import '../../../../core/widgets/sitra_app_bar.dart';
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
  static const rojo = Color(0xFFC62828);

  final KitsRepository _repository = KitsRepository();
  final TextEditingController _searchCtrl = TextEditingController();

  List<KitEntity> _todosLosKits = [];
  List<AreaKit> _areas = [];
  bool _cargando = true;
  String? _error;

  // Filtros
  String _filtroTexto = '';
  String? _filtroEstado; // null: Todos, 'ACTIVOS', 'INACTIVOS'
  String? _filtroArea; // null: Todas las áreas

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

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final kits = await _repository.listarKits();
      final areas = await _repository.cargarAreasActivas();

      if (mounted) {
        setState(() {
          _todosLosKits = kits;
          _areas = areas;
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

  Future<void> _cambiarEstado(KitEntity kit, bool nuevoEstado) async {
    try {
      await _repository.cambiarEstado(kit.id, nuevoEstado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: nuevoEstado ? Colors.teal.shade800 : Colors.orange.shade900,
            content: Row(
              children: [
                Icon(
                  nuevoEstado ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  nuevoEstado
                      ? 'Kit "${kit.nombre}" habilitado para nuevas dispensaciones.'
                      : 'Kit "${kit.nombre}" inhabilitado (historial preservado).',
                ),
              ],
            ),
          ),
        );
        _cargarDatos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text(KitsRepository.mensajeError(e)),
          ),
        );
      }
    }
  }

  Future<void> _eliminarKit(KitEntity kit) async {
    try {
      await _repository.eliminarKit(kit.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.teal,
            content: Text('Borrador de kit eliminado correctamente.'),
          ),
        );
        _cargarDatos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text(KitsRepository.mensajeError(e)),
          ),
        );
      }
    }
  }

  void _abrirFormulario({KitEntity? kit}) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => KitFormularioView(
          repository: _repository,
          kitExistente: kit,
        ),
      ),
    );

    if (guardado == true && mounted) {
      _cargarDatos();
    }
  }

  List<KitEntity> get _kitsFiltrados {
    return _todosLosKits.where((kit) {
      // Filtro de texto
      if (_filtroTexto.isNotEmpty) {
        final q = _filtroTexto.toLowerCase();
        final matchNombre = kit.nombre.toLowerCase().contains(q);
        final matchDesc = (kit.descripcion ?? '').toLowerCase().contains(q);
        final matchArea = kit.areaNombre.toLowerCase().contains(q) ||
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

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: const SitraAppBar(
        title: 'Plantillas de Kits Quirúrgicos y Clínicos',
        subtitle: 'Administración de kits prearmados (HU-017, HU-018, HU-019)',
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: rojo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo Kit', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _abrirFormulario(),
      ),
      body: RefreshIndicator(
        color: rojo,
        onRefresh: _cargarDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner explicativo de Semana 2
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [rojo, Color(0xFFE53935)],
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
                            Icon(Icons.inventory_2_rounded, color: Colors.white, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Gestión de Kits y Plantillas Prearmadas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Permite estandarizar los sets de insumos y medicamentos para Quirófano (SOP), '
                          'Coche de Paros y Emergencia. La edición preserva íntegramente las fichas y consumos pasados.',
                          style: TextStyle(fontSize: 13, height: 1.4, color: Colors.white),
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
                            hintText: 'Buscar por nombre, descripción o área...',
                            prefixIcon: const Icon(Icons.search_rounded, color: rojo),
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF616161)),
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
                                selectedColor: const Color(0xFFE8F5E9),
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
                                selectedColor: const Color(0xFFFFEBEE),
                                onSelected: (_) {
                                  setState(() {
                                    _filtroEstado = 'INACTIVOS';
                                  });
                                },
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Área:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF616161)),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('Todas'),
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
                                    label: Text(area.nombre),
                                    selected: _filtroArea == area.codigo,
                                    onSelected: (_) {
                                      setState(() {
                                        _filtroArea = _filtroArea == area.codigo ? null : area.codigo;
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
                      child: Center(child: CircularProgressIndicator(color: rojo)),
                    ),
                  ] else if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 36, color: Colors.red),
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: rojo, foregroundColor: Colors.white),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar conexión'),
                            onPressed: _cargarDatos,
                          ),
                        ],
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
                          const Icon(Icons.medical_services_outlined, size: 48, color: Color(0xFFBDBDBD)),
                          const SizedBox(height: 12),
                          const Text(
                            'No se encontraron kits con los filtros seleccionados',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF616161)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Prueba cambiando el término de búsqueda o crea una nueva plantilla con el botón (+).',
                            style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: rojo),
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF616161)),
                    ),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: kits.length,
                      itemBuilder: (context, index) {
                        final kit = kits[index];
                        return KitCard(
                          kit: kit,
                          onEditar: () => _abrirFormulario(kit: kit),
                          onCambiarEstado: (nuevoEstado) => _cambiarEstado(kit, nuevoEstado),
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
    );
  }
}

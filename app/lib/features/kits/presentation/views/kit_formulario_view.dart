import 'package:flutter/material.dart';
import '../../data/repositories/kits_repository.dart';
import '../../domain/entities/kit_entity.dart';
import '../../domain/entities/kit_item_entity.dart';
import '../../domain/kit_borrador.dart';
import '../../domain/kit_validadores.dart';
import '../widgets/selector_medicamento_dialog.dart';

class KitFormularioView extends StatefulWidget {
  final KitEntity? kitExistente;
  final KitsRepository repository;

  const KitFormularioView({
    super.key,
    this.kitExistente,
    required this.repository,
  });

  @override
  State<KitFormularioView> createState() => _KitFormularioViewState();
}

class _KitFormularioViewState extends State<KitFormularioView> {
  static const rojo = Color(0xFFC62828);
  static const pastel = Color(0xFFFFF0F0);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;

  String? _areaSeleccionada;
  List<AreaKit> _areas = [];
  bool _cargandoAreas = true;

  List<KitItemEntity> _items = [];
  bool _guardando = false;
  String? _errorMensaje;

  bool get _esEdicion => widget.kitExistente != null;

  @override
  void initState() {
    super.initState();
    final kit = widget.kitExistente;
    _nombreCtrl = TextEditingController(text: kit?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: kit?.descripcion ?? '');
    _areaSeleccionada = kit?.areaDestino;
    _items = kit != null ? List<KitItemEntity>.from(kit.items) : [];

    _cargarAreas();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarAreas() async {
    try {
      final areas = await widget.repository.cargarAreasActivas();
      if (mounted) {
        setState(() {
          _areas = areas;
          _cargandoAreas = false;
          // Si el área seleccionada no está o está vacía, preseleccionar la primera
          if (_areaSeleccionada == null || _areaSeleccionada!.isEmpty) {
            if (_areas.isNotEmpty) {
              _areaSeleccionada = _areas.first.codigo;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargandoAreas = false;
          _errorMensaje = 'No se pudieron cargar las áreas: ${KitsRepository.mensajeError(e)}';
        });
      }
    }
  }

  Future<void> _abrirSelectorMedicamento() async {
    final idsActuales = _items.map((i) => i.medicamentoId).toSet();
    final itemSeleccionado = await showDialog<KitItemEntity>(
      context: context,
      builder: (ctx) => SelectorMedicamentoDialog(
        repository: widget.repository,
        idsYaSeleccionados: idsActuales,
      ),
    );

    if (itemSeleccionado != null && mounted) {
      setState(() {
        final borrador = KitBorrador(items: _items).agregarOActualizarItem(itemSeleccionado);
        _items = borrador.items;
        _errorMensaje = null;
      });
    }
  }

  void _cambiarCantidad(String medId, int nuevaCantidad) {
    setState(() {
      final borrador = KitBorrador(items: _items).cambiarCantidad(medId, nuevaCantidad);
      _items = borrador.items;
    });
  }

  void _eliminarItem(String medId) {
    setState(() {
      final borrador = KitBorrador(items: _items).eliminarItem(medId);
      _items = borrador.items;
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final borrador = KitBorrador(
      nombre: _nombreCtrl.text,
      descripcion: _descripcionCtrl.text,
      areaDestino: _areaSeleccionada ?? '',
      items: _items,
    );

    final errorValidacion = KitValidadores.validarBorradorCompleto(borrador);
    if (errorValidacion != null) {
      setState(() {
        _errorMensaje = errorValidacion;
      });
      return;
    }

    setState(() {
      _guardando = true;
      _errorMensaje = null;
    });

    try {
      await widget.repository.guardarKit(
        borrador,
        id: widget.kitExistente?.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal.shade800,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  _esEdicion
                      ? 'Plantilla de kit actualizada con éxito.'
                      : 'Nuevo kit registrado exitosamente.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _errorMensaje = KitsRepository.mensajeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: rojo,
        foregroundColor: Colors.white,
        title: Text(
          _esEdicion ? 'Editar Plantilla de Kit' : 'Crear Nuevo Kit Clínico',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner explicativo según HU-018 / HU-019
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: pastel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: rojo, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _esEdicion
                                ? 'Regla HU-019: La edición actualiza la plantilla para futuros pedidos y dispensaciones. Todas las fichas y consumos generados anteriormente conservan sus ítems y cantidades históricas.'
                                : 'HU-018: Registra un nuevo kit estandarizado (ej: Quirófano SOP, Coche de Paros, Emergencia) con insumos y cantidades predeterminadas.',
                            style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF333333)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_errorMensaje != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMensaje!,
                              style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Sección 1: Datos Generales
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.badge_rounded, color: rojo, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Información del Kit',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nombreCtrl,
                          validator: KitValidadores.validarNombre,
                          decoration: InputDecoration(
                            labelText: 'Nombre del Kit *',
                            hintText: 'Ej: Kit Cirugía General Estándar',
                            filled: true,
                            fillColor: const Color(0xFFFAFAFA),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.title_rounded, color: rojo),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _cargandoAreas
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(child: CircularProgressIndicator(color: rojo)),
                              )
                            : DropdownButtonFormField<String>(
                                value: _areaSeleccionada,
                                decoration: InputDecoration(
                                  labelText: 'Área de Destino *',
                                  filled: true,
                                  fillColor: const Color(0xFFFAFAFA),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  prefixIcon: const Icon(Icons.local_hospital_rounded, color: rojo),
                                ),
                                validator: KitValidadores.validarArea,
                                items: _areas.map((area) {
                                  return DropdownMenuItem<String>(
                                    value: area.codigo,
                                    child: Text('${area.nombre} (${area.codigoInterno})'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _areaSeleccionada = val;
                                  });
                                },
                              ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descripcionCtrl,
                          maxLines: 2,
                          validator: KitValidadores.validarDescripcion,
                          decoration: InputDecoration(
                            labelText: 'Descripción / Propósito Clínico (Opcional)',
                            hintText: 'Insumos y anestésicos para intervenciones quirúrgicas...',
                            filled: true,
                            fillColor: const Color(0xFFFAFAFA),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.notes_rounded, color: rojo),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sección 2: Composición del Kit (Ítems)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.medication_liquid_rounded, color: rojo, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Insumos y Medicamentos Incluidos',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_items.length} ítems',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: rojo,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Agrega los medicamentos predeterminados con sus cantidades de salida estándar.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
                        ),
                        const SizedBox(height: 16),

                        if (_items.isEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE0E0E0), style: BorderStyle.solid),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFFBDBDBD)),
                                const SizedBox(height: 10),
                                const Text(
                                  'Aún no has agregado medicamentos al kit',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF616161)),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Presiona el botón inferior para buscar en el catálogo maestro.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                                ),
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: rojo,
                                    side: const BorderSide(color: rojo),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Agregar Primer Insumo'),
                                  onPressed: _abrirSelectorMedicamento,
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: const Color(0xFFFFF0F0),
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: rojo),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.medicamentoNombre,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                          if (item.presentacion != null && item.presentacion!.isNotEmpty) ...[
                                            Text(
                                              item.presentacion!,
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF757575)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Stepper cantidad
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline_rounded, color: rojo, size: 20),
                                      onPressed: item.cantidad > 1
                                          ? () => _cambiarCantidad(item.medicamentoId, item.cantidad - 1)
                                          : null,
                                    ),
                                    Container(
                                      constraints: const BoxConstraints(minWidth: 36),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F5F5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${item.cantidad}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline_rounded, color: rojo, size: 20),
                                      onPressed: () => _cambiarCantidad(item.medicamentoId, item.cantidad + 1),
                                    ),
                                    IconButton(
                                      tooltip: 'Quitar del kit',
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF9E9E9E), size: 20),
                                      onPressed: () => _eliminarItem(item.medicamentoId),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(foregroundColor: rojo),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Agregar otro insumo'),
                              onPressed: _abrirSelectorMedicamento,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(120, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar', style: TextStyle(color: Color(0xFF616161))),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: rojo,
                          minimumSize: const Size(180, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded, size: 20),
                        label: Text(
                          _guardando
                              ? 'Guardando...'
                              : _esEdicion
                                  ? 'Actualizar Kit'
                                  : 'Guardar Kit',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _guardando ? null : _guardar,
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
  }
}

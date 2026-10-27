import 'package:flutter/material.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/theme/tema_area.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../../administracion/presentation/widgets/catalogo_estilo.dart';
import '../../data/repositories/kits_repository.dart';
import '../../domain/entities/kit_entity.dart';
import '../../domain/entities/kit_item_entity.dart';
import '../../domain/kit_borrador.dart';
import '../../domain/kit_validadores.dart';
import '../widgets/selector_medicamento_dialog.dart';
import '../widgets/disponibilidad_kit.dart';
import '../widgets/laboratorio_medicamento.dart';

class KitFormularioView extends StatefulWidget {
  final KitEntity? kitExistente;
  final KitsRepository repository;
  final KitEntity? duplicarDe;
  final String? areaInicial;
  final TemaArea temaInicial;

  const KitFormularioView({
    super.key,
    this.kitExistente,
    required this.repository,
    this.duplicarDe,
    this.areaInicial,
    this.temaInicial = const TemaArea(
      'ROJO',
      'Rojo institucional',
      Color(0xFFC62828),
      Color(0xFFFFF0F0),
    ),
  });

  @override
  State<KitFormularioView> createState() => _KitFormularioViewState();
}

class _KitFormularioViewState extends State<KitFormularioView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;

  String? _areaSeleccionada;
  List<AreaKit> _areas = [];
  bool _cargandoAreas = true;
  bool _autorizado = false;
  Map<String, MedicamentoKit> _disponibilidad = {};

  List<KitItemEntity> _items = [];
  bool _guardando = false;
  String? _errorMensaje;

  bool get _esEdicion => widget.kitExistente != null;

  /// Cambia la identidad del formulario cuando se elige otra área autorizada.
  TemaArea get _temaActual {
    for (final area in _areas) {
      if (area.codigo == _areaSeleccionada) {
        return TemaArea.desde(area.temaColor);
      }
    }
    return widget.temaInicial;
  }

  @override
  void initState() {
    super.initState();
    final kit = widget.kitExistente ?? widget.duplicarDe;
    // La variante pide otro nombre y se guarda con identidad propia.
    _nombreCtrl = TextEditingController(
      text: widget.duplicarDe != null ? '' : kit?.nombre ?? '',
    );
    _descripcionCtrl = TextEditingController(text: kit?.descripcion ?? '');
    _areaSeleccionada = kit?.areaDestino ?? widget.areaInicial;
    _items = kit != null ? List<KitItemEntity>.from(kit.items) : [];

    _cargarAreas();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  /// Consulta las áreas habilitadas para asignar la plantilla a un destino válido.
  Future<void> _cargarAreas() async {
    try {
      final contexto = await widget.repository.contexto();
      if (!contexto.puedeGestionar) {
        throw StateError('No tienes permisos para gestionar kits.');
      }
      final areas = contexto.areas
          .where(
            (a) => a.activo || a.codigo == widget.kitExistente?.areaDestino,
          )
          .toList();
      final disponibilidad = await widget.repository.buscarMedicamentos();
      if (mounted) {
        setState(() {
          // El selector necesita un único elemento por código operativo.
          _areas = {
            for (final area in areas)
              if (area.codigo.trim().isNotEmpty) area.codigo: area,
          }.values.toList();
          _cargandoAreas = false;
          _autorizado = true;
          _disponibilidad = {for (final m in disponibilidad) m.id: m};
          // No sustituir silenciosamente el destino histórico por otra área.
          if (_areaSeleccionada != null &&
              !_areas.any((area) => area.codigo == _areaSeleccionada)) {
            _areaSeleccionada = null;
            _errorMensaje =
                'El área original del kit (${widget.kitExistente?.areaNombre ?? ''}) '
                'no está disponible para tu perfil. '
                'Selecciona un área habilitada y autorizada para guardar los cambios. '
                'El kit original todavía no se ha modificado.';
          } else if (_areas.isEmpty) {
            _errorMensaje =
                'No hay áreas habilitadas disponibles. Habilita un área en '
                'Gestión administrativa antes de guardar el kit.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargandoAreas = false;
          _errorMensaje =
              'No se pudieron cargar las áreas: ${KitsRepository.mensajeError(e)}';
        });
      }
    }
  }

  /// Abre la búsqueda del catálogo y agrega el medicamento elegido al borrador.
  Future<void> _abrirSelectorMedicamento() async {
    final idsActuales = _items.map((i) => i.medicamentoId).toSet();
    final itemSeleccionado = await showDialog<KitItemEntity>(
      context: context,
      builder: (ctx) => SelectorMedicamentoDialog(
        tema: _temaActual,
        repository: widget.repository,
        idsYaSeleccionados: idsActuales,
      ),
    );

    if (itemSeleccionado != null && mounted) {
      setState(() {
        final borrador = KitBorrador(
          items: _items,
        ).agregarOActualizarItem(itemSeleccionado);
        _items = borrador.items;
        _errorMensaje = null;
      });
    }
  }

  /// Actualiza la cantidad del borrador sin escribir todavía en la base de datos.
  void _cambiarCantidad(String medId, int nuevaCantidad) {
    setState(() {
      final borrador = KitBorrador(
        items: _items,
      ).cambiarCantidad(medId, nuevaCantidad);
      _items = borrador.items;
    });
  }

  /// Retira un ítem de la composición que se guardará al confirmar el formulario.
  void _eliminarItem(String medId) {
    setState(() {
      final borrador = KitBorrador(items: _items).eliminarItem(medId);
      _items = borrador.items;
    });
  }

  /// Valida los datos y solicita al repositorio guardar cabecera e ítems juntos.
  Future<void> _guardar() async {
    if (_guardando || _cargandoAreas || !_autorizado) return;
    if (!_areas.any((area) => area.codigo == _areaSeleccionada)) {
      setState(() {
        _errorMensaje =
            'Selecciona un área habilitada antes de guardar el kit.';
      });
      return;
    }
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
        origenId: widget.duplicarDe?.id,
      );

      if (mounted) {
        MensajesApp.mostrar(
          context,
          _esEdicion
              ? 'Kit actualizado correctamente.'
              : 'Kit guardado correctamente.',
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
    final rojo = _temaActual.principal;
    final pastel = _temaActual.suave;
    return Theme(
      data: CatalogoEstilo.tema(context, area: _temaActual),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7F9),
        appBar: AppBar(
          toolbarHeight: DisenoAdaptable.altoCabecera(
            context,
            base: kToolbarHeight,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: rojo,
          foregroundColor: Colors.white,
          title: Text(
            _esEdicion
                ? 'Editar kit'
                : widget.duplicarDe != null
                ? 'Duplicar kit'
                : 'Nuevo kit',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(
          child: ContenidoAdaptable(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // La explicación utiliza el color informativo, no el tema del área.
                    MensajesApp.nota(
                      _esEdicion
                          ? 'Los cambios se aplican a futuros pedidos. Las fichas anteriores conservan sus medicamentos y cantidades.'
                          : widget.duplicarDe != null
                          ? 'Copia de «${widget.duplicarDe!.nombre}». Escribe otro nombre y ajusta su composición. El original se conserva.'
                          : 'Crea un kit personalizado: elige el área, los medicamentos y las cantidades.',
                    ),
                    const SizedBox(height: 16),

                    if (_errorMensaje != null) ...[
                      MensajesApp.nota(_errorMensaje!, tipo: TipoMensaje.error),
                      const SizedBox(height: 16),
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
                          Row(
                            children: [
                              Icon(Icons.badge_rounded, color: rojo, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Información del Kit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(
                                Icons.title_rounded,
                                color: rojo,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _cargandoAreas
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : DropdownButtonFormField<String>(
                                  itemHeight: null,
                                  isDense: false,
                                  isExpanded: true,
                                  // También evita el valor histórico inválido si
                                  // falla la carga o durante una reconstrucción.
                                  value:
                                      _areas.any(
                                        (area) =>
                                            area.codigo == _areaSeleccionada,
                                      )
                                      ? _areaSeleccionada
                                      : null,
                                  hint: const Text('Selecciona un área'),
                                  decoration: InputDecoration(
                                    labelText: 'Área de Destino *',
                                    filled: true,
                                    fillColor: const Color(0xFFFAFAFA),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.local_hospital_rounded,
                                      color: rojo,
                                    ),
                                  ),
                                  validator: KitValidadores.validarArea,
                                  items: _areas.map((area) {
                                    return DropdownMenuItem<String>(
                                      value: area.codigo,
                                      child: Text(
                                        '${area.nombre} (${area.codigoInterno})${area.activo ? '' : ' · Deshabilitada (histórica)'}',
                                      ),
                                    );
                                  }).toList(),
                                  onChanged:
                                      _guardando || widget.duplicarDe != null
                                      ? null
                                      : (val) {
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
                              labelText:
                                  'Descripción / Propósito Clínico (Opcional)',
                              hintText:
                                  'Insumos y anestésicos para intervenciones quirúrgicas...',
                              filled: true,
                              fillColor: const Color(0xFFFAFAFA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(
                                Icons.notes_rounded,
                                color: rojo,
                              ),
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
                              Icon(
                                Icons.medication_liquid_rounded,
                                color: rojo,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Composición del kit',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: pastel,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_items.length} ítems',
                                  style: TextStyle(
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF757575),
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (_items.isEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 40,
                                    color: Color(0xFFBDBDBD),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Aún no has agregado medicamentos al kit',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF616161),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Presiona el botón inferior para buscar en el catálogo maestro.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9E9E9E),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: rojo,
                                      side: BorderSide(color: rojo),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
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
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: Color(0xFFEEEEEE),
                              ),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: pastel,
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: rojo,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.medicamentoNombre,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (item.presentacion != null &&
                                                    item
                                                        .presentacion!
                                                        .isNotEmpty) ...[
                                                  Text(
                                                    item.presentacion!,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF757575),
                                                    ),
                                                  ),
                                                ],
                                                LaboratorioMedicamento(
                                                  laboratorio: item.laboratorio,
                                                  referencia:
                                                      _disponibilidad[item
                                                              .medicamentoId]
                                                          ?.laboratorio,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      DisponibilidadKit(
                                        medicamento:
                                            _disponibilidad[item.medicamentoId],
                                        cantidad: item.cantidad,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          // Cantidad en otra fila para dar espacio al nombre completo.
                                          IconButton(
                                            tooltip: 'Disminuir cantidad',
                                            icon: Icon(
                                              Icons
                                                  .remove_circle_outline_rounded,
                                              color: rojo,
                                              size: 20,
                                            ),
                                            onPressed: item.cantidad > 1
                                                ? () => _cambiarCantidad(
                                                    item.medicamentoId,
                                                    item.cantidad - 1,
                                                  )
                                                : null,
                                          ),
                                          Expanded(
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minWidth: 36,
                                              ),
                                              alignment: Alignment.center,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF5F5F5),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${item.cantidad}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Aumentar cantidad',
                                            icon: Icon(
                                              Icons.add_circle_outline_rounded,
                                              color: rojo,
                                              size: 20,
                                            ),
                                            onPressed: () => _cambiarCantidad(
                                              item.medicamentoId,
                                              item.cantidad + 1,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Quitar del kit',
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Color(0xFF9E9E9E),
                                              size: 20,
                                            ),
                                            onPressed: () => _eliminarItem(
                                              item.medicamentoId,
                                            ),
                                          ),
                                        ],
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
                                style: TextButton.styleFrom(
                                  foregroundColor: rojo,
                                ),
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
                    AccionesAdaptables(
                      acciones: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _guardando
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(color: Color(0xFF616161)),
                          ),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: rojo,
                            minimumSize: const Size(0, 48),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _guardando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
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
                          onPressed:
                              _guardando || _cargandoAreas || !_autorizado
                              ? null
                              : _guardar,
                        ),
                      ],
                    ),
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

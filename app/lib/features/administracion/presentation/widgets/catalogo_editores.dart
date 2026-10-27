import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../data/catalogos_repository.dart';
import 'catalogo_estilo.dart';
import 'selector_tema_area.dart';

class AreaEditor extends StatefulWidget {
  final AreaCatalogo? area;
  final CatalogosRepository repository;

  /// Abre el formulario de un área nueva o existente con el repositorio de guardado.
  const AreaEditor({super.key, this.area, required this.repository});

  /// Crea el estado que administra campos, validación y progreso del formulario.
  @override
  State<AreaEditor> createState() => _AreaEditorState();
}

class _AreaEditorState extends State<AreaEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _codigo, _nombre, _descripcion;
  late bool _stock;
  late String _temaColor;
  bool _guardando = false;
  String? _error;

  /// Precarga los campos del área al editar; al crear deja el código opcional vacío.
  @override
  void initState() {
    super.initState();
    _codigo = TextEditingController(text: widget.area?.codigo ?? '');
    _nombre = TextEditingController(text: widget.area?.nombre ?? '');
    _descripcion = TextEditingController(text: widget.area?.descripcion ?? '');
    _stock = widget.area?.administraStock ?? false;
    _temaColor = widget.area?.temaColor ?? 'ROJO';
  }

  /// Libera los controladores de texto cuando se cierra el formulario.
  @override
  void dispose() {
    _codigo.dispose();
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  /// Valida el formulario y evita envíos duplicados mientras se guarda.
  /// Envía nombre, descripción, código visible y stock propio a la RPC mediante
  /// el repositorio; cierra con true solo después de un guardado satisfactorio.
  Future<void> _guardar() async {
    if (!_form.currentState!.validate() || _guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repository.guardar('AREA', {
        'codigo_interno': _codigo.text.trim().toUpperCase(),
        'nombre': _nombre.text.trim(),
        'descripcion': _descripcion.text.trim(),
        'administra_stock': _stock,
        'tema_color': _temaColor,
      }, id: widget.area?.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = CatalogosRepository.mensajeError(e);
          _guardando = false;
        });
      }
    }
  }

  /// Dibuja los campos del área y las indicaciones de habilitación.
  /// Los valores se editan localmente hasta pulsar Guardar; no consulta Supabase.
  @override
  Widget build(BuildContext context) => CatalogoDialogo(
    titulo: widget.area == null ? 'Nueva área' : 'Editar área',
    icono: Icons.apartment_rounded,
    guardando: _guardando,
    guardar: _guardar,
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CatalogoEstilo.nota(
            'Registra el nombre corto, por ejemplo SOP, y su descripción: Sala de Operaciones.',
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _codigo,
            enabled: !_guardando,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Código interno',
              hintText: 'AREA-001',
              helperText: widget.area == null
                  ? 'Opcional al crear: se genera automáticamente.'
                  : 'Es editable y debe ser único.',
            ),
            validator: (v) => (v ?? '').trim().isEmpty && widget.area == null
                ? null
                : RegExp(
                    r'^AREA-[0-9]{3,}$',
                  ).hasMatch((v ?? '').trim().toUpperCase())
                ? null
                : 'Usa un código como AREA-001.',
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _nombre,
            enabled: !_guardando,
            maxLength: 100,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nombre del área *',
              hintText: 'SOP',
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Escribe el nombre del área.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descripcion,
            enabled: !_guardando,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              hintText: 'Sala de Operaciones',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Administra stock propio',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Para áreas que conservan insumos de curación o un botiquín.',
              style: TextStyle(fontSize: 12),
            ),
            activeTrackColor: CatalogoEstilo.rojo,
            value: _stock,
            onChanged: _guardando ? null : (v) => setState(() => _stock = v),
          ),
          const SizedBox(height: 20),
          SelectorTemaArea(
            valor: _temaColor,
            nombreArea: _nombre.text,
            onChanged: _guardando
                ? null
                : (valor) => setState(() => _temaColor = valor),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 12),
          CatalogoEstilo.nota(
            'Deshabilitar conserva los registros anteriores y evita nuevas selecciones o asignaciones. Los pedidos existentes pueden finalizar.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            CatalogoEstilo.nota(_error!, icono: Icons.error_outline_rounded),
          ],
        ],
      ),
    ),
  );
}

class FinanciamientoEditor extends StatefulWidget {
  final FinanciamientoCatalogo? registro;
  final List<MedicamentoCobertura> medicamentos;
  final CatalogosRepository repository;

  /// Recibe el registro a editar y el catálogo ya cargado para seleccionar cobertura.
  const FinanciamientoEditor({
    super.key,
    this.registro,
    required this.medicamentos,
    required this.repository,
  });

  /// Crea el estado que conserva la cobertura seleccionada y los campos del convenio/seguro.
  @override
  State<FinanciamientoEditor> createState() => _FinanciamientoEditorState();
}

class _FinanciamientoEditorState extends State<FinanciamientoEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nombre, _descripcion, _porcentaje;
  late String _tipo;
  late Set<String> _seleccionados;
  String _busqueda = '';
  String? _error;
  int _limite = 30;
  bool _soloSeleccionados = false, _guardando = false;

  /// Interpreta el porcentaje escrito, admitiendo coma o punto como separador decimal.
  /// Devuelve null si todavía no es un número válido; el formulario valida su rango.
  double? get _descuento =>
      double.tryParse(_porcentaje.text.replaceAll(',', '.'));

  /// Precarga nombre, tipo, descripción, porcentaje y cobertura en una copia editable.
  @override
  void initState() {
    super.initState();
    final f = widget.registro;
    _nombre = TextEditingController(text: f?.nombre ?? '');
    _descripcion = TextEditingController(text: f?.descripcion ?? '');
    _porcentaje = TextEditingController(
      text: f?.porcentaje.toStringAsFixed(2) ?? '0',
    );
    _tipo = f?.tipo ?? 'SEGURO';
    _seleccionados = {...?f?.medicamentos};
  }

  /// Libera los controladores de los datos generales y del porcentaje.
  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _porcentaje.dispose();
    super.dispose();
  }

  /// Valida y envía el porcentaje junto con todos los IDs seleccionados.
  /// La RPC guarda datos y cobertura en una transacción; el cálculo visible es
  /// una vista previa y esta función no cobra ni modifica fichas históricas.
  Future<void> _guardar() async {
    if (!_form.currentState!.validate() || _guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repository.guardar('FINANCIAMIENTO', {
        'nombre': _nombre.text.trim(),
        'descripcion': _descripcion.text.trim(),
        'tipo': _tipo,
        'porcentaje_descuento': _descuento,
        'medicamentos': _seleccionados.toList()..sort(),
      }, id: widget.registro?.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = CatalogosRepository.mensajeError(e);
          _guardando = false;
        });
      }
    }
  }

  /// Construye el editor de seguro/convenio y filtra localmente los medicamentos.
  /// Muestra resultados por bloques de 30 sin perder la selección al buscar,
  /// y calcula la vista previa del descuento a partir del Kairos disponible.
  @override
  Widget build(BuildContext context) {
    final coincidencias = widget.medicamentos
        .where(
          (m) =>
              (m.activo || _seleccionados.contains(m.id)) &&
              (!_soloSeleccionados || _seleccionados.contains(m.id)) &&
              '${m.nombre} ${m.presentacion}'.toLowerCase().contains(_busqueda),
        )
        .toList();
    final visibles = coincidencias.take(_limite).toList();
    final descuento = _descuento;
    return CatalogoDialogo(
      titulo: widget.registro == null
          ? 'Nuevo seguro o convenio'
          : 'Editar seguro o convenio',
      icono: Icons.handshake_rounded,
      guardando: _guardando,
      guardar: _guardar,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Datos generales',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _tipo,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo *'),
              items: const [
                DropdownMenuItem(value: 'SEGURO', child: Text('Seguro')),
                DropdownMenuItem(value: 'CONVENIO', child: Text('Convenio')),
              ],
              onChanged: _guardando
                  ? null
                  : (v) {
                      if (v != null) setState(() => _tipo = v);
                    },
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nombre,
              enabled: !_guardando,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Nombre *',
                hintText: _tipo == 'SEGURO'
                    ? 'Nombre del seguro'
                    : 'Nombre del convenio',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Escribe un nombre.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcion,
              enabled: !_guardando,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Información del acuerdo o cobertura',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _porcentaje,
              enabled: !_guardando,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (anterior, nuevo) =>
                      RegExp(r'^\d{0,3}([.,]\d{0,2})?$').hasMatch(nuevo.text)
                      ? nuevo
                      : anterior,
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Descuento sobre Kairos *',
                suffixText: '%',
                helperText:
                    'Entre 0 y 100. Se aplica solo a los medicamentos seleccionados.',
              ),
              validator: (_) =>
                  descuento == null || descuento < 0 || descuento > 100
                  ? 'Ingresa un porcentaje entre 0 y 100.'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            CatalogoEstilo.nota(
              descuento != null && descuento >= 0 && descuento <= 100
                  ? 'Ejemplo con Kairos S/ 100.00: precio con descuento S/ ${(100 * (1 - descuento / 100)).toStringAsFixed(2)}. Los no incluidos mantienen Kairos sin descuento.'
                  : 'El descuento corresponde únicamente a los medicamentos incluidos.',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Medicamentos incluidos',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Chip(
                  label: Text(
                    '${_seleccionados.length} seleccionados',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: CatalogoEstilo.pastel,
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              enabled: !_guardando,
              decoration: const InputDecoration(
                hintText: 'Buscar medicamento o presentación',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() {
                _busqueda = v.trim().toLowerCase();
                _limite = 30;
              }),
            ),
            const SizedBox(height: 8),
            FilterChip(
              label: const Text('Solo seleccionados'),
              selected: _soloSeleccionados,
              selectedColor: CatalogoEstilo.pastel,
              checkmarkColor: CatalogoEstilo.rojo,
              onSelected: _guardando
                  ? null
                  : (v) => setState(() {
                      _soloSeleccionados = v;
                      _limite = 30;
                    }),
            ),
            const SizedBox(height: 8),
            if (coincidencias.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  widget.medicamentos.isEmpty
                      ? 'No hay medicamentos registrados. Puedes guardar y definir la cobertura después.'
                      : 'No hay medicamentos para este filtro.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ...visibles.map((m) {
              final incluido = _seleccionados.contains(m.id);
              final precio = m.kairos;
              final total =
                  precio != null &&
                      descuento != null &&
                      descuento >= 0 &&
                      descuento <= 100
                  ? precio * (1 - descuento / 100)
                  : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: incluido
                      ? CatalogoEstilo.pastel
                      : const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: CheckboxListTile(
                    value: incluido,
                    activeColor: CatalogoEstilo.rojo,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    title: Text(
                      m.nombre,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${m.presentacion}${m.activo ? '' : ' · Inactivo'}\n'
                      '${precio == null ? 'Kairos sin registrar' : 'Kairos S/ ${precio.toStringAsFixed(2)}'}'
                      '${incluido && total != null ? ' · Con descuento S/ ${total.toStringAsFixed(2)}' : ''}',
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                    onChanged: _guardando || (!m.activo && !incluido)
                        ? null
                        : (v) => setState(() {
                            if (v == true) {
                              _seleccionados.add(m.id);
                            } else {
                              _seleccionados.remove(m.id);
                            }
                          }),
                  ),
                ),
              );
            }),
            if (coincidencias.length > visibles.length)
              Center(
                child: TextButton.icon(
                  onPressed: _guardando
                      ? null
                      : () => setState(() => _limite += 30),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text(
                    'Mostrar más (${visibles.length}/${coincidencias.length})',
                  ),
                ),
              ),
            if (_seleccionados.isEmpty)
              CatalogoEstilo.nota(
                'Sin medicamentos incluidos, este registro no aplica descuentos.',
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              CatalogoEstilo.nota(_error!, icono: Icons.error_outline_rounded),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cabecera y acciones permanecen visibles; el formulario admite teclado y scroll.
class CatalogoDialogo extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final bool guardando;
  final VoidCallback guardar;
  final Widget child;

  /// Recibe título, contenido y acción de guardado para reutilizar el mismo modal.
  const CatalogoDialogo({
    super.key,
    required this.titulo,
    required this.icono,
    required this.guardando,
    required this.guardar,
    required this.child,
  });

  /// Desplaza también cabecera y acciones si el teclado o el texto reducen el alto.
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !guardando,
    child: DialogoAdaptable(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: CatalogoEstilo.rojo,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icono, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: guardando ? null : () => Navigator.pop(context),
                  color: Colors.white,
                  disabledColor: Colors.white54,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AccionesAdaptables(
              acciones: [
                TextButton(
                  onPressed: guardando ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: guardando ? null : guardar,
                  icon: guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(guardando ? 'Guardando…' : 'Guardar'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

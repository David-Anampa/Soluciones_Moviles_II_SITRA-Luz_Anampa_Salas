import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../administracion/presentation/widgets/catalogo_estilo.dart';
import '../../data/repositories/kits_repository.dart';
import '../../domain/entities/kit_item_entity.dart';
import 'disponibilidad_kit.dart';

class SelectorMedicamentoDialog extends StatefulWidget {
  final KitsRepository repository;
  final Set<String> idsYaSeleccionados;
  const SelectorMedicamentoDialog({
    super.key,
    required this.repository,
    this.idsYaSeleccionados = const {},
  });
  @override
  State<SelectorMedicamentoDialog> createState() =>
      _SelectorMedicamentoDialogState();
}

class _SelectorMedicamentoDialogState extends State<SelectorMedicamentoDialog> {
  final _busqueda = TextEditingController(),
      _cantidad = TextEditingController(text: '1');
  Timer? _espera;
  int _revision = 0;
  List<MedicamentoKit> _medicamentos = [];
  MedicamentoKit? _seleccionado;
  bool _cargando = true;
  String? _error;
  int get _unidades => int.tryParse(_cantidad.text) ?? 0;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    _cantidad.dispose();
    super.dispose();
  }

  /// Agrupa la escritura y descarta respuestas antiguas para no mostrar otra búsqueda.
  void _programarBusqueda(String texto) {
    _espera?.cancel();
    _revision++;
    setState(() {
      _cargando = true;
      _error = null;
      _seleccionado = null;
    });
    _espera = Timer(const Duration(milliseconds: 300), _buscar);
  }

  /// Obtiene medicamentos y disponibilidad vigentes; no inventa stock ante errores.
  Future<void> _buscar() async {
    final revision = ++_revision;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await widget.repository.buscarMedicamentos(
        query: _busqueda.text,
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        _medicamentos = datos.where((m) => m.activo).toList();
        _cargando = false;
      });
    } catch (error) {
      if (!mounted || revision != _revision) return;
      setState(() {
        _error = KitsRepository.mensajeError(error);
        _cargando = false;
      });
    }
  }

  /// Conserva los botones táctiles y permite escribir con teclado numérico.
  void _ajustarCantidad(int delta) {
    final valor = (_unidades + delta).clamp(1, 999999999);
    setState(() => _cantidad.text = '$valor');
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: CatalogoEstilo.tema(context),
    child: Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.medication_outlined,
                    color: CatalogoEstilo.rojo,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Agregar medicamento',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _busqueda,
                onChanged: _programarBusqueda,
                decoration: const InputDecoration(
                  hintText: 'Nombre o principio activo',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? SingleChildScrollView(
                        child: Column(
                          children: [
                            CatalogoEstilo.nota(
                              _error!,
                              icono: Icons.error_outline,
                            ),
                            TextButton(
                              onPressed: _buscar,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _medicamentos.isEmpty
                    ? const Center(
                        child: Text('Sin medicamentos para esta búsqueda.'),
                      )
                    : ListView.separated(
                        itemCount: _medicamentos.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, indice) {
                          final m = _medicamentos[indice];
                          final agregado = widget.idsYaSeleccionados.contains(
                            m.id,
                          );
                          final seleccionado = _seleccionado?.id == m.id;
                          return Material(
                            color: seleccionado
                                ? CatalogoEstilo.pastel
                                : const Color(0xFFF8F8F8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: seleccionado
                                    ? CatalogoEstilo.rojo
                                    : const Color(0xFFE5E5E5),
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: agregado
                                  ? null
                                  : () => setState(() => _seleccionado = m),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            m.nombre,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (agregado)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 8),
                                            child: Icon(
                                              Icons.playlist_add_check_rounded,
                                              color: Color(0xFF757575),
                                            ),
                                          )
                                        else if (seleccionado)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: CatalogoEstilo.rojo,
                                          ),
                                      ],
                                    ),
                                    if (m.laboratorio.isNotEmpty)
                                      Text(
                                        m.laboratorio,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF757575),
                                        ),
                                      ),
                                    if (m.presentacion.isNotEmpty)
                                      Text(
                                        m.presentacion,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF757575),
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    DisponibilidadKit(
                                      medicamento: m,
                                      cantidad: seleccionado ? _unidades : 1,
                                    ),
                                    if (agregado)
                                      const Text(
                                        'Ya incluido en el kit',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_seleccionado != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Cantidad', style: TextStyle(fontSize: 13)),
                    ),
                    IconButton(
                      tooltip: 'Disminuir cantidad',
                      onPressed: _unidades > 1
                          ? () => _ajustarCantidad(-1)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    SizedBox(
                      width: 92,
                      child: TextField(
                        controller: _cantidad,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(9),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          errorText: _unidades < 1 ? 'Mínimo 1' : null,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Aumentar cantidad',
                      onPressed: () => _ajustarCantidad(1),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Agregar'),
                      onPressed:
                          _cargando ||
                              _error != null ||
                              _seleccionado == null ||
                              _unidades < 1
                          ? null
                          : () {
                              final m = _seleccionado!;
                              Navigator.pop(
                                context,
                                KitItemEntity(
                                  id: '',
                                  medicamentoId: m.id,
                                  medicamentoNombre: m.nombre,
                                  presentacion: m.presentacion,
                                  laboratorio: m.laboratorio,
                                  cantidad: _unidades,
                                ),
                              );
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

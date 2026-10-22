import 'package:flutter/material.dart';
import '../../../administracion/data/catalogos_repository.dart';
import '../../data/repositories/kits_repository.dart';
import '../../domain/entities/kit_item_entity.dart';

class SelectorMedicamentoDialog extends StatefulWidget {
  final KitsRepository repository;
  final Set<String> idsYaSeleccionados;

  const SelectorMedicamentoDialog({
    super.key,
    required this.repository,
    this.idsYaSeleccionados = const {},
  });

  @override
  State<SelectorMedicamentoDialog> createState() => _SelectorMedicamentoDialogState();
}

class _SelectorMedicamentoDialogState extends State<SelectorMedicamentoDialog> {
  static const rojo = Color(0xFFC62828);

  final TextEditingController _searchCtrl = TextEditingController();
  List<MedicamentoCobertura> _medicamentos = [];
  bool _cargando = true;
  String? _error;

  MedicamentoCobertura? _seleccionado;
  int _cantidad = 1;

  @override
  void initState() {
    super.initState();
    _buscar('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String query) async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final list = await widget.repository.buscarMedicamentos(query: query);
      if (mounted) {
        setState(() {
          _medicamentos = list;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = KitsRepository.mensajeError(e);
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medication_rounded, color: rojo, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agregar Insumo o Medicamento',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Selecciona del catálogo maestro de la clínica',
                          style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchCtrl,
                onChanged: (val) => _buscar(val),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre comercial...',
                  prefixIcon: const Icon(Icons.search_rounded, color: rojo),
                  filled: true,
                  fillColor: const Color(0xFFF7F7F7),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator(color: rojo))
                    : _error != null
                        ? Center(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _medicamentos.isEmpty
                            ? const Center(
                                child: Text(
                                  'No se encontraron medicamentos activos con ese criterio.',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.separated(
                                itemCount: _medicamentos.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                                itemBuilder: (context, index) {
                                  final med = _medicamentos[index];
                                  final yaEsta = widget.idsYaSeleccionados.contains(med.id);
                                  final esSeleccionado = _seleccionado?.id == med.id;

                                  return ListTile(
                                    dense: true,
                                    selected: esSeleccionado,
                                    selectedTileColor: const Color(0xFFFFF0F0),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    title: Text(
                                      med.nombre,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: yaEsta ? Colors.grey : const Color(0xFF212121),
                                      ),
                                    ),
                                    subtitle: Text(
                                      med.presentacion.isNotEmpty ? med.presentacion : 'Presentación estándar',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF757575)),
                                    ),
                                    trailing: yaEsta
                                        ? const Text(
                                            'Ya agregado',
                                            style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                                          )
                                        : esSeleccionado
                                            ? const Icon(Icons.check_circle_rounded, color: rojo, size: 20)
                                            : null,
                                    onTap: yaEsta
                                        ? null
                                        : () {
                                            setState(() {
                                              _seleccionado = med;
                                            });
                                          },
                                  );
                                },
                              ),
              ),
              const SizedBox(height: 12),
              if (_seleccionado != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _seleccionado!.nombre,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Cantidad requerida en el kit:',
                              style: TextStyle(fontSize: 11, color: Color(0xFF616161)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: rojo),
                        onPressed: _cantidad > 1
                            ? () {
                                setState(() {
                                  _cantidad--;
                                });
                              }
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCCCCCC)),
                        ),
                        child: Text(
                          '$_cantidad',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: rojo),
                        onPressed: () {
                          setState(() {
                            _cantidad++;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar', style: TextStyle(color: Color(0xFF616161))),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: rojo,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Agregar al Kit'),
                    onPressed: _seleccionado == null
                        ? null
                        : () {
                            final item = KitItemEntity(
                              id: '',
                              medicamentoId: _seleccionado!.id,
                              medicamentoNombre: _seleccionado!.nombre,
                              presentacion: _seleccionado!.presentacion,
                              cantidad: _cantidad,
                            );
                            Navigator.of(context).pop(item);
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

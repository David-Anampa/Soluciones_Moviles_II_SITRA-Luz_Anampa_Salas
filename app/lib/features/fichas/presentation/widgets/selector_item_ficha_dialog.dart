import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/tema_area.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../../administracion/presentation/widgets/catalogo_estilo.dart';
import '../../domain/entities/ficha_catalogo_entities.dart';
import '../../domain/ficha_borrador.dart';

/// Diálogo adaptable para seleccionar medicamentos o dispositivos médicos con stock
/// disponible en Farmacia en tiempo real (HU-004 / RF-004).
/// Los productos con stock 0 en Farmacia se muestran deshabilitados y no pueden elegirse.
class SelectorItemFichaDialog extends StatefulWidget {
  final List<MedicamentoStockFicha> catalogo;
  final String categoriaInicial; // MEDICAMENTO | DISPOSITIVO_MEDICO
  final Set<String> idsYaSeleccionados;
  final TemaArea tema;

  const SelectorItemFichaDialog({
    super.key,
    required this.catalogo,
    this.categoriaInicial = 'MEDICAMENTO',
    this.idsYaSeleccionados = const {},
    required this.tema,
  });

  @override
  State<SelectorItemFichaDialog> createState() =>
      _SelectorItemFichaDialogState();
}

class _SelectorItemFichaDialogState extends State<SelectorItemFichaDialog> {
  final TextEditingController _busquedaCtrl = TextEditingController();
  final TextEditingController _cantidadCtrl = TextEditingController(text: '1');

  String _busqueda = '';
  late String _categoriaSeccion;
  bool _soloConStock = false;
  MedicamentoStockFicha? _seleccionado;

  @override
  void initState() {
    super.initState();
    _categoriaSeccion = widget.categoriaInicial;
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    _cantidadCtrl.dispose();
    super.dispose();
  }

  List<MedicamentoStockFicha> get _filtrados {
    final q = _busqueda.trim().toLowerCase();
    return widget.catalogo.where((m) {
      if (_soloConStock && !m.seleccionableIndividualmente) return false;
      if (q.isEmpty) return true;
      final texto =
          '${m.nombre} ${m.principioActivo ?? ''} ${m.presentacion ?? ''} ${m.laboratorio ?? ''}'
              .toLowerCase();
      return texto.contains(q);
    }).toList(growable: false);
  }

  void _elegirProducto(MedicamentoStockFicha item) {
    if (!item.seleccionableIndividualmente) return;
    setState(() {
      _seleccionado = item;
      _categoriaSeccion = item.categoria;
      _cantidadCtrl.text = '1';
    });
  }

  void _confirmarSeleccion() {
    final med = _seleccionado;
    if (med == null) {
      MensajesApp.mostrar(
        context,
        'Selecciona un producto con stock disponible en Farmacia.',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    final cantidad = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;
    if (cantidad <= 0) {
      MensajesApp.mostrar(
        context,
        'Ingresa una cantidad entera mayor que cero.',
        tipo: TipoMensaje.error,
      );
      return;
    }
    if (cantidad > med.farmaciaDisponible) {
      MensajesApp.mostrar(
        context,
        'La cantidad ($cantidad) no puede superar el stock disponible en Farmacia (${med.farmaciaDisponible}).',
        tipo: TipoMensaje.error,
      );
      return;
    }

    Navigator.of(context).pop(
      FichaItemBorrador(
        medicamentoId: med.id,
        nombreComercial: med.nombre,
        presentacion: med.presentacion,
        laboratorio: med.laboratorio,
        unidad: med.unidad,
        categoriaItem: _categoriaSeccion,
        cantidad: cantidad,
        farmaciaDisponible: med.farmaciaDisponible,
        precioKairos: med.precioKairos,
        origenKit: false,
        activo: med.activo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtrados;
    return Theme(
      data: CatalogoEstilo.tema(context, area: widget.tema),
      child: AlertaAdaptable(
        title: const Text('Seleccionar producto del catálogo (HU-004)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MensajesApp.nota(
              'Se muestra el stock disponible en Farmacia en tiempo real. '
              'Los productos sin stock en Farmacia aparecen deshabilitados y no pueden seleccionarse.',
              tipo: TipoMensaje.informacion,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _busquedaCtrl,
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                labelText: 'Buscar por nombre comercial, principio activo o presentación',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _busqueda.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () {
                          _busquedaCtrl.clear();
                          setState(() => _busqueda = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Solo con stock en Farmacia'),
                  selected: _soloConStock,
                  onSelected: (v) => setState(() => _soloConStock = v),
                ),
                Text(
                  '${lista.length} producto(s) mostrados',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64646D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E2EA)),
                ),
                child: lista.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No se encontraron productos que coincidan con tu búsqueda.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: lista.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFEEEEF2)),
                        itemBuilder: (context, index) {
                          final item = lista[index];
                          final habilitado = item.seleccionableIndividualmente;
                          final elegido = _seleccionado?.id == item.id;
                          final yaEnFicha =
                              widget.idsYaSeleccionados.contains(item.id);
                          return ListTile(
                            enabled: habilitado,
                            selected: elegido,
                            selectedTileColor: widget.tema.suave,
                            onTap: habilitado
                                ? () => _elegirProducto(item)
                                : null,
                            leading: Icon(
                              item.esDispositivoMedico
                                  ? Icons.healing_rounded
                                  : Icons.medication_rounded,
                              color: habilitado
                                  ? widget.tema.principal
                                  : Colors.grey.shade400,
                            ),
                            title: Text(
                              item.nombre,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: habilitado
                                    ? CatalogoEstilo.texto
                                    : Colors.grey.shade500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.subtituloDetalle),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _BadgeStock(
                                      etiqueta: habilitado
                                          ? 'Farmacia: ${item.farmaciaDisponible}'
                                          : 'Sin stock en Farmacia (0)',
                                      color: habilitado
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                    ),
                                    if (item.almacenDisponible > 0)
                                      _BadgeStock(
                                        etiqueta:
                                            'Almacén: ${item.almacenDisponible}',
                                        color: const Color(0xFF455A64),
                                      ),
                                    if (item.enTransito > 0)
                                      _BadgeStock(
                                        etiqueta:
                                            'En tránsito: ${item.enTransito}',
                                        color: const Color(0xFFE65100),
                                      ),
                                    if (yaEnFicha)
                                      const _BadgeStock(
                                        etiqueta: 'Ya en la ficha',
                                        color: Color(0xFF1565C0),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: habilitado
                                ? Radio<String>(
                                    value: item.id,
                                    groupValue: _seleccionado?.id,
                                    onChanged: (_) => _elegirProducto(item),
                                  )
                                : const Icon(
                                    Icons.block_rounded,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                          );
                        },
                      ),
              ),
            ),
            if (_seleccionado != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.tema.suave.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.tema.principal.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seleccionado: ${_seleccionado!.nombre} '
                      '(Disponible en Farmacia: ${_seleccionado!.farmaciaDisponible})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 170,
                          child: TextField(
                            controller: _cantidadCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Cantidad a solicitar',
                              helperText:
                                  'Máximo ${_seleccionado!.farmaciaDisponible}',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            value: _categoriaSeccion,
                            decoration: const InputDecoration(
                              labelText: 'Sección en la ficha (RF-003)',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'MEDICAMENTO',
                                child: Text('Sección Medicamentos'),
                              ),
                              DropdownMenuItem(
                                value: 'DISPOSITIVO_MEDICO',
                                child: Text(
                                  'Sección Dispositivos Médicos / Insumos',
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _categoriaSeccion = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: _seleccionado == null ? null : _confirmarSeleccion,
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Agregar a la ficha'),
          ),
        ],
      ),
    );
  }
}

class _BadgeStock extends StatelessWidget {
  final String etiqueta;
  final Color color;

  const _BadgeStock({required this.etiqueta, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        etiqueta,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

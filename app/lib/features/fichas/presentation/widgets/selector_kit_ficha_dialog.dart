import 'package:flutter/material.dart';
import '../../../../core/theme/tema_area.dart';
import '../../../../core/widgets/diseno_adaptable.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../../administracion/presentation/widgets/catalogo_estilo.dart';
import '../../domain/entities/ficha_catalogo_entities.dart';

/// Resultado de aplicar un kit a la ficha (HU-005).
class SeleccionKitResultado {
  final KitDisponibleFicha kit;
  final bool conservarExistentes;
  final bool confirmarFaltante;

  const SeleccionKitResultado({
    required this.kit,
    required this.conservarExistentes,
    required this.confirmarFaltante,
  });
}

/// Diálogo adaptable para elegir una plantilla de kit activa del área y copiar
/// sus ítems a la ficha de forma editable (HU-005 / RF-005).
class SelectorKitFichaDialog extends StatefulWidget {
  final List<KitDisponibleFicha> kitsDisponibles;
  final String areaNombre;
  final bool fichaYaTieneItems;
  final TemaArea tema;

  const SelectorKitFichaDialog({
    super.key,
    required this.kitsDisponibles,
    required this.areaNombre,
    required this.fichaYaTieneItems,
    required this.tema,
  });

  @override
  State<SelectorKitFichaDialog> createState() => _SelectorKitFichaDialogState();
}

class _SelectorKitFichaDialogState extends State<SelectorKitFichaDialog> {
  KitDisponibleFicha? _seleccionado;
  bool _conservarExistentes = true;
  bool _confirmarFaltante = false;

  @override
  void initState() {
    super.initState();
    if (widget.kitsDisponibles.isNotEmpty) {
      _seleccionado = widget.kitsDisponibles.first;
    }
  }

  void _aplicar() {
    final kit = _seleccionado;
    if (kit == null) return;
    if (!kit.tieneStockCompleto && !_confirmarFaltante) {
      MensajesApp.mostrar(
        context,
        'Este kit tiene ítems con stock insuficiente en Farmacia. Marca la casilla de confirmación para copiarlo y ajustar cantidades en la ficha.',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    Navigator.of(context).pop(
      SeleccionKitResultado(
        kit: kit,
        conservarExistentes:
            widget.fichaYaTieneItems ? _conservarExistentes : false,
        confirmarFaltante: _confirmarFaltante,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kit = _seleccionado;
    return Theme(
      data: CatalogoEstilo.tema(context, area: widget.tema),
      child: AlertaAdaptable(
        title: Text('Aplicar kit de ${widget.areaNombre} (HU-005)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MensajesApp.nota(
              'Al aplicar un kit se copia su composición actual a esta ficha. '
              'Podrás editar cantidades, retirar o agregar ítems sin alterar la plantilla original del kit ni fichas anteriores.',
              tipo: TipoMensaje.informacion,
            ),
            const SizedBox(height: 12),
            if (widget.kitsDisponibles.isEmpty)
              MensajesApp.nota(
                'No hay kits activos configurados para el área ${widget.areaNombre}.',
                tipo: TipoMensaje.advertencia,
              )
            else ...[
              DropdownButtonFormField<String>(
                value: kit?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Plantilla de kit activa del área',
                  prefixIcon: Icon(Icons.medical_services_rounded),
                ),
                items: widget.kitsDisponibles
                    .map(
                      (k) => DropdownMenuItem<String>(
                        value: k.id,
                        child: Text(
                          '${k.nombre} (${k.items.length} ítem(s))'
                          '${k.tieneStockCompleto ? " · Stock completo" : " · Con faltante en Farmacia"}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final encontrado = widget.kitsDisponibles
                      .firstWhere((k) => k.id == id);
                  setState(() {
                    _seleccionado = encontrado;
                    _confirmarFaltante = false;
                  });
                },
              ),
              if (kit != null) ...[
                if (kit.descripcion != null &&
                    kit.descripcion!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    kit.descripcion!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64646D),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E2EA)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: kit.items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFEEEEF2)),
                      itemBuilder: (context, index) {
                        final item = kit.items[index];
                        final ok = item.tieneStockSuficiente;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            item.categoria == 'DISPOSITIVO_MEDICO'
                                ? Icons.healing_rounded
                                : Icons.medication_rounded,
                            color: ok
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828),
                          ),
                          title: Text(
                            item.nombreComercial,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${item.presentacion ?? item.unidad} · '
                            'Stock en Farmacia: ${item.farmaciaDisponible}',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (ok
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFC62828))
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Cant. kit: ${item.cantidad}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: ok
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (!kit.tieneStockCompleto) ...[
                  const SizedBox(height: 10),
                  MensajesApp.nota(
                    'Atención: ${kit.itemsConFaltante.length} ítem(s) del kit superan el stock actual en Farmacia. '
                    'Puedes ajustar sus cantidades en la ficha o confirmar la solicitud con faltante.',
                    tipo: TipoMensaje.advertencia,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _confirmarFaltante,
                    onChanged: (v) =>
                        setState(() => _confirmarFaltante = v ?? false),
                    title: const Text(
                      'Confirmar copia del kit aun con stock parcial en Farmacia',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (widget.fichaYaTieneItems) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _conservarExistentes,
                    onChanged: (v) =>
                        setState(() => _conservarExistentes = v ?? true),
                    title: const Text(
                      'Conservar los ítems que ya había agregado a la ficha',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: kit == null ? null : _aplicar,
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('Copiar ítems del kit a la ficha'),
          ),
        ],
      ),
    );
  }
}

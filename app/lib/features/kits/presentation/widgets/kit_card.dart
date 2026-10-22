import 'package:flutter/material.dart';
import '../../domain/entities/kit_entity.dart';

class KitCard extends StatefulWidget {
  final KitEntity kit;
  final VoidCallback onEditar;
  final ValueChanged<bool> onCambiarEstado;
  final VoidCallback onEliminar;

  const KitCard({
    super.key,
    required this.kit,
    required this.onEditar,
    required this.onCambiarEstado,
    required this.onEliminar,
  });

  @override
  State<KitCard> createState() => _KitCardState();
}

class _KitCardState extends State<KitCard> {
  static const rojo = Color(0xFFC62828);
  bool _expandido = false;

  void _confirmarCambioEstado(bool nuevoEstado) {
    final accion = nuevoEstado ? 'habilitar' : 'inhabilitar';
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              nuevoEstado ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
              color: nuevoEstado ? Colors.teal : Colors.orange,
            ),
            const SizedBox(width: 10),
            Text('¿Deseas $accion este kit?'),
          ],
        ),
        content: Text(
          nuevoEstado
              ? 'El kit "${widget.kit.nombre}" volverá a estar disponible para nuevas dispensaciones y solicitudes en ${widget.kit.areaNombre}.'
              : 'Al inhabilitar el kit "${widget.kit.nombre}", no podrá ser seleccionado para nuevas dispensaciones. Todas las fichas y consumos históricos se conservan íntegros.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF616161))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: nuevoEstado ? Colors.teal : Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(nuevoEstado ? 'Habilitar Kit' : 'Inhabilitar Kit'),
          ),
        ],
      ),
    ).then((confirmado) {
      if (confirmado == true) {
        widget.onCambiarEstado(nuevoEstado);
      }
    });
  }

  void _confirmarEliminacion() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: rojo),
            SizedBox(width: 10),
            Text('Eliminar borrador de kit'),
          ],
        ),
        content: Text(
          '¿Estás seguro de eliminar el kit "${widget.kit.nombre}"?\n\n'
          'Nota: Si este kit fue utilizado en alguna ficha médica histórica, el sistema bloqueará el borrado y te orientará a desactivarlo para proteger la trazabilidad.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF616161))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: rojo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ).then((confirmado) {
      if (confirmado == true) {
        widget.onEliminar();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final kit = widget.kit;
    final activo = kit.activo;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activo ? const Color(0xFFE2E2E2) : const Color(0xFFEAEAEA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: activo ? const Color(0xFFFFF0F0) : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.medical_services_rounded,
                        color: activo ? rojo : const Color(0xFF9E9E9E),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kit.nombre,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: activo ? const Color(0xFF212121) : const Color(0xFF757575),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFC8E6C9)),
                                ),
                                child: Text(
                                  'Área: ${kit.areaNombre}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE7F6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFD1C4E9)),
                                ),
                                child: Text(
                                  '${kit.totalItems} insumos',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF512DA8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Badge Estado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: activo ? const Color(0xFFE8F5E9) : const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        activo ? 'Activo' : 'Inactivo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: activo ? const Color(0xFF2E7D32) : const Color(0xFF757575),
                        ),
                      ),
                    ),
                  ],
                ),
                if (kit.descripcion != null && kit.descripcion!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    kit.descripcion!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF616161),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          // Desplegable de insumos
          InkWell(
            onTap: () {
              setState(() {
                _expandido = !_expandido;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _expandido ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: rojo,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _expandido ? 'Ocultar composición del kit' : 'Ver ${kit.items.length} insumos incluidos',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: rojo,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Plantilla de Quirófano / Área',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          if (_expandido) ...[
            Container(
              color: const Color(0xFFFAFAFA),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: kit.items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'No hay insumos detallados registrados en este kit.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  : Column(
                      children: kit.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: rojo,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.medicamentoNombre,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              if (item.presentacion != null && item.presentacion!.isNotEmpty) ...[
                                Text(
                                  '(${item.presentacion})',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF757575)),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFDDDDDD)),
                                ),
                                child: Text(
                                  'Cant: ${item.cantidad}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          // Barra de acciones
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Eliminar borrador de kit',
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF9E9E9E), size: 20),
                  onPressed: _confirmarEliminacion,
                ),
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF424242)),
                  label: const Text(
                    'Editar',
                    style: TextStyle(fontSize: 12, color: Color(0xFF424242)),
                  ),
                  onPressed: widget.onEditar,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: activo ? const Color(0xFFFFF0F0) : const Color(0xFFE8F5E9),
                    foregroundColor: activo ? rojo : const Color(0xFF2E7D32),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: Icon(
                    activo ? Icons.pause_circle_outline_rounded : Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(
                    activo ? 'Desactivar' : 'Activar',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _confirmarCambioEstado(!activo),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

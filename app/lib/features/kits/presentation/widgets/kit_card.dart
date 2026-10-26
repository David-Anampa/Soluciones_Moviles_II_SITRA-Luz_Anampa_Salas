import 'package:flutter/material.dart';
import '../../domain/entities/kit_entity.dart';
import '../../data/repositories/kits_repository.dart';
import 'disponibilidad_kit.dart';

class KitCard extends StatefulWidget {
  final KitEntity kit;
  final VoidCallback onEditar;
  final ValueChanged<bool> onCambiarEstado;
  final VoidCallback onEliminar;
  final VoidCallback? onDuplicar;
  final bool puedeGestionar;
  final bool bloqueada;
  final Map<String, MedicamentoKit> disponibilidad;

  const KitCard({
    super.key,
    required this.kit,
    required this.onEditar,
    required this.onCambiarEstado,
    required this.onEliminar,
    this.onDuplicar,
    this.puedeGestionar = true,
    this.bloqueada = false,
    this.disponibilidad = const {},
  });

  @override
  State<KitCard> createState() => _KitCardState();
}

class _KitCardState extends State<KitCard> {
  static const rojo = Color(0xFFC62828);
  bool _expandido = false;

  /// Solicita confirmación antes de cambiar la disponibilidad para pedidos nuevos.
  void _confirmarCambioEstado(bool nuevoEstado) {
    final accion = nuevoEstado ? 'habilitar' : 'inhabilitar';
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              nuevoEstado
                  ? Icons.check_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              color: rojo,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('¿Deseas $accion este kit?')),
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
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF616161)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: rojo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(nuevoEstado ? 'Habilitar Kit' : 'Inhabilitar Kit'),
          ),
        ],
      ),
    ).then((confirmado) {
      if (mounted && confirmado == true && !widget.bloqueada) {
        widget.onCambiarEstado(nuevoEstado);
      }
    });
  }

  /// Confirma el borrado; el servidor conserva los kits que tengan historial.
  void _confirmarEliminacion() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: rojo),
            SizedBox(width: 10),
            Expanded(child: Text('Eliminar borrador de kit')),
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
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF616161)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: rojo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ).then((confirmado) {
      if (mounted && confirmado == true && !widget.bloqueada) {
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
                        color: activo
                            ? const Color(0xFFFFF0F0)
                            : const Color(0xFFF0F0F0),
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
                              color: activo
                                  ? const Color(0xFF212121)
                                  : const Color(0xFF757575),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0F0),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFFFCDD2),
                                  ),
                                ),
                                child: Text(
                                  'Área: ${kit.areaNombre}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: rojo,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFE0E0E0),
                                  ),
                                ),
                                child: Text(
                                  '${kit.totalItems} insumos',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF616161),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: activo
                            ? const Color(0xFFFFF0F0)
                            : const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        activo ? 'Activo' : 'Inactivo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: activo ? rojo : const Color(0xFF757575),
                        ),
                      ),
                    ),
                  ],
                ),
                if (kit.descripcion != null &&
                    kit.descripcion!.trim().isNotEmpty) ...[
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
                    _expandido
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: rojo,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _expandido
                          ? 'Ocultar composición'
                          : 'Ver ${kit.items.length} insumos incluidos',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: rojo,
                      ),
                    ),
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.medicamentoNombre,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if ([
                                      item.presentacion,
                                      item.laboratorio,
                                    ].any(
                                      (valor) =>
                                          valor != null &&
                                          valor.trim().isNotEmpty,
                                    ))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          [item.presentacion, item.laboratorio]
                                              .whereType<String>()
                                              .where(
                                                (valor) =>
                                                    valor.trim().isNotEmpty,
                                              )
                                              .join(' · '),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF757575),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    DisponibilidadKit(
                                      medicamento: widget
                                          .disponibilidad[item.medicamentoId],
                                      cantidad: item.cantidad,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFDDDDDD),
                                  ),
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
          if (widget.puedeGestionar) ...[
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            // Acciones del mismo ancho, con etiquetas accesibles y respuesta al hover.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: _accion(
                      'Editar kit',
                      Icons.edit_outlined,
                      widget.onEditar,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _accion(
                      'Duplicar como variante',
                      Icons.copy_all_outlined,
                      widget.onDuplicar,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _accion(
                      activo ? 'Inhabilitar kit' : 'Habilitar kit',
                      activo
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                      () => _confirmarCambioEstado(!activo),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _accion(
                      'Eliminar borrador de kit',
                      Icons.delete_outline_rounded,
                      _confirmarEliminacion,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Mantiene iguales las zonas táctiles y explica los iconos al mantener pulsado.
  Widget _accion(String etiqueta, IconData icono, VoidCallback? accion) {
    return Tooltip(
      message: etiqueta,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: rojo,
          backgroundColor: const Color(0xFFFFFAFA),
          side: const BorderSide(color: Color(0xFFFFCDD2)),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          overlayColor: rojo.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: widget.bloqueada ? null : accion,
        child: Semantics(label: etiqueta, child: Icon(icono, size: 21)),
      ),
    );
  }
}

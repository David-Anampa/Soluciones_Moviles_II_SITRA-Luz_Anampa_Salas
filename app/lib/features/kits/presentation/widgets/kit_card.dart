import 'package:flutter/material.dart';
import '../../../../core/theme/tema_area.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../domain/entities/kit_entity.dart';
import '../../data/repositories/kits_repository.dart';
import 'disponibilidad_kit.dart';
import 'laboratorio_medicamento.dart';

class KitCard extends StatefulWidget {
  final KitEntity kit;
  final VoidCallback onEditar;
  final ValueChanged<bool> onCambiarEstado;
  final VoidCallback onEliminar;
  final VoidCallback? onDuplicar;
  final bool puedeGestionar;
  final bool bloqueada;
  final Map<String, MedicamentoKit> disponibilidad;
  final TemaArea tema;

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
    this.tema = const TemaArea(
      'ROJO',
      'Rojo institucional',
      Color(0xFFC62828),
      Color(0xFFFFF0F0),
    ),
  });

  @override
  State<KitCard> createState() => _KitCardState();
}

class _KitCardState extends State<KitCard> {
  bool _expandido = false;

  /// Advierte antes de cambiar disponibilidad; el color del aviso no depende del área.
  Future<void> _confirmarCambioEstado(bool nuevoEstado) async {
    final confirmado = await MensajesApp.confirmar(
      context,
      titulo: nuevoEstado ? 'Habilitar kit' : 'Inhabilitar kit',
      mensaje: nuevoEstado
          ? 'El kit «${widget.kit.nombre}» estará disponible para nuevos pedidos en ${widget.kit.areaNombre}.'
          : 'El kit «${widget.kit.nombre}» no podrá seleccionarse para nuevos pedidos. Su historial se conserva.',
      accion: nuevoEstado ? 'Habilitar kit' : 'Inhabilitar kit',
    );
    if (mounted && confirmado && !widget.bloqueada) {
      widget.onCambiarEstado(nuevoEstado);
    }
  }

  /// Confirma una eliminación destructiva; el servidor bloquea kits con historial.
  Future<void> _confirmarEliminacion() async {
    final confirmado = await MensajesApp.confirmar(
      context,
      titulo: 'Eliminar borrador de kit',
      mensaje:
          '¿Eliminar «${widget.kit.nombre}»? Solo se permite si no tiene fichas asociadas. Esta acción no se puede deshacer.',
      accion: 'Eliminar kit',
      destructivo: true,
    );
    if (mounted && confirmado && !widget.bloqueada) widget.onEliminar();
  }

  @override
  Widget build(BuildContext context) {
    final kit = widget.kit;
    final activo = kit.activo;
    final rojo = widget.tema.principal;

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
                            ? widget.tema.suave
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
                                  color: widget.tema.suave,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: rojo.withValues(alpha: .2),
                                  ),
                                ),
                                child: Text(
                                  'Área: ${kit.areaNombre}',
                                  style: TextStyle(
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
                            ? const Color(0xFFECF7EF)
                            : const Color(0xFFFFEDEA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        activo ? 'Activo' : 'Inactivo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: activo
                              ? const Color(0xFF23713B)
                              : const Color(0xFFB3261E),
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
                      style: TextStyle(
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
                                decoration: BoxDecoration(
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
                                    if (item.presentacion?.trim().isNotEmpty ==
                                        true)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          item.presentacion!.trim(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF757575),
                                          ),
                                        ),
                                      ),
                                    LaboratorioMedicamento(
                                      laboratorio: item.laboratorio,
                                      referencia: widget
                                          .disponibilidad[item.medicamentoId]
                                          ?.laboratorio,
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
                      activo ? Icons.check_circle_rounded : Icons.block_rounded,
                      () => _confirmarCambioEstado(!activo),
                      color: activo
                          ? const Color(0xFF23713B)
                          : const Color(0xFFB3261E),
                      fondo: activo
                          ? const Color(0xFFECF7EF)
                          : const Color(0xFFFFEDEA),
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
  Widget _accion(
    String etiqueta,
    IconData icono,
    VoidCallback? accion, {
    Color? color,
    Color? fondo,
  }) {
    final destructivo = icono == Icons.delete_outline_rounded;
    final edicion = icono == Icons.edit_outlined;
    final tinta = destructivo
        ? Colors.white
        : color ?? (edicion ? const Color(0xFFC62828) : widget.tema.principal);
    final superficie = destructivo
        ? const Color(0xFFC62828)
        : fondo ?? (edicion ? const Color(0xFFFFF0F0) : widget.tema.suave);
    return Tooltip(
      message: etiqueta,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: tinta,
          backgroundColor: superficie,
          disabledBackgroundColor: const Color(0xFFF0F0F0),
          disabledForegroundColor: const Color(0xFF9E9E9E),
          side: BorderSide(
            color: destructivo ? superficie : tinta.withValues(alpha: .2),
          ),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          overlayColor: tinta.withValues(alpha: destructivo ? .16 : .08),
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

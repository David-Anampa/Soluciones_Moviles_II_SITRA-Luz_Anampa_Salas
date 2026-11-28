import 'package:flutter/material.dart';

/// Resumen clínico por área: prioridad visible, sin mostrar datos de pacientes.
class TarjetaPendientesArea extends StatelessWidget {
  final String codigo, nombre;
  final int urgentes, normales;
  final Color color;
  final bool invertida;
  final VoidCallback? onAbrir;
  const TarjetaPendientesArea({
    super.key,
    required this.codigo,
    required this.nombre,
    required this.urgentes,
    required this.normales,
    required this.color,
    this.onAbrir,
    this.invertida = false,
  });

  IconData get _icono {
    if (invertida) return Icons.local_pharmacy_rounded;
    final area = codigo.toUpperCase();
    if (area.contains('NEONAT')) return Icons.child_care_rounded;
    if (area.contains('HOSPITAL')) return Icons.bed_rounded;
    if (area == 'SOP' ||
        area.contains('QUIROF') ||
        area.contains('OPERACION')) {
      return Icons.medical_services_outlined;
    }
    if (area.contains('EMERGEN')) return Icons.emergency_rounded;
    if (area.contains('PARO') || area.contains('UCI')) {
      return Icons.monitor_heart_outlined;
    }
    return Icons.apartment_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = urgentes + normales;
    final borde = BorderRadius.circular(16);
    final tinta = invertida ? Colors.white : color;
    return Semantics(
      button: onAbrir != null,
      enabled: invertida ? null : onAbrir != null,
      label: '$nombre. $urgentes urgentes y $normales normales.',
      child: Material(
        color: invertida ? color : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: borde,
          side: BorderSide(color: color.withValues(alpha: .18)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAbrir,
          hoverColor: color.withValues(alpha: .04),
          splashColor: color.withValues(alpha: .10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 178),
            child: Stack(
              children: [
                Positioned(
                  top: -5,
                  right: -12,
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: Icon(
                        _icono,
                        size: 102,
                        color: tinta.withValues(alpha: invertida ? .16 : .07),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 58),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              softWrap: true,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                                color: tinta,
                              ),
                            ),
                            if (invertida) ...[
                              const SizedBox(height: 4),
                              Text(
                                '$pendientes',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _conteo(
                        'Urgentes',
                        urgentes,
                        Icons.bolt_rounded,
                        invertida
                            ? Colors.white
                            : urgentes > 0
                            ? const Color(0xFFB3261E)
                            : const Color(0xFF777782),
                      ),
                      const SizedBox(height: 8),
                      _conteo(
                        'Normales',
                        normales,
                        Icons.assignment_outlined,
                        tinta,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _conteo(String etiqueta, int cantidad, IconData icono, Color tinta) =>
      Row(
        children: [
          Icon(icono, size: 15, color: tinta),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              etiqueta,
              style: TextStyle(fontSize: 12, color: tinta, height: 1.4),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$cantidad',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: tinta,
            ),
          ),
        ],
      );
}

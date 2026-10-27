import 'package:flutter/material.dart';
import '../../../../core/widgets/mensajes_app.dart';
import '../../data/repositories/kits_repository.dart';

/// Consulta orientativa, nunca una reserva: Almacén y tránsito se muestran separados.
class DisponibilidadKit extends StatelessWidget {
  final MedicamentoKit? medicamento;
  final int cantidad;
  const DisponibilidadKit({
    super.key,
    required this.medicamento,
    required this.cantidad,
  });

  @override
  Widget build(BuildContext context) {
    final m = medicamento;
    if (m == null) {
      return const Text(
        'Disponibilidad sin consultar. Actualiza la lista.',
        style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
      );
    }
    final faltante = (cantidad - m.farmacia).clamp(0, cantidad);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: !m.activo || faltante > 0
            ? MensajesApp.fondo(TipoMensaje.advertencia)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children:
                [
                      Text('Farmacia: ${m.farmacia}'),
                      Text('Almacén: ${m.almacen}'),
                      if (m.transito > 0) Text('En tránsito: ${m.transito}'),
                    ]
                    .map(
                      (texto) => DefaultTextStyle.merge(
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF616161),
                        ),
                        child: texto,
                      ),
                    )
                    .toList(),
          ),
          if (!m.activo || faltante > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    MensajesApp.icono(TipoMensaje.advertencia),
                    size: 18,
                    color: MensajesApp.color(TipoMensaje.advertencia),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      !m.activo
                          ? 'Medicamento deshabilitado: revisar composición.'
                          : 'Faltan $faltante en Farmacia.${m.almacen > 0 ? ' Requiere abastecimiento desde Almacén.' : ' Requiere reposición.'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: MensajesApp.color(TipoMensaje.advertencia),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

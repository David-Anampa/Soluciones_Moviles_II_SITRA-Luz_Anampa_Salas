import 'package:flutter/material.dart';

/// Selección múltiple uniforme: toda la tarjeta es pulsable y admite nombres largos.
class OpcionMultiple extends StatelessWidget {
  final String titulo;
  final bool seleccionada;
  final ValueChanged<bool?>? onChanged;
  const OpcionMultiple({
    super.key,
    required this.titulo,
    required this.seleccionada,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final borde = BorderRadius.circular(12);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: seleccionada ? color.withValues(alpha: .07) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: borde,
          side: BorderSide(
            color: seleccionada
                ? color.withValues(alpha: .55)
                : const Color(0xFFE5E7EB),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: CheckboxListTile(
          value: seleccionada,
          onChanged: onChanged,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          shape: RoundedRectangleBorder(borderRadius: borde),
          title: Text(
            titulo,
            softWrap: true,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ),
    );
  }
}

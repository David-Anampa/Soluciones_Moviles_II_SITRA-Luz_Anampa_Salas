import 'package:flutter/material.dart';
import '../theme/tema_pedidos.dart';

/// Selección múltiple uniforme: toda la tarjeta es pulsable y admite nombres largos.
class OpcionMultiple extends StatelessWidget {
  final String? titulo;
  final Widget? tituloWidget, subtitulo;
  final bool compacta;
  final bool seleccionada;
  final ValueChanged<bool?>? onChanged;
  const OpcionMultiple({
    super.key,
    this.titulo,
    this.tituloWidget,
    this.subtitulo,
    this.compacta = false,
    required this.seleccionada,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Theme(
    data: TemaPedidos.aplicar(context, TemaPedidos.rolActual(context)),
    child: Builder(builder: _contenido),
  );

  Widget _contenido(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final borde = BorderRadius.circular(8);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: seleccionada || compacta
            ? color.withValues(alpha: .07)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: borde),
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
          subtitle: subtitulo,
          title:
              tituloWidget ??
              Text(
                titulo ?? '',
                softWrap: true,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
        ),
      ),
    );
  }
}

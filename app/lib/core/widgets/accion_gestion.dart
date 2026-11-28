import 'package:flutter/material.dart';
import '../theme/tema_pedidos.dart';

/// Patrón de Usuarios para todas las gestiones: icono, tooltip y 48 px táctiles.
class AccionGestion extends StatelessWidget {
  final String ayuda;
  final IconData icono;
  final VoidCallback? onPressed;
  final bool? activa;
  const AccionGestion({
    super.key,
    required this.ayuda,
    required this.icono,
    this.onPressed,
    this.activa,
  });
  @override
  Widget build(BuildContext context) {
    final color = TemaPedidos.colorRol(TemaPedidos.rolActual(context));
    return Semantics(
      toggled: activa,
      child: Tooltip(
        message: ayuda,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            backgroundColor: activa == true
                ? color.withValues(alpha: .10)
                : Colors.white,
            disabledForegroundColor: const Color(0xFF9999A3),
            disabledBackgroundColor: const Color(0xFFF0F0F3),
            side: BorderSide(
              color: onPressed == null
                  ? const Color(0xFFE0E0E5)
                  : color.withValues(alpha: .20),
            ),
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            overlayColor: color.withValues(alpha: .10),
          ),
          child: Icon(icono, size: 22, semanticLabel: ayuda),
        ),
      ),
    );
  }
}

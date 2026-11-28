import 'package:flutter/material.dart';
import '../theme/tema_pedidos.dart';

/// Patrón de Usuarios para todas las gestiones: icono, tooltip y 48 px táctiles.
class AccionGestion extends StatelessWidget {
  final String ayuda;
  final IconData icono;
  final VoidCallback? onPressed;
  final bool? activa;
  final Color? colorTarjeta;
  const AccionGestion({
    super.key,
    required this.ayuda,
    required this.icono,
    this.onPressed,
    this.activa,
    this.colorTarjeta,
  });
  @override
  Widget build(BuildContext context) {
    final color =
        colorTarjeta ?? TemaPedidos.colorRol(TemaPedidos.rolActual(context));
    if (activa != null) {
      final duracion = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180);
      return Tooltip(
        message: ayuda,
        child: Semantics(
          label: ayuda,
          toggled: activa,
          enabled: onPressed != null,
          onTap: onPressed,
          child: ExcludeSemantics(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: 80,
                  height: 48,
                  child: Center(
                    child: AnimatedContainer(
                      duration: duracion,
                      curve: Curves.easeOutCubic,
                      width: 80,
                      height: 40,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: activa! ? color : const Color(0xFFD6DAD5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: AnimatedAlign(
                        duration: duracion,
                        curve: Curves.easeOutCubic,
                        alignment: activa!
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            activa! ? Icons.check_rounded : Icons.close_rounded,
                            color: activa! ? color : const Color(0xFF9DA59D),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final eliminar = icono == Icons.delete_outline_rounded;
    final pastel = Color.alphaBlend(color.withValues(alpha: .12), Colors.white);
    return Semantics(
      toggled: activa,
      child: Tooltip(
        message: ayuda,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: eliminar ? Colors.white : color,
            backgroundColor: eliminar ? color : pastel,
            disabledForegroundColor: const Color(0xFF9999A3),
            disabledBackgroundColor: const Color(0xFFF0F0F3),
            side: BorderSide.none,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            overlayColor: eliminar
                ? Colors.white.withValues(alpha: .15)
                : color.withValues(alpha: .10),
          ),
          child: Icon(icono, size: 22, semanticLabel: ayuda),
        ),
      ),
    );
  }
}

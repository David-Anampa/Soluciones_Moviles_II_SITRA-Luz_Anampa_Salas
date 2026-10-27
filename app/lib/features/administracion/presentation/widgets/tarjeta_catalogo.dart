import 'package:flutter/material.dart';

/// Superficie común de los listados administrativos. El degradado mantiene
/// zonas claras para el texto y las burbujas no reciben gestos ni semántica.
class TarjetaCatalogo extends StatelessWidget {
  final Color principal, pastel;
  final Widget child;
  final VoidCallback? onTap;

  const TarjetaCatalogo({
    super.key,
    required this.principal,
    required this.pastel,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: principal.withValues(alpha: .18)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, pastel, Color.lerp(pastel, principal, .05)!],
          stops: const [0, .65, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: CustomPaint(painter: _BurbujasCatalogo(principal)),
              ),
            ),
          ),
          InkWell(
            onTap: onTap,
            hoverColor: principal.withValues(alpha: .05),
            splashColor: principal.withValues(alpha: .10),
            child: child,
          ),
        ],
      ),
    ),
  );
}

/// Pinta adornos recortados en los bordes sin imponer altura a la tarjeta.
class _BurbujasCatalogo extends CustomPainter {
  final Color color;
  const _BurbujasCatalogo(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final radio = (size.width * .24).clamp(58.0, 108.0);
    canvas.drawCircle(
      Offset(size.width - 12, 6),
      radio,
      Paint()..color = color.withValues(alpha: .07),
    );
    canvas.drawCircle(
      Offset(size.width - radio * .28, radio * .35),
      radio * .53,
      Paint()
        ..color = color.withValues(alpha: .10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      Offset(-22, size.height + 24),
      radio * .85,
      Paint()..color = color.withValues(alpha: .05),
    );
  }

  @override
  bool shouldRepaint(covariant _BurbujasCatalogo oldDelegate) =>
      oldDelegate.color != color;
}

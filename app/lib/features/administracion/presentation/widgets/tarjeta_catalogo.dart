import 'package:flutter/material.dart';

/// Tarjeta con cubierta de degradado orgánico y cuerpo claro para los datos.
/// El adorno no recibe gestos ni semántica; conserva las acciones del listado.
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
          colors: [Colors.white, Color.lerp(Colors.white, pastel, .60)!],
        ),
      ),
      child: InkWell(
        onTap: onTap,
        hoverColor: principal.withValues(alpha: .05),
        splashColor: principal.withValues(alpha: .10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 42,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _CubiertaOrganica(principal, pastel),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    ),
  );
}

/// Combina manchas difuminadas con curvas de nivel inspiradas en la referencia.
/// Usa shaders estáticos en lugar de imágenes, filtros de desenfoque o animaciones.
class _CubiertaOrganica extends CustomPainter {
  final Color color, pastel;
  const _CubiertaOrganica(this.color, this.pastel);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, pastel, .38)!, color],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(.40, -.8),
          radius: 1.05,
          colors: [pastel.withValues(alpha: .55), pastel.withValues(alpha: 0)],
        ).createShader(rect),
    );
    // Curvas asimétricas abiertas: no son círculos ni iconos decorativos.
    canvas.scale(size.width / 360, size.height / 100);
    final trazo = Paint()
      ..color = Colors.white.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final curvas = [
      Path()
        ..moveTo(-12, 20)
        ..cubicTo(42, 92, 64, -44, 120, 12)
        ..cubicTo(176, 68, 164, 120, 228, 88)
        ..cubicTo(280, 62, 314, 0, 372, 38),
      Path()
        ..moveTo(-16, 68)
        ..cubicTo(36, 130, 92, 16, 136, 54)
        ..cubicTo(184, 96, 210, -18, 266, 12)
        ..cubicTo(308, 36, 334, 122, 380, 78),
      Path()
        ..moveTo(60, -12)
        ..cubicTo(106, 30, 168, -24, 184, 16)
        ..cubicTo(206, 62, 266, 120, 312, 92),
    ];
    for (final curva in curvas) {
      canvas.drawPath(curva, trazo);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CubiertaOrganica oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pastel != pastel;
}

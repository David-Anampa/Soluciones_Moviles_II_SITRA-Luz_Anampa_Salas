import 'package:flutter/material.dart';

/// Acceso a una operación existente; un callback nulo conserva su bloqueo actual.
class AccionRapidaAlmacen {
  final String titulo, descripcion;
  final IconData icono;
  final VoidCallback? onTap;
  const AccionRapidaAlmacen({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.onTap,
  });
}

/// Dos accesos por fila. La altura mínima es cuadrada; puede crecer con texto
/// ampliado para no recortar nombres en celulares pequeños.
class AccionesRapidasAlmacen extends StatelessWidget {
  final List<AccionRapidaAlmacen> acciones;
  const AccionesRapidasAlmacen({super.key, required this.acciones});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final lado = (limites.maxWidth - 12) / 2;
      return Column(
        children: [
          for (var i = 0; i < acciones.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _tarjeta(acciones[i], lado)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < acciones.length
                        ? _tarjeta(acciones[i + 1], lado)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );

  /// Icono y nombre sobre un degradado lineal, sin brillos ni halos. La descripción
  /// queda disponible al mantener pulsado o pasar el cursor, mediante el tooltip.
  Widget _tarjeta(AccionRapidaAlmacen accion, double lado) {
    const rojo = Color(0xFFC62828);
    final habilitada = accion.onTap != null;
    final acento = habilitada ? rojo : const Color(0xFF777780);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: lado),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: habilitada
                ? const Color(0xFFE9AEAE)
                : const Color(0xFFE3E3E3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: habilitada
                  ? const [
                      Color(0xFFFFF7F7),
                      Color(0xFFF9DEDE),
                      Color(0xFFF0BBBB),
                    ]
                  : const [
                      Color(0xFFFAFAFA),
                      Color(0xFFF0F0F0),
                      Color(0xFFE7E7E7),
                    ],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: CustomPaint(painter: _LineasAccion(acento)),
                  ),
                ),
              ),
              Tooltip(
                message: accion.descripcion,
                child: InkWell(
                  onTap: accion.onTap,
                  hoverColor: rojo.withValues(alpha: .08),
                  focusColor: rojo.withValues(alpha: .08),
                  splashColor: rojo.withValues(alpha: .12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: acento,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .8),
                              ),
                            ),
                            child: Icon(
                              accion.icono,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          accion.titulo,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: habilitada
                                ? const Color(0xFF262630)
                                : acento,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trazos geométricos discretos en los extremos, sin ocupar espacio del contenido.
class _LineasAccion extends CustomPainter {
  final Color color;
  const _LineasAccion(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / 160, size.height / 160);
    final trazo = Paint()
      ..color = color.withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final d = i * 8.0;
      canvas.drawPath(
        Path()
          ..moveTo(104 + d, -5)
          ..lineTo(104 + d, 20)
          ..lineTo(142 + d, 58)
          ..lineTo(165, 58),
        trazo,
      );
      canvas.drawPath(
        Path()
          ..moveTo(-5, 100 + d)
          ..lineTo(18, 100 + d)
          ..lineTo(50, 132 + d)
          ..lineTo(50, 165),
        trazo,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LineasAccion oldDelegate) =>
      oldDelegate.color != color;
}

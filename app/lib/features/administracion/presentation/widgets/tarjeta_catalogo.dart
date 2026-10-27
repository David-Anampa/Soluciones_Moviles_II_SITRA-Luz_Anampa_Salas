import 'package:flutter/material.dart';
import '../../../../core/theme/tema_area.dart';

enum DisenoTarjeta { area, seguro, convenio, usuario }

/// Paletas visuales; no intervienen en permisos ni cambian el tema del área.
class PaletaTarjeta {
  static TemaArea usuario(String rol) => TemaArea.desde(switch (rol) {
    'ALMACEN' => 'AZUL',
    'FARMACIA' => 'TURQUESA',
    'ENFERMERIA' => 'LAVANDA',
    'JEFATURA_FARMACIA' => 'GRIS_AZUL',
    _ => 'ROJO',
  });
  static TemaArea financiamiento(String tipo) =>
      TemaArea.desde(tipo == 'SEGURO' ? 'AZUL' : 'MORADO');
}

/// Degradado continuo, con zona central clara. El patrón no ocupa altura ni
/// intercepta gestos: la tarjeta crece según el texto y mantiene sus acciones.
class TarjetaCatalogo extends StatelessWidget {
  final Color principal, pastel;
  final DisenoTarjeta diseno;
  final Widget child;
  final VoidCallback? onTap;
  const TarjetaCatalogo({
    super.key,
    required this.principal,
    required this.pastel,
    required this.child,
    this.diseno = DisenoTarjeta.area,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: pastel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: principal.withValues(alpha: .25)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _FondoTarjeta(principal, pastel, diseno),
              ),
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          hoverColor: principal.withValues(alpha: .06),
          splashColor: principal.withValues(alpha: .12),
          child: child,
        ),
      ],
    ),
  );
}

/// Cuatro composiciones estáticas con shaders y trazos nativos, sin imágenes,
/// animaciones ni filtros de desenfoque. Se recortan al borde de cada tarjeta.
class _FondoTarjeta extends CustomPainter {
  final Color color, pastel;
  final DisenoTarjeta diseno;
  const _FondoTarjeta(this.color, this.pastel, this.diseno);

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
          colors: [
            Color.lerp(pastel, color, .32)!,
            pastel,
            Color.lerp(pastel, color, .35)!,
          ],
          stops: const [0, .48, 1],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: diseno == DisenoTarjeta.usuario
              ? const Alignment(-.65, -.55)
              : const Alignment(.80, -.80),
          radius: 1.2,
          colors: [color.withValues(alpha: .30), color.withValues(alpha: 0)],
        ).createShader(rect),
    );
    canvas.save();
    canvas.scale(size.width / 360, size.height / 260);
    final linea = Paint()
      ..color = Colors.white.withValues(alpha: .42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    switch (diseno) {
      case DisenoTarjeta.area:
        // Curvas de nivel a los costados de las áreas.
        for (var i = 0; i < 3; i++) {
          final d = i * 12.0;
          canvas.drawPath(
            Path()
              ..moveTo(255 + d, -15)
              ..cubicTo(230 + d, 58, 345 + d, 32, 370, 104 + d),
            linea,
          );
          canvas.drawPath(
            Path()
              ..moveTo(-15, 95 + d)
              ..cubicTo(60, 112 + d, -35, 192 + d, 85 - d, 275),
            linea,
          );
        }
      case DisenoTarjeta.seguro:
        // Ondas amplias para la credencial del seguro.
        for (var i = 0; i < 3; i++) {
          final d = i * 24.0;
          final onda = Path()
            ..moveTo(180 + d, 280)
            ..cubicTo(180 + d, 132, 310, 188 - d, 380, 100 - d)
            ..lineTo(380, 280)
            ..close();
          canvas.drawPath(onda, Paint()..color = color.withValues(alpha: .09));
          canvas.drawPath(onda, linea);
        }
      case DisenoTarjeta.convenio:
        // Capas diagonales distinguen convenios incluso sin percibir el color.
        for (var i = 0; i < 3; i++) {
          final d = i * 58.0;
          canvas.drawPath(
            Path()
              ..moveTo(160 + d, -15)
              ..lineTo(240 + d, -15)
              ..lineTo(50 + d, 275)
              ..lineTo(-30 + d, 275)
              ..close(),
            Paint()..color = color.withValues(alpha: .07),
          );
          canvas.drawPath(
            Path()
              ..moveTo(240 + d, -15)
              ..lineTo(50 + d, 275),
            linea,
          );
        }
      case DisenoTarjeta.usuario:
        // Malla difuminada de perfil con un contorno lateral discreto.
        canvas.drawPath(
          Path()
            ..moveTo(290, -15)
            ..cubicTo(215, 120, 390, 124, 340, 275),
          linea,
        );
    }
    canvas.restore();
    // Velo central protege nombres, descripciones y datos del registro.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.12, -.10),
          radius: 1.15,
          colors: [Color(0xF5FFFFFF), Color(0xD9FFFFFF), Color(0x00FFFFFF)],
          stops: [0, .55, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FondoTarjeta oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.pastel != pastel ||
      oldDelegate.diseno != diseno;
}

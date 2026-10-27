import 'package:flutter/material.dart';

/// Identidad de un área. Los códigos son persistentes; los mensajes usan otra paleta.
class TemaArea {
  final String codigo, nombre;
  final Color principal, suave;
  const TemaArea(this.codigo, this.nombre, this.principal, this.suave);

  static const opciones = [
    TemaArea(
      'ROJO',
      'Rojo institucional',
      Color(0xFFC62828),
      Color(0xFFFFF0F0),
    ),
    TemaArea('AZUL', 'Azul', Color(0xFF245B8F), Color(0xFFEDF4FB)),
    TemaArea('CELESTE', 'Celeste', Color(0xFF156B97), Color(0xFFEBF7FC)),
    TemaArea('LAVANDA', 'Lavanda', Color(0xFF67518C), Color(0xFFF3EFF9)),
    TemaArea('ROSA', 'Rosa', Color(0xFF934261), Color(0xFFFCF0F5)),
    TemaArea('GRIS_AZUL', 'Gris azulado', Color(0xFF4F6274), Color(0xFFF0F3F6)),
    TemaArea('VERDE', 'Verde salvia', Color(0xFF2E6F50), Color(0xFFEDF7F0)),
    TemaArea('TURQUESA', 'Turquesa', Color(0xFF00796B), Color(0xFFEAF7F5)),
    TemaArea('INDIGO', 'Índigo', Color(0xFF414B8A), Color(0xFFEEF0FA)),
    TemaArea('MORADO', 'Morado', Color(0xFF7B3F8C), Color(0xFFF8EFFA)),
    TemaArea('TERRACOTA', 'Terracota', Color(0xFF9C4938), Color(0xFFFCF0EB)),
    TemaArea('AMBAR', 'Ámbar', Color(0xFF865900), Color(0xFFFFF6E5)),
  ];

  /// Resuelve solo valores conocidos. Áreas anteriores conservan el rojo institucional.
  static TemaArea desde(String codigo) => opciones.firstWhere(
    (tema) => tema.codigo == codigo,
    orElse: () => opciones.first,
  );
}

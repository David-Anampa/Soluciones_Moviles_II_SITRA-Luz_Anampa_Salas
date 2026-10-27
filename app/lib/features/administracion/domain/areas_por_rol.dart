/// Áreas operativas reservadas a roles propios; no son destinos de Enfermería.
bool areaReservadaPorRol(String codigo, String nombre) {
  String normalizar(String texto) {
    var valor = texto.trim().toUpperCase();
    const acentos = 'ÁÉÍÓÚ', letras = 'AEIOU';
    for (var i = 0; i < acentos.length; i++) {
      valor = valor.replaceAll(acentos[i], letras[i]);
    }
    return valor;
  }

  final reservada = RegExp(r'^(FARMACIA|ALMACEN|JEFATURA)([ _-]|$)');
  return reservada.hasMatch(normalizar(codigo)) ||
      reservada.hasMatch(normalizar(nombre));
}

/// El Administrador accede por rol; no necesita una asignación física de área.
String? areaFijaPorRol(String? rol) => switch (rol) {
  'ALMACEN' => 'ALMACEN',
  'FARMACIA' || 'JEFATURA_FARMACIA' => 'FARMACIA',
  _ => null,
};

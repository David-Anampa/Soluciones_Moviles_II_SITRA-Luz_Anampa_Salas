/// Reglas de validación del formulario de usuarios (HU-021/HU-022).
///
/// Son funciones puras, sin dependencias de Flutter ni de Supabase, para poder
/// probarlas de forma aislada. Devuelven el mensaje de error o `null` si el valor
/// es válido, que es el contrato de `TextFormField.validator`. Reflejan las
/// mismas reglas que valida el servidor (`hu021_normalizar_perfil`); el servidor
/// sigue siendo la autoridad final.
class UsuarioValidadores {
  UsuarioValidadores._();

  static final _correo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _usuario = RegExp(r'^[a-z0-9][a-z0-9_.-]{2,31}$');
  static const longitudMinimaClave = 8;
  static const longitudMaximaNombre = 80;

  /// Valida nombres o apellidos: obligatorios, de 2 a 80 caracteres.
  static String? nombre(String? valor, {required String etiqueta}) {
    final texto = (valor ?? '').trim();
    if (texto.length < 2) return 'Escribe $etiqueta.';
    if (texto.length > longitudMaximaNombre) {
      return 'Máximo $longitudMaximaNombre caracteres.';
    }
    return null;
  }

  /// Valida el nombre de usuario: 3 a 32 caracteres en minúsculas, números, `.`, `-` o `_`.
  static String? nombreUsuario(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Escribe el nombre de usuario.';
    if (!_usuario.hasMatch(texto)) {
      return '3 a 32 caracteres: minúsculas, números, punto, guion o guion bajo.';
    }
    return null;
  }

  /// Valida el correo de acceso, obligatorio y con formato de correo.
  static String? correoAcceso(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Escribe el correo de acceso.';
    return _correo.hasMatch(texto) ? null : 'El correo no tiene un formato válido.';
  }

  /// Valida el correo de Drive, que es opcional: vacío es válido.
  static String? correoDrive(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return null;
    return _correo.hasMatch(texto) ? null : 'El correo de Drive no es válido.';
  }

  /// Valida la contraseña inicial: mínimo 8 caracteres con al menos una letra y un número.
  static String? contrasena(String? valor) {
    final texto = valor ?? '';
    if (texto.length < longitudMinimaClave) {
      return 'Usa al menos $longitudMinimaClave caracteres.';
    }
    if (!texto.contains(RegExp(r'[A-Za-z]')) || !texto.contains(RegExp(r'\d'))) {
      return 'Incluye letras y números.';
    }
    return null;
  }

  /// Valida el cargo, que es opcional pero limitado a 80 caracteres.
  static String? cargo(String? valor) {
    final texto = (valor ?? '').trim();
    return texto.length > longitudMaximaNombre
        ? 'Máximo $longitudMaximaNombre caracteres.'
        : null;
  }

  /// Valida que se haya elegido un rol.
  static String? rol(String? valor) =>
      (valor == null || valor.isEmpty) ? 'Selecciona un rol.' : null;
}

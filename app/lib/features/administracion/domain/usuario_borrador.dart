/// Datos editables de un usuario, tal como los envía el formulario HU-021/HU-022.
///
/// Es un objeto de valor inmutable: separa lo que el formulario captura de cómo
/// se transmite al servidor. No contiene la contraseña ni el correo de acceso,
/// porque ambos pertenecen a Supabase Auth y solo se usan al crear la cuenta.
class UsuarioBorrador {
  final String nombres, apellidos, nombreUsuario, cargo, rol;
  final List<String> areas;
  final String colegioCodigo, numeroColegiatura, especialidadCodigo;
  final bool puedeGestionarKits;

  /// Construye el borrador; los textos se limpian en [toJson] antes de enviarse.
  const UsuarioBorrador({
    required this.nombres,
    required this.apellidos,
    required this.nombreUsuario,
    required this.cargo,
    required this.rol,
    required this.areas,
    this.colegioCodigo = '',
    this.numeroColegiatura = '',
    this.especialidadCodigo = '',
    this.puedeGestionarKits = false,
  });

  /// Convierte el borrador al JSON que esperan las RPC `administrar_usuario_hu020`
  /// y `registrar_perfil_usuario_hu021`. El servidor vuelve a validar cada campo.
  Map<String, dynamic> toJson() => {
    'nombres': nombres.trim(),
    'apellidos': apellidos.trim(),
    'nombre_usuario': nombreUsuario.trim().toLowerCase(),
    'cargo': cargo.trim(),
    'rol': rol,
    'areas': areas,
    'puede_gestionar_kits': puedeGestionarKits,
    'colegio_codigo': colegioCodigo.isEmpty ? null : colegioCodigo,
    'numero_colegiatura': numeroColegiatura.trim().isEmpty
        ? null
        : numeroColegiatura.trim(),
    'especialidad_codigo': especialidadCodigo.isEmpty
        ? null
        : especialidadCodigo,
  };
}

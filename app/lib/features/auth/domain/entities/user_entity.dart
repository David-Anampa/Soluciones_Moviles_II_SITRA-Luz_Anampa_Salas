/// HU-002: Roles del sistema SITRA-Luz y permisos de sesión.
enum UserRole {
  administrador,
  jefaturaFarmacia,
  farmacia,
  almacen,
  enfermeria,
}

/// Extensión para convertir el rol a String legible y viceversa
extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.administrador:
        return 'Administrador';
      case UserRole.jefaturaFarmacia:
        return 'Jefatura de Farmacia';
      case UserRole.farmacia:
        return 'Farmacia';
      case UserRole.almacen:
        return 'Almacén';
      case UserRole.enfermeria:
        return 'Enfermería / Técnico';
    }
  }

  String get dbValue => supabaseValue;

  String get supabaseValue {
    switch (this) {
      case UserRole.administrador:
        return 'ADMINISTRADOR';
      case UserRole.jefaturaFarmacia:
        return 'JEFATURA_FARMACIA';
      case UserRole.farmacia:
        return 'FARMACIA';
      case UserRole.almacen:
        return 'ALMACEN';
      case UserRole.enfermeria:
        return 'ENFERMERIA';
    }
  }

  String get firestoreValue => supabaseValue;

  static UserRole fromDb(String value) => fromSupabase(value);

  static UserRole fromSupabase(String value) {
    final norm = value.toUpperCase().trim().replaceAll(' ', '_');
    return switch (norm) {
      'ADMINISTRADOR' || 'ADMIN' => UserRole.administrador,
      'JEFATURA_FARMACIA' || 'JEFATURA' || 'JEFE' => UserRole.jefaturaFarmacia,
      'FARMACIA' || 'FARMA' => UserRole.farmacia,
      'ALMACEN' || 'ALMACÉN' => UserRole.almacen,
      'ENFERMERIA' || 'ENFERMERÍA' || 'TECNICO' || 'TÉCNICO' || 'ENFERMERA' => UserRole.enfermeria,
      _ => throw const FormatException('El perfil no tiene un rol válido.'),
    };
  }

  static UserRole fromFirestore(String value) => fromSupabase(value);
}

/// Entidad de dominio pura — no depende de ningún framework
class UserEntity {
  final String uid;
  final String nombre;
  final String email;
  final UserRole rol;
  final List<String> areasAsignadas;
  final bool activo;

  const UserEntity({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.rol,
    required this.areasAsignadas,
    required this.activo,
  });

  @override
  String toString() =>
      'UserEntity(uid: $uid, nombre: $nombre, rol: ${rol.firestoreValue})';
}

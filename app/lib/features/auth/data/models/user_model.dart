import '../../domain/entities/user_entity.dart';

/// DTO que mapea la fila de la tabla `profiles` de Supabase a la entidad de dominio.
/// Tabla: public.profiles
class UserModel {
  final String uid;
  final String nombre;
  final String email;
  final String rol;
  final List<String> areasAsignadas;
  final String? fcmToken;
  final bool activo;

  const UserModel({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.rol,
    required this.areasAsignadas,
    this.fcmToken,
    required this.activo,
  });

  /// Construye un [UserModel] desde un mapa retornado por Supabase (PostgreSQL)
  factory UserModel.fromMap(Map<String, dynamic> data, [String? fallbackId]) {
    final id = data['id']?.toString() ?? data['uid']?.toString() ?? fallbackId ?? '';
    
    List<String> areas = [];
    final rawAreas = data['areas_asignadas'] ?? data['areasAsignadas'];
    if (rawAreas is List) {
      areas = rawAreas.map((e) => e.toString()).toList();
    }

    return UserModel(
      uid: id,
      nombre: data['nombre'] as String? ?? '',
      email: data['email'] as String? ?? '',
      rol: data['rol'] as String? ?? '',
      areasAsignadas: areas,
      fcmToken: data['fcm_token'] as String?,
      activo: data['activo'] as bool? ?? false,
    );
  }

  /// Constructor alternativo para compatibilidad
  factory UserModel.fromSupabase(Map<String, dynamic> data, [String? id]) =>
      UserModel.fromMap(data, id);

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) =>
      UserModel.fromMap(data, uid);

  /// Convierte el modelo a un mapa para guardar o actualizar en Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': uid,
      'nombre': nombre,
      'email': email,
      'rol': rol,
      'areas_asignadas': areasAsignadas,
      if (fcmToken != null) 'fcm_token': fcmToken,
      'activo': activo,
    };
  }

  Map<String, dynamic> toSupabase() => toMap();
  Map<String, dynamic> toFirestore() => toMap();

  /// Convierte el DTO a la entidad pura de dominio
  UserEntity toEntity() {
    return UserEntity(
      uid: uid,
      nombre: nombre,
      email: email,
      rol: UserRoleExtension.fromDb(rol),
      areasAsignadas: areasAsignadas,
      activo: activo,
    );
  }
}

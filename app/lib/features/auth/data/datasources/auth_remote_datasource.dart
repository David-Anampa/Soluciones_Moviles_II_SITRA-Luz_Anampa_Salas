import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/notification_service.dart';
import '../models/user_model.dart';

/// Excepción específica del módulo de autenticación
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Fuente de datos remota — interactúa directamente con Supabase (Auth + PostgreSQL).
/// Esta clase es la ÚNICA que conoce Supabase en la capa de datos de autenticación.
class AuthRemoteDataSource {
  final SupabaseClient? _customClient;

  AuthRemoteDataSource({SupabaseClient? client}) : _customClient = client;

  SupabaseClient get _supabase => _customClient ?? Supabase.instance.client;

  /// Inicia sesión con email y contraseña usando Supabase Auth
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException('No se pudo obtener el usuario autenticado.');
      }

      // Obtener el perfil asociado desde la tabla 'profiles'
      final userModel = await _getUserModel(user.id);

      // Sincronizar el token de notificaciones FCM con Supabase si está disponible
      try {
        await NotificationService.instance.syncTokenWithSupabase();
      } catch (e) {
        debugPrint('⚠️ No se pudo sincronizar token FCM tras login: $e');
      }

      return userModel;
    } on AuthApiException catch (e) {
      final rawMsg = '${e.code} ${e.message}';
      if (_isNetworkError(rawMsg)) {
        throw const AuthException('Sin conexión a internet');
      }
      throw AuthException(_mapSupabaseAuthError(e.code ?? e.message));
    } on PostgrestException catch (e) {
      debugPrint('Error Postgrest al obtener perfil: ${e.message}');
      if (_isNetworkError('${e.message} ${e.details}')) {
        throw const AuthException('Sin conexión a internet');
      }
      throw const AuthException(
        'Error al cargar el perfil de usuario en la base de datos.',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('Error inesperado en login: $e');
      if (_isNetworkError(e.toString())) {
        throw const AuthException('Sin conexión a internet');
      }
      throw AuthException('Error al iniciar sesión: ${e.toString()}');
    }
  }

  /// Cierra la sesión activa en Supabase
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('Error al cerrar sesión en Supabase: $e');
      throw const AuthException('No se pudo cerrar la sesión. Revisa la conexión e inténtalo de nuevo.');
    }
  }

  /// Obtiene el UserModel del usuario actualmente autenticado
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      return await _getUserModel(user.id);
    } catch (_) {
      return null;
    }
  }

  /// Stream de cambios en el estado de autenticación de Supabase
  Stream<UserModel?> get authStateChanges {
    try {
      return _supabase.auth.onAuthStateChange.asyncMap((data) async {
        final user = data.session?.user;
        if (user == null) return null;
        try {
          return await _getUserModel(user.id);
        } catch (_) {
          return null;
        }
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Consulta la fila del usuario en la tabla `profiles` de Supabase
  Future<UserModel> _getUserModel(String uid) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (response == null) {
      await _descartarSesionInvalida();
      throw const AuthException(
        'Perfil de usuario no registrado en la base de datos de la clínica.',
      );
    }

    final model = UserModel.fromMap(response, uid);
    if (!model.activo) {
      await _descartarSesionInvalida();
      throw const AuthException(
        'Tu cuenta está deshabilitada. Contacta al administrador del sistema.',
      );
    }
    try {
      model.toEntity();
    } on FormatException {
      await _descartarSesionInvalida();
      throw const AuthException('El perfil no tiene un rol válido. Contacta al administrador.');
    }
    return model;
  }

  Future<void> _descartarSesionInvalida() async {
    try {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // El ViewModel deniega igualmente el acceso; SQL valida el perfil activo.
    }
  }

  /// Detecta si una cadena de error corresponde a una falla de conectividad a internet
  bool _isNetworkError(String errStr) {
    final lower = errStr.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('unreachable') ||
        lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('authretryablefetchexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('no internet') ||
        lower.contains('sin conexión') ||
        lower.contains('host lookup') ||
        lower.contains('os error') ||
        lower.contains('errno = 11001') ||
        lower.contains('errno = 10060') ||
        lower.contains('errno = 111') ||
        lower.contains('fetch_error');
  }

  /// Traduce los códigos de error de Supabase Auth a mensajes en español amigables
  String _mapSupabaseAuthError(String codeOrMessage) {
    if (_isNetworkError(codeOrMessage)) {
      return 'Sin conexión a internet';
    }
    final lower = codeOrMessage.toLowerCase();
    if (lower.contains('invalid_credentials') ||
        lower.contains('invalid login credentials') ||
        lower.contains('invalid_grant')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (lower.contains('user not found') || lower.contains('user_not_found')) {
      return 'No existe ningún usuario registrado con ese correo.';
    }
    if (lower.contains('email not confirmed') || lower.contains('email_not_confirmed')) {
      return 'El correo aún no ha sido confirmado.';
    }
    if (lower.contains('too many requests') || lower.contains('over_request_rate_limit')) {
      return 'Demasiados intentos de acceso. Espera unos minutos.';
    }
    return 'Error de autenticación: $codeOrMessage';
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/network/diagnostico_red.dart';
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

  /// Acepta correo o nombre de usuario. Solo el servidor resuelve usuario → correo.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final identificador = email.trim();
      final response = identificador.contains('@')
          ? await DiagnosticoRed.medir(
              'Sesion.validarCredenciales',
              () => _supabase.auth.signInWithPassword(
                email: identificador.toLowerCase(),
                password: password,
              ),
            )
          : await _loginPorUsuario(identificador, password);

      final user = response.user;
      if (user == null) {
        throw const AuthException('No se pudo obtener el usuario autenticado.');
      }

      // Obtener el perfil asociado desde la tabla 'profiles'
      final userModel = await _getUserModel(user.id);

      // Sincronizar el token de notificaciones FCM con Supabase si está disponible
      try {
        await NotificationService.instance.syncTokenWithSupabase();
      } catch (e, stack) {
        DiagnosticoRed.error('Sesion.sincronizarNotificaciones', e, stack, 0);
      }

      return userModel;
    } on AuthRetryableFetchException catch (e) {
      throw AuthException(
        e.message.toLowerCase().contains('timeoutexception')
            ? 'El acceso tardó demasiado. Revisa la conexión del dispositivo y vuelve a intentar.'
            : 'No se pudo conectar con el servicio de acceso. Vuelve a intentar.',
      );
    } on AuthApiException catch (e) {
      final rawMsg = '${e.code} ${e.message}';
      if (rawMsg.toLowerCase().contains('timeoutexception')) {
        throw const AuthException(
          'El acceso tardó demasiado. Revisa la conexión del dispositivo y vuelve a intentar.',
        );
      }
      if (_isNetworkError(rawMsg)) {
        throw const AuthException('Sin conexión a internet');
      }
      throw AuthException(_mapSupabaseAuthError(e.code ?? e.message));
    } on PostgrestException catch (e, stack) {
      DiagnosticoRed.error('Sesion.perfil', e, stack, 0);
      if (_isNetworkError('${e.message} ${e.details}')) {
        throw const AuthException('Sin conexión a internet');
      }
      throw const AuthException(
        'Error al cargar el perfil de usuario en la base de datos.',
      );
    } catch (e, stack) {
      if (e is AuthException) rethrow;
      if (e is TimeoutException) {
        throw const AuthException(
          'La consulta del perfil tardó demasiado. Revisa la conexión y vuelve a intentar.',
        );
      }
      DiagnosticoRed.error('Sesion.iniciar', e, stack, 0);
      if (_isNetworkError(e.toString())) {
        throw const AuthException('Sin conexión a internet');
      }
      throw const AuthException(
        'No se pudo completar el inicio de sesión. Revisa la conexión y vuelve a intentar.',
      );
    }
  }

  /// Obtiene una sesión verificada por Auth desde la función pública de login.
  /// La espera se limita antes de recuperar la sesión, evitando respuestas tardías.
  Future<AuthResponse> _loginPorUsuario(String usuario, String password) async {
    try {
      final respuesta = await DiagnosticoRed.medir(
        'Sesion.loginPorUsuario',
        () => _supabase.functions
            .invoke(
              'login-usuario',
              body: {'usuario': usuario, 'password': password},
            )
            .timeout(const Duration(seconds: 20)),
      );
      final datos = respuesta.data;
      if (respuesta.status != 200 ||
          datos is! Map ||
          datos['session'] is! Map) {
        throw const AuthException('No se pudo completar el acceso.');
      }
      return await _supabase.auth.recoverSession(jsonEncode(datos['session']));
    } on FunctionException catch (error) {
      if (error.status == 401 || error.status == 403) {
        throw const AuthException(
          'Usuario o contraseña incorrectos, o cuenta no habilitada.',
        );
      }
      if (error.status == 404) {
        throw const AuthException('Falta desplegar login-usuario en Supabase.');
      }
      if (error.status == 429) {
        throw const AuthException(
          'Demasiados intentos. Espera un momento y vuelve a intentar.',
        );
      }
      throw const AuthException(
        'El servicio de acceso no está disponible. Vuelve a intentar.',
      );
    }
  }

  /// Cierra la sesión activa en Supabase.
  Future<void> logout() async {
    try {
      await DiagnosticoRed.medir(
        'Sesion.cerrar',
        () => _supabase.auth.signOut(scope: SignOutScope.local),
      );
    } catch (e, stack) {
      DiagnosticoRed.error('Sesion.cerrar', e, stack, 0);
      throw const AuthException(
        'No se pudo cerrar la sesión. Revisa la conexión e inténtalo de nuevo.',
      );
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
      return Stream<UserModel?>.multi((controlador) {
        var revision = 0;
        final suscripcion = _supabase.auth.onAuthStateChange.listen(
          (data) {
            final actual = ++revision;
            final user = data.session?.user;
            if (user == null) {
              controlador.add(null);
              return;
            }
            // No encolar signedOut detrás de una consulta de perfil lenta.
            unawaited(() async {
              try {
                final perfil = await _getUserModel(user.id);
                if (!controlador.isClosed &&
                    actual == revision &&
                    _supabase.auth.currentUser?.id == user.id) {
                  controlador.add(perfil);
                }
              } catch (_) {
                if (!controlador.isClosed && actual == revision) {
                  controlador.add(null);
                }
              }
            }());
          },
          onError: (Object error, StackTrace stack) {
            revision++;
            controlador.addError(error, stack);
          },
        );
        controlador.onCancel = () {
          revision++;
          return suscripcion.cancel();
        };
      }, isBroadcast: true);
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Consulta la fila del usuario en la tabla `profiles` de Supabase
  Future<UserModel> _getUserModel(String uid) =>
      DiagnosticoRed.medir('Sesion.cargarPerfil', () => _consultarPerfil(uid));

  /// Consulta el perfil; su identificador no se imprime en los registros.
  Future<UserModel> _consultarPerfil(String uid) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));

    if (response == null) {
      await _descartarSesionInvalida(uid);
      throw const AuthException(
        'Perfil de usuario no registrado en la base de datos de la clínica.',
      );
    }

    final model = UserModel.fromMap(response, uid);
    if (!model.activo) {
      await _descartarSesionInvalida(uid);
      throw const AuthException(
        'Tu cuenta está deshabilitada. Contacta al administrador del sistema.',
      );
    }
    try {
      model.toEntity();
    } on FormatException {
      await _descartarSesionInvalida(uid);
      throw const AuthException(
        'El perfil no tiene un rol válido. Contacta al administrador.',
      );
    }
    return model;
  }

  Future<void> _descartarSesionInvalida(String uid) async {
    // Una consulta anterior no puede cerrar la sesión de otra persona.
    if (_supabase.auth.currentUser?.id != uid) return;
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
    if (lower.contains('email not confirmed') ||
        lower.contains('email_not_confirmed')) {
      return 'El correo aún no ha sido confirmado.';
    }
    if (lower.contains('too many requests') ||
        lower.contains('over_request_rate_limit')) {
      return 'Demasiados intentos de acceso. Espera unos minutos.';
    }
    return 'Error de autenticación: $codeOrMessage';
  }
}

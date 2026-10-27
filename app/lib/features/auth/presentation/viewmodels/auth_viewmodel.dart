import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../states/auth_state.dart';

/// ViewModel del módulo de autenticación.
/// Implementa [ChangeNotifier] para notificar a la UI.
/// No importa nada de Firebase directamente — usa [AuthRepository].
class AuthViewModel extends ChangeNotifier {
  final AuthRepository _repository;

  AuthState _state = const AuthStateInitial();
  AuthState get state => _state;

  UserEntity? _currentUser;
  UserEntity? get currentUser => _currentUser;
  StreamSubscription<UserEntity?>? _authSubscription;
  bool _authOperationInProgress = false;
  bool _disposed = false;
  int _sessionRevision = 0;
  int _operationRevision = 0;
  bool _cerrandoSesion = false;

  AuthViewModel({required AuthRepository repository})
    : _repository = repository {
    _authSubscription = _repository.authStateChanges.listen(
      _onSessionChanged,
      onError: (Object error, StackTrace stackTrace) => _onSessionChanged(null),
    );
    _checkCurrentSession();
  }

  void _onSessionChanged(UserEntity? user) {
    if (_disposed) return;
    _sessionRevision++;
    // La salida local llega antes que la revocación remota: no bloquear el login.
    if (_cerrandoSesion && user == null) {
      _cerrandoSesion = false;
      _authOperationInProgress = false;
      _currentUser = null;
      _setState(const AuthStateUnauthenticated());
      return;
    }
    if (_authOperationInProgress) return;
    if (user == null && _currentUser == null && _state is AuthStateError) {
      return;
    }
    _currentUser = user != null && user.activo ? user : null;
    _setState(
      _currentUser == null
          ? const AuthStateUnauthenticated()
          : AuthStateAuthenticated(_currentUser!),
    );
  }

  /// Verifica si hay una sesión activa al iniciar la app
  Future<void> _checkCurrentSession() async {
    final revision = _sessionRevision;
    _setState(const AuthStateLoading());
    try {
      final user = await _repository.getCurrentUser();
      if (_disposed || revision != _sessionRevision) return;
      if (user != null && user.activo) {
        _currentUser = user;
        _setState(AuthStateAuthenticated(user));
      } else {
        _currentUser = null;
        _setState(const AuthStateUnauthenticated());
      }
    } catch (_) {
      if (_disposed || revision != _sessionRevision) return;
      _currentUser = null;
      _setState(const AuthStateUnauthenticated());
    }
  }

  /// Inicia sesión con email y contraseña
  Future<void> login({required String email, required String password}) async {
    if (_authOperationInProgress || _disposed) return;
    if (email.trim().isEmpty || password.isEmpty) {
      _setState(const AuthStateError('Por favor completa todos los campos.'));
      return;
    }
    _authOperationInProgress = true;
    _operationRevision++;
    _sessionRevision++;
    _currentUser = null;
    _setState(const AuthStateLoading());
    try {
      final user = await _repository.login(email: email, password: password);
      if (_disposed) return;
      if (!user.activo) {
        throw const AuthException('Tu cuenta está deshabilitada.');
      }
      _currentUser = user;
      _setState(AuthStateAuthenticated(user));
    } on AuthException catch (e) {
      _currentUser = null;
      _setState(AuthStateError(e.message));
    } catch (e) {
      _currentUser = null;
      _setState(const AuthStateError('Error inesperado. Inténtalo de nuevo.'));
    } finally {
      _authOperationInProgress = false;
    }
  }

  /// Cierra la sesión actual
  Future<void> logout() async {
    if (_authOperationInProgress || _disposed) return;
    _authOperationInProgress = true;
    _cerrandoSesion = true;
    final operacion = ++_operationRevision;
    _sessionRevision++;
    _currentUser = null;
    _setState(const AuthStateLoading());
    try {
      await _repository.logout();
      if (_disposed || operacion != _operationRevision || !_cerrandoSesion) {
        return;
      }
      _currentUser = null;
      _setState(const AuthStateUnauthenticated());
    } catch (e) {
      if (_disposed || operacion != _operationRevision || !_cerrandoSesion) {
        return;
      }
      _setState(
        const AuthStateError(
          'No se pudo cerrar la sesión. Inténtalo de nuevo.',
        ),
      );
    } finally {
      if (operacion == _operationRevision) {
        _authOperationInProgress = false;
        _cerrandoSesion = false;
      }
    }
  }

  /// Limpia un error anterior para permitir reintentar
  void clearError() {
    if (_state is AuthStateError) {
      _setState(const AuthStateInitial());
    }
  }

  void _setState(AuthState newState) {
    if (_disposed) return;
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}

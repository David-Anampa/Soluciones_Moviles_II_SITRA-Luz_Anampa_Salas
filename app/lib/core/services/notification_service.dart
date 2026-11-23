import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// FCM transporta avisos; Supabase conserva sesión, destinatario e historial.
class NotificationService extends ChangeNotifier with WidgetsBindingObserver {
  NotificationService._();
  static final instance = NotificationService._();
  static const enableFirebaseSdk = true;
  static const enablePushNotifications = true;
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  SupabaseClient get _db => Supabase.instance.client;
  bool _initialized = false;
  bool get isInitialized => _initialized;
  bool registered = false;
  int unread = 0;
  int revision = 0;
  String? _userId;
  String? _pendingId;
  String? _pendingOwner;
  String? _installation;
  String? _testRequest;
  void Function(String id)? openNotification;

  static String newId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> initialize() async {
    if (_initialized || !enablePushNotifications) return;
    final prefs = await SharedPreferences.getInstance();
    _installation = prefs.getString('push_instalacion') ?? newId();
    await prefs.setString('push_instalacion', _installation!);
    _pendingId = prefs.getString('push_pendiente');
    _pendingOwner = prefs.getString('push_destinatario');
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    FirebaseMessaging.onMessage.listen((message) {
      if (message.data['usuario_id'] != _userId) return;
      final id = message.data['notification_id'];
      if (id == null || !_uuidPattern.hasMatch(id)) return;
      revision++;
      unawaited(refreshUnread());
      notifyListeners();
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Tienes una nueva notificación de SITRA-Luz.'),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Abrir',
            onPressed: () => openNotification?.call(id),
          ),
        ),
      );
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      if (_userId != null) unawaited(registerDevice(requestPermission: false));
    });
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) await _handleTap(initial);
    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
  }

  Future<void> _handleTap(RemoteMessage message) async {
    final id = message.data['notification_id'];
    final owner = message.data['usuario_id'];
    if (id == null ||
        owner == null ||
        !_uuidPattern.hasMatch(id) ||
        !_uuidPattern.hasMatch(owner)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('push_pendiente', id);
    await prefs.setString('push_destinatario', owner);
    _pendingId = id;
    _pendingOwner = owner;
    notifyListeners();
  }

  /// Solo rutas internas; nunca se abre una URL recibida en el push.
  String? takePendingRoute(String userId) {
    if (_pendingId == null) return null;
    final path = _pendingOwner == userId
        ? '/notificaciones?aviso=${Uri.encodeQueryComponent(_pendingId!)}'
        : '/notificaciones';
    _pendingId = null;
    _pendingOwner = null;
    unawaited(
      SharedPreferences.getInstance().then((p) async {
        await p.remove('push_pendiente');
        await p.remove('push_destinatario');
      }),
    );
    return path;
  }

  void bindUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    unread = 0;
    registered = false;
    _testRequest = null;
    notifyListeners();
    if (userId != null) {
      unawaited(refreshUnread());
      if (_initialized) unawaited(registerDevice(requestPermission: false));
    }
  }

  Future<String?> registerDevice({bool requestPermission = true}) async {
    final user = _userId;
    registered = false;
    notifyListeners();
    if (user == null) return 'Inicia sesión para activar los avisos.';
    if (!_initialized) {
      return 'El canal de avisos no está disponible en esta compilación.';
    }
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = requestPermission
          ? await messaging.requestPermission()
          : await messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return 'Permite las notificaciones en Ajustes de Android → SITRA-Luz → Notificaciones.';
      }
      final token = await messaging.getToken().timeout(
        const Duration(seconds: 15),
      );
      if (user != _userId || _db.auth.currentUser?.id != user) {
        return 'La sesión cambió.';
      }
      if (token == null) {
        return 'Google Play aún no entregó un identificador. Intenta nuevamente.';
      }
      await _db
          .rpc(
            'registrar_dispositivo_push',
            params: {'p_instalacion': _installation, 'p_token': token},
          )
          .timeout(const Duration(seconds: 15));
      if (user != _userId) return 'La sesión cambió.';
      registered = true;
      notifyListeners();
      return null;
    } catch (_) {
      return 'No se pudo activar este dispositivo. Revisa Internet y Google Play Services.';
    }
  }

  Future<void> unregisterDevice() async {
    registered = false;
    try {
      if (_installation != null) {
        await _db
            .rpc(
              'desvincular_dispositivo_push',
              params: {'p_instalacion': _installation},
            )
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {
      /* El cierre de sesión sigue aunque no haya Internet. */
    }
    try {
      if (_initialized) {
        await FirebaseMessaging.instance.deleteToken().timeout(
          const Duration(seconds: 4),
        );
      }
    } catch (_) {
      /* Un aviso genérico nunca concede acceso a datos clínicos. */
    }
  }

  Future<void> refreshUnread() async {
    final user = _userId;
    if (user == null) return;
    try {
      final count = await _db
          .from('notificaciones')
          .count(CountOption.exact)
          .eq('usuario_id', user)
          .isFilter('leido_en', null);
      if (user != _userId) return;
      unread = count;
      notifyListeners();
    } catch (_) {
      /* Conservar contador si falla Internet. */
    }
  }

  Future<String> sendTest() async {
    final user = _userId;
    final registrationError = await registerDevice();
    if (registrationError != null) return registrationError;
    // Permite pulsar Inicio de Android para comprobar el aviso del sistema.
    await Future<void>.delayed(const Duration(seconds: 5));
    if (user == null || user != _userId) return 'La sesión cambió.';
    _testRequest ??= newId();
    try {
      final response = await _db.functions.invoke(
        'enviar-notificacion-prueba',
        body: {'instalacion_id': _installation, 'solicitud_id': _testRequest},
      );
      if (user != _userId) return 'La sesión cambió.';
      final data = response.data as Map;
      if (data['estado'] == 'enviado') {
        _testRequest = null;
        return 'Firebase aceptó el envío. Comprueba su llegada en este dispositivo.';
      }
      return data['error'] as String? ??
          'El envío no pudo confirmarse. Revisa la bandeja antes de reintentar.';
    } on FunctionException catch (error) {
      final details = error.details;
      return details is Map && details['error'] is String
          ? details['error'] as String
          : 'No se pudo enviar. Revisa conexión y sesión.';
    } catch (_) {
      return 'No se pudo confirmar el envío. Revisa la bandeja antes de reintentar.';
    } finally {
      await refreshUnread();
      revision++;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _userId != null) {
      revision++;
      unawaited(refreshUnread());
      if (_initialized) unawaited(registerDevice(requestPermission: false));
      notifyListeners();
    }
  }
}

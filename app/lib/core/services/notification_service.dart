import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manejador de notificaciones push en segundo plano (requerido a nivel superior por FCM)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Mensaje recibido en segundo plano.');
}

/// Servicio centralizado de Notificaciones Push con Firebase Cloud Messaging (FCM).
///
/// Firebase se utiliza ÚNICAMENTE como canal de mensajería y alertas en tiempo real,
/// mientras que los datos y perfiles se gestionan en Supabase.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Configuración Android instalada para sitra-luz; BD y Auth siguen en Supabase.
  static const bool enableFirebaseSdk = true;

  /// Activar después de completar bandeja, navegación con login y envío seguro.
  /// Instalar el SDK no implica que el flujo de notificaciones esté terminado.
  static const bool enablePushNotifications = false;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Inicializa Firebase Cloud Messaging y configura los receptores de eventos
  Future<void> initialize() async {
    if (!enablePushNotifications) {
      debugPrint('ℹ️ [NotificationService] Firebase FCM pospuesto para una fase posterior. Supabase gestiona BD y Auth.');
      return;
    }
    if (_initialized) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Solicitar permisos de notificación (Android 13+ e iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('🔔 [FCM] Permisos de notificación: ${settings.authorizationStatus}');

      // 2. Obtener el token de FCM para este dispositivo
      _fcmToken = await messaging.getToken();

      // 3. Suscribirse a cambios o renovaciones del token
      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        syncTokenWithSupabase(newToken);
      });

      // 4. Configurar receptor de mensajes en segundo plano
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 5. Escuchar notificaciones en primer plano (foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('🔔 [FCM Foreground] Notificación recibida:');
      });

      // 6. Escuchar cuando el usuario toca una notificación
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] Notificación abierta por el usuario.');
      });

      _initialized = true;
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error al inicializar FCM: $e');
    }
  }

  /// Vincula el token de FCM del dispositivo con el perfil del usuario en Supabase
  Future<void> syncTokenWithSupabase([String? token]) async {
    if (!enablePushNotifications) return;
    final activeToken = token ?? _fcmToken;
    if (activeToken == null || activeToken.isEmpty) return;

    try {
      final client = Supabase.instance.client;
      final currentUserId = client.auth.currentUser?.id;

      if (currentUserId != null) {
        await client.from('profiles').update({
          'fcm_token': activeToken,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', currentUserId);

        debugPrint('✅ [NotificationService] FCM token sincronizado con Supabase para usuario: $currentUserId');
      }
    } catch (e) {
      debugPrint('⚠️ [NotificationService] No se pudo sincronizar el FCM token con Supabase: $e');
    }
  }
}

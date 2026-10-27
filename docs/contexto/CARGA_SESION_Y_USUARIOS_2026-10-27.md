# Corrección de espera en acceso y usuarios — 27/10/2026

## Hallazgos

La versión instalada de GoTrue borra la sesión local y emite `signedOut` antes de esperar la revocación remota. El ViewModel ignoraba ese evento durante logout y mantenía el formulario de acceso en Loading mientras esperaba la red. Además, `asyncMap` podía encolar la salida detrás de una lectura lenta del perfil.

Gestión de usuarios consultaba permisos, perfiles y áreas de forma consecutiva después de comprobar Administrador. No tenía un límite de espera del listado.

## Cambios

- Se acepta el aviso de salida local durante logout y se habilita un nuevo login. La respuesta remota de una salida anterior no pisa una operación posterior.
- Los eventos de sesión ya no se encolan detrás del perfil: se descartan respuestas antiguas por revisión. Un perfil anterior no puede cerrar la sesión de otra persona.
- Cliente HTTP con límite de 20 segundos para cabeceras y períodos sin datos de Auth/REST. El límite actúa antes de que Auth procese una respuesta tardía. No se aplica a Storage ni Edge Functions.
- La lectura de perfil también tiene límite de 20 segundos. Un timeout no significa rollback de una escritura remota ni cancela una operación que el servidor ya ejecutó.
- El listado verifica primero Administrador activo y luego consulta permisos, perfiles y áreas en paralelo, conservando paginación, compatibilidad de solo lectura y validaciones. Tiene un límite global de 20 segundos, mensaje de error y reintento; descarta cambios de identidad.
- `http` 1.6.0, ya instalado como dependencia transitiva, queda declarado directamente. No se modifican esquemas ni políticas SQL.

## Verificación

Resultado final: 43 pruebas aprobadas (36 existentes y 7 adicionales); `flutter analyze --no-pub` sin incidencias.

Siete pruebas adicionales con red y repositorios simulados: logout local, respuesta remota tardía satisfactoria/fallida tras nuevo login, error recuperable, timeout antes de procesar una sesión, cuerpo HTTP detenido, signedOut durante lectura de perfil y consultas paralelas posteriores al control de Administrador. Archivo externo: `C:\Users\USUARIO\Documents\Codex\2026-10-12\te-x20\pruebas-responsive\carga_y_sesion_test.dart`.

La comprobación HTTP sin credenciales desde la computadora alcanzó el servicio remoto (401, aproximadamente 681 ms). No prueba conectividad del emulador ni autentica usuarios. No se usaron cuentas reales, no se cambiaron contraseñas, no se tomaron capturas y no se abrió un emulador.

## Comprobar en el dispositivo

Detener y volver a ejecutar `flutter run`: el cliente HTTP se configura en `main`, por lo que Hot Reload no basta. Cerrar sesión y volver a entrar; abrir Gestión de usuarios. Si sigue fallando la conexión, el formulario debe terminar con un mensaje y permitir reintentar. Anotar ese mensaje y el tiempo aproximado para separar problemas del emulador/red de errores del servidor.

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

### Diagnóstico posterior con el emulador ya abierto

Se comprobó HTTPS desde Android sin credenciales: Google respondió 204 (~1159 ms), y el endpoint público de Auth respondió 401 (~678 ms). Desde Windows, Auth con la clave pública respondió 200 (~1032 ms); REST sin sesión respondió 401 (~762 ms).

En la VM Dart de la app se hizo una petición pública a la URL raíz: un cliente HTTP nuevo produjo una respuesta; la misma petición a través del cliente compartido de Supabase permaneció pendiente en dos inspecciones separadas. No se leyeron credenciales, perfiles ni cuerpos de respuesta mediante el depurador.

La inspección remota de solo lectura no mostró conexiones bloqueadas. Se verificaron las columnas profesionales, nombres y permiso de Kits en profiles, y las firmas de `listar_permisos_kits`, `listar_usuarios_hu020`, `administrar_usuario_con_kits` y `registrar_perfil_usuario_hu021`: coinciden con las llamadas del repositorio. También se confirmó la instalación de reglas de áreas por rol y nombres con mayúsculas. No se encontró un desfase de contrato en ese flujo; no equivale a validar todas las consultas de la aplicación.

Se corrigió el transporte por defecto: usa un cliente propio por petición y lo cierra al terminar/abandonar la lectura o agotar el tiempo. El cliente general libera todos sus transportes al cerrarse. La inyección de clientes para pruebas se conserva. No reintenta escrituras ni interpreta un timeout como rollback en PostgreSQL. No cambian SQL, RLS, contraseñas ni setup.

Doce pruebas específicas aprobadas: tres de transporte (aislamiento tras timeout, cuerpo detenido y cierre), siete de sesión/listado y dos de registros seguros. `flutter analyze --no-pub` sin incidencias. Prueba nueva externa: `pruebas-responsive/transporte_aislado_test.dart` en el mismo directorio externo indicado anteriormente. Falta aceptación después de reiniciar la app; no afirmar que el login autenticado ya se probó en el dispositivo.

Detener y volver a ejecutar `flutter run`: el cliente HTTP se configura en `main`, por lo que Hot Reload no basta. Cerrar sesión y volver a entrar; abrir Gestión de usuarios. Si sigue fallando la conexión, el formulario debe terminar con un mensaje y permitir reintentar. Anotar ese mensaje y el tiempo aproximado para separar problemas del emulador/red de errores del servidor.

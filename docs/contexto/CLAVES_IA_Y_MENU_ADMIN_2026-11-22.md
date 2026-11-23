# Claves de IA y menú de administración — 22/11/2026

Implementación: `758c81c`, rama `Sprint-08`.

## Alcance acordado y aplicado

- Menú en dos columnas también en celular: icono y nombre, sin descripción ni
  «Abrir módulo». Las tarjetas permiten varias líneas sin recortar el nombre ni
  reducir los tamaños base de letra. Mantiene la paleta roja y las tarjetas claras.
- Retirados el apartado de claves de bienvenida, los controles mostrar/ocultar,
  el diálogo antiguo y sus accesos desde captura/revisión de Almacén.
- Nuevo módulo **Claves de inteligencia artificial**, ruta `/admin/claves-ia`.
  El Administrador activo es el único que puede acceder o modificar credenciales;
  la protección también se aplica en servidor, no solo ocultando botones.
- Resumen con cantidades reales de claves registradas y en uso. Cuadrícula de
  tarjetas pastel con nombre, llave, estado «En uso»/«Guardada» y última fecha
  de edición. Al tocar una tarjeta se ven las fechas y horas locales completas
  de creación/edición y las opciones para gestionar esa clave.
  Nunca muestra, revela ni copia el secreto guardado.
- Alta con entrada oculta; edición de nombre y reemplazo opcional de clave.
  Una clave en uso para todo el reconocimiento: la primera se activa; las demás
  se guardan. Cambiar la activa requiere confirmación. No se rotan por cuota
  automáticamente. Eliminar requiere confirmación y preserva auditoría; si se
  elimina la activa, se debe seleccionar otra explícitamente.
- Botón «Comprobar conexión» para la clave activa, sin revelar su valor.

## Persistencia y uso seguro

Las claves se guardan cifradas en **Supabase Vault**. `public.claves_ia` contiene
solo metadatos; los clientes tampoco tienen acceso directo a esa tabla ni a las
vistas de descifrado. La gestión se hace con RPC que comprueban Administrador
activo. `credencial_gemini_servidor()` solo se concede a `service_role`.

La Edge Function `gemini-ia` comprueba la sesión con `auth.getUser()` y el rol
activo (Administrador o Almacén) antes de utilizar una credencial en el servidor.
Su configuración desactiva la verificación JWT antigua de la pasarela porque
la función valida la sesión explícitamente; no es una función de uso anónimo.
La app conserva su prompt, fotografías y lectura estructurada; Google recibe la
misma solicitud desde servidor. No vuelve a usarse una clave incorporada al APK.

La auditoría registra actor, operación, metadatos y fechas; nunca el secreto.
Las preferencias antiguas se limpian al iniciar la aplicación. La migración puede
importar la última clave global vigente del mecanismo anterior y retira únicamente
el campo sensible de esos eventos, preservando el resto del historial. Bloquea
que versiones antiguas vuelvan a insertar ese campo en la auditoría.

Referencia técnica: [Supabase Vault](https://supabase.com/docs/guides/database/vault).

## Despliegue realizado

Proyecto `nedeqnvpkalrchswrapr` (`sitra-luz-clinica`), saludable al comprobarlo.
Migración aplicada:
`docs/supabase/migracion_claves_ia_vault_2026_11_22.sql`.
Función desplegada: `supabase/functions/gemini-ia/index.ts`.
Configuración versionada: `supabase/config.toml`.

No había eventos de configuración antigua ni una clave global para importar:
el Administrador debe añadir la primera desde el nuevo módulo. No se pidió ni
se publicó ninguna clave Gemini. No se actualizaron dependencias de Flutter.

Para una instalación nueva: ejecutar esta migración después del setup y desplegar
`gemini-ia`. No ejecutar el setup completo sobre la base existente.

## Verificación y aceptación pendiente

Comprobaciones por terminal: permisos SQL de roles ajenos, cifrado real en Vault,
CRUD, duplicados, activación única, eliminación y auditoría sin secretos; todo
dentro de una transacción revertida. Prueba externa:
`C:/Users/ASUS/Documents/Codex/2026-10-25/empe/work/claves_ia_seguridad_test.sql`.
Pasaron nueve comprobaciones Dart existentes de extracción/normalización y
limpieza local antes de que el usuario indicara que él hará las pruebas de uso.
`flutter analyze --no-pub`: sin observaciones.
`flutter build apk --debug --no-pub`: compilación Android correcta.

El usuario realizará las pruebas visuales y de reconocimiento real. No se declara
aceptación funcional completa ni se cierra HU-014/HU-015 por esta implementación.
Comprobar: dos columnas, entrada/salida del módulo, alta de dos claves propias,
reemplazo, cambio de activa, eliminación, fechas, permisos y una captura que antes
funcionaba. Reiniciar la app con **R** en la terminal Flutter para cargar rutas e
inicialización nuevas antes de probar. Retomar después HU-003.

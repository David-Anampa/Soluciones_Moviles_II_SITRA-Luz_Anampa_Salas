# Restablecimiento administrativo y selector de áreas — 27/10/2026

## Contraseña

En Administrador → Gestión de usuarios → Editar usuario → Acceso aparece **Restablecer contraseña**. Es una acción separada de Guardar cambios del perfil.

El modal identifica al usuario y pide nueva contraseña y repetición. Exige al menos 8 caracteres, una letra y un número; limita a 72 bytes. No muestra la contraseña anterior. El envío bloquea doble pulsación y cierre hasta recibir respuesta. Cancelar no cambia credenciales. El éxito confirma el cambio sin guardar los cambios pendientes del perfil.

La app llama a `restablecer-clave`. En el servidor se verifica el token con Auth y que el perfil solicitante sea Administrador activo. Se comprueba que el destinatario exista; se utiliza `auth.admin.updateUserById` con service-role solo en el servidor. No se almacena contraseña en profiles, auditoría, respuestas ni logs del código.

Referencia de la API: [Supabase — updateUserById](https://supabase.com/docs/reference/javascript/auth-admin-updateuserbyid).

Se registra una solicitud previa en la auditoría existente. Si falla, no se llama a Auth. Después se registra resultado satisfactorio o fallido, enlazado por operación, actor y destinatario. Auth y PostgreSQL no comparten una transacción: si la contraseña cambió y el registro final falla, la respuesta indica éxito con advertencia explícita; la solicitud previa queda disponible para revisión. No se afirma que se revirtió la contraseña ni se recomienda repetir el cambio en ese caso.

No implementa contraseña temporal, caducidad, cambio obligatorio al siguiente acceso ni cierre forzado de sesiones existentes. No modifica correo, estado o rol del perfil.

## Despliegue requerido

Desde la raíz del repositorio, con Supabase CLI autenticado:

```powershell
supabase functions deploy restablecer-clave --project-ref nedeqnvpkalrchswrapr
```

También puede desplegarse desde el editor de Edge Functions del Dashboard de Supabase usando `supabase/functions/restablecer-clave/index.ts` como código de la función `restablecer-clave`.

Se utilizan las variables de entorno del servidor `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY`, igual que en crear-usuario. No copiar la clave service-role a Flutter. Conservar la verificación JWT del despliegue.

**Actualización del 27/10: función desplegada por solicitud del usuario.** `restablecer-clave` está ACTIVE, versión 1, en `nedeqnvpkalrchswrapr`, con verificación JWT habilitada. Se desplegó mediante la API de Supabase, sin Docker. Una solicitud sin sesión devolvió HTTP 401. No se cambiaron contraseñas reales: queda pendiente verificar el cambio autenticado desde la app con una cuenta de prueba.

No requiere nueva migración SQL: utiliza `auditoria_trazabilidad` y sus columnas/eventos de texto existentes. Por eso no cambia el setup. La migración anterior de nombres de usuario sigue siendo independiente.

## Áreas asignadas

Crear/Editar usuario ahora abre un selector múltiple con buscador por nombre/código, búsqueda sin acentos y casillas. La selección es un borrador: Aplicar selección la confirma en el formulario; Cancelar la descarta. Guardar usuario sigue siendo necesario para persistirla.

Las áreas seleccionadas se muestran como etiquetas removibles. Se conservan asignaciones históricas a áreas deshabilitadas; una deshabilitada no se puede seleccionar de nuevo si se retiró. Las opciones y la validación de servidor existentes no cambian.

## Validación local

- `flutter analyze --no-pub`: sin incidencias.
- 8 pruebas de widgets: contraseñas distintas no se envían; coincidencia/envío/cierre; búsqueda de áreas, cancelación y aplicación. Cuatro tamaños con escala de texto y teclado simulado.
- 14 casos del handler TypeScript con Auth/auditoría simulados: sesión, rol, perfil activo, política de clave, destinatario, fallo de auditoría previo, rechazo Auth, éxito y advertencia parcial, método y CORS.
- Pruebas externas en `C:\Users\USUARIO\Documents\Codex\2026-10-12\te-x20\pruebas-responsive\administracion_acceso_test.dart` y `restablecer_clave_backend_test.cjs`.

Estas pruebas no sustituyen el despliegue ni certifican el runtime Deno remoto. Verificar con una cuenta de prueba: restablecer como Administrador, cerrar la sesión del destinatario y entrar con la nueva clave; la anterior debe rechazarse. Comprobar eventos en auditoría y que otro rol reciba rechazo del servidor. En áreas: buscar, aplicar, guardar y reabrir para comprobar persistencia; cancelar el selector debe conservar lo anterior.

# Acceso por correo o nombre de usuario — 27/10/2026

## Comportamiento

Acuerdo final de la sesión: temporalmente aceptar correo o nombre de usuario con contraseña, porque las cuentas de prueba usan correo. Cuando se incorporen los usuarios finales, la interfaz deberá pasar a usuario y contraseña. Esa transición futura no se aplica todavía. El correo seguirá siendo el identificador interno de Supabase Auth, aunque luego no se solicite en el formulario.

El campo de acceso acepta **Correo o nombre de usuario**. Con correo conserva el acceso directo a Supabase Auth. Con nombre usa `login-usuario`, que encuentra el correo únicamente en el servidor y verifica la contraseña con Auth.

Los nombres no distinguen mayúsculas/minúsculas. Se escapan los comodines de ILIKE para que un guion bajo sea literal. Se permiten identificadores numéricos históricos al iniciar sesión; la regla actual de creación de nombres sigue exigiendo una letra. No se aplica la longitud mínima de contraseñas nuevas al login, para conservar accesos históricos válidos.

Después del éxito, Flutter recupera la sesión emitida por Auth y consulta su perfil activo/rol con las mismas reglas actuales. No registra tokens ni credenciales en logs. La respuesta del servidor tiene `Cache-Control: no-store`. Una cuenta inexistente, deshabilitada o con contraseña incorrecta obtiene el mismo rechazo, sin publicar el correo.

## Servidor y publicación

Código preparado en `supabase/functions/login-usuario/index.ts`. El servidor usa service-role solo para resolver el perfil; el acceso se realiza con la clave pública y `auth.signInWithPassword`. La sesión solo se devuelve si la identidad coincide y el perfil sigue habilitado. No se añaden permisos SELECT anónimos sobre profiles ni funciones SQL públicas de resolución.

`supabase/config.toml` configura `verify_jwt = false` solo para `login-usuario`: es un endpoint de autenticación, invocado antes de tener sesión. Eso no elimina la comprobación de contraseña ni cambia la verificación JWT de crear/restablecer usuarios u otras funciones.

**Publicación pendiente de autorización explícita.** La revisión automática rechazó el intento de despliegue porque crea un endpoint público sin JWT previo. El código queda preparado y probado para revisión; no se publicó por otra vía. El acceso por correo sigue disponible. Para usar nombres de usuario falta publicar la nueva función.

No requiere migración ni actualización de setup porque utiliza `profiles.nombre_usuario` y la unicidad existentes sin modificar el esquema. No soluciona por sí mismo el problema de conectividad que se estaba investigando.

## Validación

Cinco pruebas del datasource con HTTP simulado: usuario en ambas cajas, guion bajo, correo directo, recuperación de sesión y rechazo sin consulta de perfiles. Quince casos del handler con Auth simulado: usuario válido/inexistente/inactivo, error de clave, límite de intentos, fallo de consulta, baja durante el acceso, identidad distinta, comodines, entrada vacía y método/CORS. No se inició sesión con cuentas reales durante esta entrega.

Referencia: [Supabase — signInWithPassword](https://supabase.com/docs/reference/javascript/auth-signinwithpassword).

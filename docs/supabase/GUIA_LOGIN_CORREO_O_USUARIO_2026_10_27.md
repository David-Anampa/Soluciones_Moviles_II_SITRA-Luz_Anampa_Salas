# Acceso por usuario retirado — 27/10/2026

Por solicitud del usuario, el login vuelve a aceptar únicamente **correo institucional y contraseña** mediante Supabase Auth.

Se eliminaron la función no desplegada `login-usuario` y su configuración local. No se cambiaron perfiles, contraseñas, áreas, Kits, roles ni funciones SQL. Crear/restablecer usuarios conserva sus funciones existentes.

El arranque vuelve a usar el cliente HTTP predeterminado del SDK, sin inyectar `ClienteHttpConLimite`. Se mantienen los registros seguros de las fases y las protecciones de sesión. Retirar el acceso por usuario no demuestra por sí solo que se haya resuelto el problema de conexión.

Verificación: 38 pruebas aprobadas (36 existentes y dos de acceso solo por correo), análisis limpio y APK debug compilado, instalado y abierto en el emulador existente. El formulario rechaza nombres de usuario; el datasource llama a Auth por correo y no invoca Edge Functions de login. Estas pruebas usan datos simulados. Falta confirmar un acceso real con credenciales introducidas por el usuario.

No requiere migración SQL ni cambios en el setup.

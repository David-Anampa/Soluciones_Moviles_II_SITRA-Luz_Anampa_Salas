# Nombre de usuario — 27/10/2026

Se aceptan nombres en mayúsculas, minúsculas o mezclados, con números opcionales y al menos una letra ASCII. Se conserva la longitud de 3 a 32 caracteres y los separadores existentes (punto, guion y guion bajo), sin permitir espacios internos ni empezar con separador.

Ejemplos válidos: `ABC`, `WALTER`, `walter`, `Walter25`, `123A`, `ana.perez`.
Ejemplos inválidos: `12345`, `12_-`, `ab`, `ana perez`.

La escritura conserva las mayúsculas elegidas. La unicidad sigue siendo insensible a mayúsculas: `Walter` y `walter` no pueden pertenecer a usuarios diferentes. El acceso se mantiene únicamente por correo y contraseña; se retiró el login por nombre por solicitud expresa. El nombre de usuario sigue siendo un dato del perfil.

## Aplicación en Supabase existente

Ejecutar `migracion_nombre_usuario_mayusculas_2026_10_27.sql` en SQL Editor, después de las migraciones vigentes de usuarios y Kits por área. No ejecutar el setup completo para actualizar una base existente.

La migración sustituye la validación compartida de alta/edición y el CHECK del nombre de usuario. Conserva roles, áreas, validaciones profesionales y el índice de unicidad. No modifica contraseñas ni renombra cuentas existentes.

Los nombres históricos sin letras se conservan mediante un CHECK `NOT VALID`; al actualizar esos perfiles deberán corregirse al nuevo formato. No se ha ejecutado esta migración en Supabase durante esta entrega. El setup se actualizó con las mismas reglas para reconstrucciones.

## Verificación

Como Administrador, crear o editar usando `WALTER` y comprobar que se conserva esa escritura; probar `12345` y verificar rechazo. Intentar otro usuario `walter` cuando exista `WALTER`: debe impedir el duplicado. El login por correo debe seguir funcionando.

Los comentarios y pruebas del formulario reflejan la misma regla. Las pruebas de Dart no certifican por sí solas el despliegue o la ejecución de PostgreSQL.

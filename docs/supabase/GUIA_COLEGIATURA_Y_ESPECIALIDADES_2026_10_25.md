# Usuarios: correo único, colegiatura y especialidad

Actualización: 25 de octubre de 2026.

## Formulario

- Un solo correo electrónico para acceso y futura vinculación con Drive.
- Rol de permisos y un único campo «Cargo / ocupación»; no se agrega «Profesión».
- Colegio profesional opcional; al elegirlo se solicita su número de colegiatura.
- Especialidad opcional filtrada por colegio. Para CTMP se identifica como área
  profesional, conservando la distinción respecto de una segunda especialidad.
- Rojo, blanco y gris del tema existente, tarjetas con separación e iconos Material.
- Colegiatura y especialidad son datos de referencia: no conceden permisos ni
  acreditan por sí mismas habilidad profesional. Los médicos siguen siendo
  referencias para fichas; no se crea un nuevo rol de médico.

## Catálogos y fuentes

Se insertaron en el proyecto Supabase `nedeqnvpkalrchswrapr` cuatro colegios y
64 opciones: CMP 48, CEP 8, CQFP 2 y CTMP 6. Cada fila conserva su fuente oficial.
Es una selección amplia para UCI, sala de operaciones, emergencias y hospitalización,
incluida atención pediátrica/neonatal; no se presenta como un listado exhaustivo
de todas las especialidades reconocidas en Perú ni como una asignación normativa
de especialidades a servicios clínicos.

- CMP y consejos regionales: https://cmp.org.pe/consejos-regionales-2/
- Especialidades médicas: https://medicina.usmp.edu.pe/posgrado/segunda-especialidad/programas-curriculares-2025/
- Cirugía cardiovascular y torácica: https://www.conareme.org.pe/web/proceso-de-admision-2026.php
- Enfermería: https://www.cep.org.pe/ y https://www.essalud.gob.pe/wp-content/uploads/disp_compl_residet_enfermeria_2023.pdf
- Farmacia: https://cqfp.pe/transparencia/ y https://farmacia.unmsm.edu.pe/formacion-academica/posgrado
- Tecnología Médica: https://ctmperu.org.pe/areas/

No se agregan los consejos regionales como colegios profesionales distintos.
Los números se almacenan como texto para conservar ceros iniciales.

## Despliegue y orden de migraciones

1. HU-012: ya se verificaron sus objetos en remoto.
2. `migracion_hu020_estructura_usuarios_2026_10_15.sql`: pendiente.
3. `migracion_hu021_hu022_gestion_usuarios_2026_10_22.sql`: pendiente.
4. `migracion_hu020_hu021_hu022_correo_unico_2026_10_25.sql`: pendiente.
5. `migracion_catalogos_profesionales_2026_10_25.sql`: aplicada, con conteos
   confirmados mediante lectura. Es independiente de HU-020/HU-021.
6. `migracion_hu020_hu021_hu022_colegiatura_2026_10_25.sql`: pendiente.

Los scripts nuevos están incorporados al final de `setup_sitra_luz.sql`.
El setup completo es solo para una base nueva. No ejecutarlo sobre la base actual.
La columna heredada `correo_drive` no se borra ni se utiliza en el formulario.

El cliente comprueba el contrato del listado antes de crear o editar, para evitar
que las RPC anteriores descarten silenciosamente los nuevos campos. La Edge
Function `crear-usuario` sigue requiriendo confirmación de despliegue independiente.

## Validación realizada

Se revisaron los cambios y se formatearon los archivos Dart. Se comprobó que
Git no reporta errores de espacios y se verificaron los conteos remotos del catálogo.
No se ejecutaron pruebas, Flutter analyze ni una nueva compilación para estos cambios.
La apariencia final y el guardado completo necesitan validación en el emulador
después de completar las migraciones pendientes.

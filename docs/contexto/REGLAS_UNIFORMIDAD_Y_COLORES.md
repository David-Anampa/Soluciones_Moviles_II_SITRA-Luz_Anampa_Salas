# Uniformidad visual y colores de SITRA-Luz

Acuerdos del usuario consolidados el **24/11/2026**. Consultar antes de cualquier
cambio de interfaz. Este documento registra el diseño que debe conservarse;
no certifica que todas las pantallas heredadas ya lo cumplan.

## Colores por módulo

| Módulo | Color principal | Aplicación |
| --- | --- | --- |
| Farmacia | Verde `#00796B` | Cabeceras, botones, iconos y selección de filtros; fondos verdes pastel. |
| Enfermería | Rojo `#C62828` | Sus vistas y la consulta/gestión compartida de kits. |
| Almacén | Naranja `#E65100` | Identidad de Almacén; misma estructura visual que Farmacia. |
| Jefatura de Farmacia | Azul `#1A3A6B` | Identidad de supervisión. |
| Administración | Rojo `#C62828` | Menú y gestión administrativa acordados con el usuario. |

Usar tonos suaves derivados del principal para fondos, y tonos oscuros legibles
para iconos/textos sobre pastel. Las cabeceras de color usan letras e iconos
blancos. Las tarjetas de contenido conservan fondo blanco y bordes suaves.

**Deuda heredada:** `AppColors.adminColor` todavía declara morado y
`AppColors.primary`/el fallback de `TemaPedidos.colorRol` son azules. No tomar esos
fallbacks como una nueva decisión del usuario para Administración o Farmacia.
No cambiar toda la paleta global indiscriminadamente para corregir una pantalla.

## Módulo visual y permisos son cosas diferentes

- Entrar a Farmacia desde Administración debe mostrar verde aunque la identidad
  autenticada siga siendo ADMINISTRADOR.
- En componentes compartidos, la apariencia sigue el módulo desde el que se
  accede: kits verde para Farmacia y rojo para Enfermería. No crear copias de los
  kits ni de sus datos por el color.
- `TemaPedidos.rolActual(context)` resuelve el ámbito **visual** mediante la ruta
  del módulo y el origen de kits (`/kits?vista=FARMACIA` o `ENFERMERIA`), con la
  sesión como fallback. Nunca usarlo para habilitar permisos o filtrar datos.
- Los permisos reales siguen usando AuthViewModel/contexto del servidor y SQL.
- Revisar también las rutas hijas, ventanas de confirmación, filtros y estados
  de carga; cambiar solo la cabecera no completa la uniformidad.

## Excepción del detalle clínico

La vista general **Atender pedidos de áreas** pertenece a Farmacia y usa verde.
El código y la identificación del área pueden conservar su color propio.
Al abrir **Revisar pedido**, el fondo suave y la cabecera identifican el área
solicitante, manteniendo las tarjetas blancas. No extender el color de esa área
al listado general de Farmacia.

Rojo de error, anulación y advertencia justificada es semántico: no sustituirlo
por verde solo para teñir toda la pantalla. Urgencia debe seguir siendo visible.

## Componentes y tipografía

- Reutilizar `TemaPedidos`, `CabeceraMenu`/`FranjaPedidos`, `BotonModulo`,
  `CuadriculaPanel`, `DisenoAdaptable` y componentes de stock existentes.
- Separar secciones con **franja horizontal**, color del módulo, icono y texto
  blanco, esquinas redondeadas y separación vertical. Evitar subtítulos sueltos.
- Menús en dos columnas cuando el ancho lo permite: tarjeta pastel, borde blanco,
  círculo blanco para el icono y nombre comprensible. En Farmacia, icono verde
  oscuro. No añadir descripciones ni etiquetas redundantes como «Abrir módulo».
- Conservar la tipografía y el tamaño ya usados; botones y cuerpo alrededor de
  14 px, franjas alrededor de 15 px según el componente existente. No reducir
  letras para resolver desbordamientos ni bloquear la escala de texto de Android.
- Botones con iconos adecuados, etiquetas breves, área táctil mínima de 48 px y
  separación suficiente. Separar **Revisar pedido** de los resúmenes de cantidades.
- **Acuerdo vigente:** agregar productos y aumentar cantidades usan el color
  del módulo con el «+» blanco, verde en Farmacia. Esto sustituye la solicitud
  anterior de pintarlos rojos.
- Quitar referencias HU/RF y explicaciones de implementación de los textos de
  interfaz. Conservar instrucciones necesarias para cantidades, faltantes,
  cobertura, diferencias y justificaciones.

## Campos y adaptación a celulares

- Dar ancho y alto acordes al dato: nombres, médicos, receptores y laboratorios
  largos deben poder leerse; diagnóstico y observaciones admiten varias líneas.
- Campos en una columna en teléfonos estrechos y con letra ampliada. Agregar
  columnas solo si cada campo mantiene espacio suficiente.
- Dropdowns con estilos del módulo, contenido expandido y valores válidos. No
  seleccionar un área antes de que exista en sus opciones; sincronizar el estado
  del campo al cargar catálogo, cambiar filtros o restablecerlos.
- Detalles largos deben desplazarse verticalmente. Nunca ocultar las franjas
  amarillas/negras de overflow recortando contenido o reduciendo tipografía.
- Evitar que botones flotantes tapen el último registro o las acciones.

## Comportamientos de presentación conservados

- Solicitar a Almacén: tres resultados por página, búsqueda en todo el catálogo
  cargado, anterior/siguiente y filtro de laboratorio editable con sugerencias.
  Los productos seleccionados y sus cantidades se conservan al buscar.
- Registro clínico: Neonatología / Otras áreas, usando el catálogo autorizado;
  Otras áreas muestra su dropdown. No crear áreas ni alterar permisos para el UI.
- Registrar pedido se presenta como botón flotante, con el permiso existente.
- El nombre del botón del menú coincide con el título de su vista principal.
  Los subflujos pueden tener títulos específicos que describan su acción.
- Leer una notificación no atiende un pedido. La bandeja de prueba y el flujo
  operativo son distintos; no declarar terminados los avisos automáticos reales.

## Verificación de cada cambio

Revisar consistencia entre inicio, destino, filtros seleccionados/no seleccionados,
modales, carga y error; considerar Farmacia abierta desde Administración y kits
desde Enfermería. Ejecutar `flutter analyze --no-pub` desde `app`. No afirmar
aceptación visual o funcional si no se observó: el usuario realiza esas pruebas.
No modificar stock, auditoría ni permisos como parte de un retoque visual.
Agrupar cambios importantes en commits y mantener este acuerdo actualizado.

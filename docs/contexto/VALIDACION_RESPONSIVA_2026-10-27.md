# Validación automatizada — 27 de octubre de 2026

Rama: `Sprint-05`. Resultado final: **68 pruebas aprobadas y flutter analyze sin incidencias**.

## Alcance ejecutado

- 36 pruebas existentes: validadores de Kits y usuarios, pantalla inicial y flujo de pedidos mediante repositorios simulados. Incluyen cancelación con motivo, bloqueo durante preparación, rechazo, recepción conforme, devolución y validaciones de despacho.
- 12 pruebas adicionales: modal con texto extenso, entrada de observación y confirmación alcanzable; expansión de tarjeta de Kit, laboratorio y cantidad completos, eliminación con confirmación; desplazamiento de tabla conservando cantidades.
- 20 pruebas adicionales: construcción y desplazamiento de los paneles de Administrador, Almacén, Farmacia, Enfermería y Jefatura, con usuario de nombre extenso y datos simulados.

Las 32 pruebas adicionales cubren cuatro escenarios de tamaño lógico, escala de texto e inset de teclado simulado:

| Pantalla | Escala de texto | Teclado simulado |
| --- | --- | --- |
| 320 × 568 | 1,0 | 0 |
| 320 × 568 | 2,0 | 240 |
| 640 × 360 | 1,3 | 140 |
| 412 × 915 | 2,0 | 300 |

## Fallos encontrados y correcciones

1. Tres comprobaciones de pedidos buscaban el antiguo `AlertDialog`; ahora comprueban el `Dialog` real. Se mantienen las aserciones sobre acciones, cantidades y errores.
2. Una prueba de despacho intentaba tocar la confirmación fuera de pantalla. Ahora desplaza el modal antes de tocarla y sigue verificando que no se puedan despachar cero unidades.
3. La expectativa de serialización del usuario no incluía `puede_gestionar_kits: false`; se actualizó al contrato vigente.
4. Desbordamiento real en composición de Kits con 320 píxeles y texto al doble: la cantidad ahora pasa debajo del detalle cuando falta ancho, mediante `FilaDetalleAdaptable`.
5. Dos desbordamientos reales del panel de Almacén: distintivo del encabezado y título/conteo del inventario. Las filas permiten reorganizar el contenido con `Wrap`.

## Repetición local

Desde la carpeta `app`:

```powershell
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
```

Las pruebas adicionales de esta sesión están fuera del repositorio, en esta computadora:

`C:\Users\USUARIO\Documents\Codex\2026-10-12\te-x20\pruebas-responsive`

Para repetirlas desde `app`:

```powershell
flutter test --no-pub --concurrency=1 "C:\Users\USUARIO\Documents\Codex\2026-10-12\te-x20\pruebas-responsive\responsive_smoke_test.dart" "C:\Users\USUARIO\Documents\Codex\2026-10-12\te-x20\pruebas-responsive\dashboards_test.dart"
```

## Límites

Son pruebas unitarias y de widgets. No se abrió emulador ni se tomaron capturas. No se realizaron operaciones contra Supabase. Los resultados no certifican transacciones SQL, políticas de acceso en servidor, cámara, teclado nativo, rendimiento del dispositivo ni todos los formularios y rutas con datos reales. Falta aceptación visual y funcional en el celular, incluyendo guardar formularios y completar pedidos contra una base de pruebas.

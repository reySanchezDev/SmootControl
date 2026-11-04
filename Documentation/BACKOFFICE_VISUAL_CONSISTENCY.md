# Reglas globales de consistencia visual — SmooControl Backoffice V2

**Alcance:** toda la interfaz administrativa: listados, filtros, formularios, diálogos, reportes y pantallas futuras. No aplica a controles táctiles POS salvo aprobación específica.

## Reglas obligatorias

1. **Espaciado de formularios:** 12 px lógicos entre campos consecutivos, 16 px entre grupos/secciones y un margen interior consistente de 16 px. No colocar `TextField`, `AppInput` o `DropdownButtonFormField` verticalmente adyacentes sin separación. Para formularios antiguos, revisar los diálogos afectados y migrarlos gradualmente al componente común.
2. **Congruencia de dimensiones:** el mismo control cumple la misma función con el mismo ancho máximo en todas las pantallas. Referencia única en `BackofficeFormStandards`: búsqueda 440 px, fecha individual 210 px, filtro/select 260 px; separación de filtros 12 px. En móvil usar espacio disponible y evitar overflow. Los filtros se alinean al **inicio** del área de contenido; no centrar controles individuales a lo largo de toda la ventana ni estirarlos indiscriminadamente.
3. **Búsqueda en tablas:** utilizar `AppSearchField` / `BackofficeCollectionView` y respetar ancho de 440 px. No duplicar búsqueda al existir otra con el mismo propósito.
4. **Acciones visibles:** comandos de página y listas editables con **icono + verbo claro** (p. ej. `Registrar compra`, `Ajustar inventario`, `Guardar`, `Editar`). Un `tooltip` no reemplaza a la etiqueta visible. Evitar menús genéricos `Más`/`Opciones`, botones solo icono para acciones de negocio y columnas repetitivas `Acciones`. Excepciones justificadas: controles universales de navegación/cierre y accesibilidad.
5. **Tablas y selección:** conservar encabezado fijo, búsqueda, ordenación, paginación y comandos por selección. Cambiar presentación **no habilita** alterar contratos de pago, inventario, marcadas ni permisos. Documentar cualquier interacción distinta a la anterior y validarla antes de aprobarla.
6. **Diálogos:** anchura proporcionada, altura desplazable, contenidos siempre visibles con espaciado 12 px; si no hay datos para construir el editor, informar al usuario claramente en vez de abrir una ventana en blanco.
7. **Reportes:** módulo especializado con catálogo organizado por categorías y **opciones nombradas en lista**, no una cuadrícula de tarjetas grandes. Mantener las rutas y procesos PDF existentes. El componente de navegación debe diferenciar claramente catálogo de reportes y contenidos de reportes.
8. **Responsividad:** revisar 390 px, 1366×768 y 1920×1080. No inferir que `flutter analyze` valida la apariencia; se requieren capturas/inspección manual real.
9. **Alcance global:** una observación encontrada en una pantalla exige buscar el mismo patrón en las demás y actualizar el componente compartido si corresponde. Nunca limitar la corrección al primer ejemplo.
10. **QA incremental:** pruebas del componente y casos de navegación afectados; regresar a suite completa y build oficial al cierre de fase/release, o si cambia código compartido de alto riesgo.

## Criterio de aceptación del lote

- Editar unidad: campos separados de forma legible.
- Búsqueda de Productos y Modificadores: mismo máximo visual.
- Inventario: acciones superiores etiquetadas e ilustradas.
- Movimientos: filtros fecha/tipo alineados y tamaños estables.
- Ventas: fecha alineada a la izquierda, con comando explícito.
- Marcadas: editor nunca presenta contenido vacío por lista de empleados faltante.
- Reportes: lista por categoría con nombres claros y rutas intactas.
- Revisión transversal pendiente en otras pantallas y diálogos; no declarar cobertura integral sin auditar cada pantalla.

## Regla de no regresión funcional — obligatoria

El trabajo F3 es **exclusivamente de presentación**. Está prohibido modificar las condiciones para abrir formularios, los datos que se cargan, filtros del repositorio, validaciones de dominio, persistencia, autorización, cálculos, navegación funcional o contratos de callbacks sin aprobación explícita. La posición de los controles puede cambiar, pero sus comportamientos existentes deben ser equivalentes.

**Incidente Marcadas:** se introdujo una comprobación adicional de empleados que impedía editar registros existentes; la condición fue retirada y `_openEditor`, `_load` y la lista de empleados fueron restaurados exactamente desde la versión base `b3fddd4a` mediante el commit `8d67daba`. La corrección visual de posición de comandos se conserva. Esto **no demuestra** que la pantalla en blanco original esté resuelta; requerirá reproducir el fallo y diagnosticarlo con evidencia antes de proponer cambios funcionales, sujetos a autorización.

En cada lote: comprobar `git diff` por archivo contra la base y separar mejoras visuales de cualquier cambio de comportamiento. Ante un cambio de comportamiento no aprobado, revertirlo, no adaptarlo silenciosamente.

## Excepción funcional autorizada — Marcadas (2026-11-04)

**Autorización expresa del propietario:** corregir exclusivamente la resolución de empleados de Marcadas, preservando el diseño V2. La investigación demostró que `AttendanceAdminPage` utilizaba `IStaffRepository`, enlazado por DI a `StaffPosRepository` (Drift local), mientras Personal consultaba `SupabaseStaffAdminRepository` remoto.

**Corrección:** Marcadas usa ahora `serviceLocator<SupabaseStaffAdminRepository>()` localmente, sin alterar el binding de `IStaffRepository`, POS, Time Clock, los servicios RPC de marcadas, el formulario ni el servicio de guardado. La lista remota completa permite resolver el `AttendanceEntry.employeeId` contra `Employee.id`, incluso si el empleado histórico está inactivo. Para crear marcadas se mantienen solo empleados activos. Si no se encuentra el ID original, el comando Editar queda inhabilitado y no se asigna una persona arbitraria.

**Pruebas añadidas (pendientes de ejecución):** empleados activos, empleados inactivos históricos, ID inexistente y catálogo vacío. La certificación del defecto requiere además abrir el formulario en Web V2 con un registro real **sin pulsar Guardar**, revisar ID/identidad, campos y Cancelar; pruebas de escritura solamente con datos ficticios.

No utilizar esta excepción como autorización para cambiar flujos de otras pantallas.

## F3 — Lote de consistencia global de diálogos y comandos (2026-11-04)

La inspección de componentes compartidos detectó problemas de ancho y espaciado en formularios de **Personal**, **Unidades**, **Vacaciones** y **Marcadas**, además de comandos móviles duplicados y exclusivamente icónicos en **Unidades**. Se aplicaron las siguientes reglas reutilizables:

- `BackofficeFormStandards.dialogWidth = 520` px lógicos (límite preferido, no ancho mínimo en móvil), `wideDialogWidth = 680`, `fieldGap = 12`, `sectionGap = 16`.
- Los cuatro diálogos administrativos mencionados contienen su área desplazable dentro de `SizedBox(width: dialogWidth)`, permitiendo que `AlertDialog` se ajuste al espacio disponible en móvil.
- El formulario de Personal incorpora separadores entre Nombre, Puesto, Turno, Salario, Foto y bloque de estado.
- Vacaciones incorpora separación entre selector, rango de fechas, Tipo, aprobación y Nota.
- Unidades conserva su lógica y campos, pero utiliza ancho común; en móvil las tarjetas ya no ofrecen `IconButton` Editar/Inactivar duplicados: se usan las acciones explícitas de la barra de selección.
- Marcadas conserva íntegros la selección de empleado, fecha, hora, `_save` y callbacks: solo se ajusta ancho y el primer espacio entre controles.

**Inventario de auditoría de componentes inspeccionados:** `AppPageScaffold`, `AppSearchField`, `BackofficeCollectionView`, `BackofficeSelectionToolbar`, `BackofficeFormStandards`, `ResponsiveTouchDialogFrame`; vistas: Unidades, Personal, Marcadas, Vacaciones, Configuración, Caja y Reportes. En especial, `AppPageScaffold.actions` y `BackofficeCollectionView.selectionActions` pueden crear dos zonas de comandos en otras vistas; esta deuda debe resolverse por pantalla para no mover operaciones del POS ni confundir acciones globales con acciones seleccionadas.

**No se declara cobertura global terminada:** continúan pendientes de inspección pantalla por pantalla Caja, Tasas, varios diálogos de personal, reportes, empaques y movimientos. La revisión visual en 390/1366/1920 sigue pendiente. No usar este lote para afirmar regresión funcional aprobada.

**QA proporcional requerido ahora:** `dart format` sobre archivos del lote, `flutter analyze`, y pruebas focalizadas de diálogos y selección móvil de Unidades. No repetir 138 pruebas ni construir Web por cambios de espaciado; compilar una vez al preparar revisión visual del lote completo. No publicar si falla el análisis. Ningún servicio ni repositorio fue modificado en este lote.

## F3 — Continuación de Caja y Tasas de cambio (2026-11-04)

Base anterior confirmada por Codex: `deafa566c0817d5a0adfd830424c3877294fb608`, `flutter analyze` limpio, selección de empleados de Marcadas 4/4; no hay aún tests de widget localizados para Personal, Unidades ni Vacaciones.

**Caja:** filtros Desde/Hasta utilizan el ancho de fecha compartido de 210 px, separación de 12 px y etiquetas explícitas. Editor de sesión adopta ancho preferido de diálogo 520 px y separación del diseño global. Se conservaron `_pickDate`, los callbacks de edición y eliminación, `_submit`, el servicio remoto y las validaciones monetarias.

**Tasas de cambio:** navegación entre meses mediante controles con icono y etiqueta visible dentro del módulo (en vez de flechas aisladas en el encabezado). El período sigue siendo visible; el campo de tasa mensual deja de expandirse indefinidamente y utiliza máximo de filtro compartido de 260 px en escritorio. Se conservaron `_previousMonth`, `_nextMonth`, `_applyMonthRate`, `_saveRate` y sus repositorios. La edición de importes diarios no se modificó.

**QA incremental requerido:** formatear solo archivos tocados de Caja/Tasas, ejecutar `flutter analyze` y pruebas focalizadas existentes de vistas de Caja/Tasas sin datos reales. No ejecutar regresión general ni build hasta cerrar el lote visual. Continúa pendiente auditoría del resto de diálogos de nómina, Gastos, inventario, roles y permisos, usuarios y reportes; no declarar F3 concluida.

## Excepción funcional autorizada — Tasas de cambio como hoja de cálculo (2026-11-04)

El propietario autorizó explícitamente modificar **solo el guardado diario de tasas** para que cada campo se persista automáticamente al abandonar la celda (clic en otra celda, Tab o Enter), sin botón Guardar por registro. Se preserva **Aplicar al mes** como acción manual para asignar una tasa única a todo el mes.

Implementación en `ExchangeRateTile` y `ExchangeRatesPage`:
- Guarda únicamente valores modificados, numéricos y positivos, sin duplicar solicitudes al salir del campo y pulsar Enter.
- Mantiene el valor escrito en caso de error, mostrando una explicación visible en el propio campo. Muestra `Guardando…` y `Guardado` solo después de recibir un resultado remoto correcto.
- No ejecuta `_load()` después de guardar una tasa individual, para no perder foco ni interrumpir la edición de la siguiente celda.
- Si el usuario edita de nuevo mientras existe una petición, los cambios se envían en secuencia al terminar la anterior, sin sobrescribir el último valor silenciosamente.
- El cambio de mes y la operación masiva esperan las escrituras diarias en curso antes de proceder. `fillMonth` sigue siendo explícito y muestra los errores del servidor.
- Se conserva el repositorio `saveRate`, modelo `ExchangeRate`, validaciones de moneda y transacciones existentes, sin cambiar API ni SQL.

**QA focalizado:** `test/features/exchange_rates/presentation/pages/exchange_rate_tile_test.dart`: autoguardado al perder foco, ausencia de guardado si no se cambia el valor, falla remota preservando el texto y rechazo de valor cero. Pendientes de ejecución por Codex. Además revisar manualmente Tab/Enter, navegación mensual, concurrencia y las pantallas compactas 390 px antes de aprobar. No afirmar validación sin resultado de pruebas.

### Corrección del autoguardado focalizado — 2026-11-04

Codex reportó `flutter analyze` con 3 observaciones (`discarded_futures`, `unawaited_futures`, `avoid_catches_without_on_clauses`) y prueba de celda 1/4. La causa de las tres aserciones fallidas es que pulsar un botón externo no implica necesariamente perder el foco en Flutter; el componente dependía exclusivamente del listener de `FocusNode`. Se añadió `TextField.onTapOutside` para disparar `_commit()` al tocar fuera, además de mantener focus loss y `onSubmitted` como eventos de teclado. Se envolvieron explícitamente los Futures no esperados en `unawaited`, se importó `dart:async` y se restringió `catch` a `on Object`. No cambió el servicio de persistencia ni `fillMonth`.

**Estado:** implementación publicada, **pendiente** de que Codex ejecute de nuevo `flutter analyze` y solo `exchange_rate_tile_test.dart`. No ejecutar build ni regresión completa hasta validación focalizada limpia.

### Ajuste posterior observado en navegador: Tab/Enter saltaba al sidebar

El usuario confirmó en Chrome que el guardado diario funciona pero Tab/Enter podía enfocar la opción **Marcadas** del sidebar. Las pruebas anteriores solo ejercitaban un formulario aislado y no reprodujeron el orden de foco de todo el workspace.

Se corrigió exclusivamente la navegación de teclado de Tasas:
- `ExchangeRatesPage` administra 31 `FocusNode` estables y los libera en `dispose`. Cada fila recibe referencias explícitas a la celda diaria anterior y siguiente.
- `ExchangeRateTile` redirige **Tab** a la tasa siguiente, **Shift+Tab** a la anterior y **Enter** a la siguiente mediante esos nodos, sin `FocusScope.nextFocus` global mientras existe celda siguiente; el autoguardado al perder foco permanece.
- Los 28–31 controles diarios se montan dentro de una única columna desplazable para que también exista un destino de foco cuando la celda siguiente empieza fuera de la ventana.
- Se añadieron pruebas de integración de foco con un botón representativo de **Marcadas** en el mismo árbol, además de los tests previos de guardado. No se toca el sidebar ni POS.

**Bloqueo de publicación visual:** ejecutar `flutter analyze` y pruebas focalizadas de Tasas; corregir lo que falle, y **solo con todas las validaciones verdes** compilar Web oficial con Supabase/Drift y actualizar `127.0.0.1:8081` en la **misma tarea Codex**. Verificar navegación real de Tab, Enter y Shift+Tab, incluyendo filas alejadas del inicio, sin probar guardado con importes ficticios sobre datos de negocio reales. No modificar `main`, `8080` ni producción.

### Incidente: «Aplicar al mes» no ejecutaba la operación con 36.6243

El usuario demostró en Chrome que el autoguardado por fila y la navegación funcionan, pero el comando mensual no hace nada cuando se introduce `36.6243`. Diagnóstico confirmado en código: `MoneyFormatter.parseToCents` admite un máximo de dos decimales y `_applyMonthRate` devolvía silenciosamente cuando la validación fallaba. El esquema real `public.exchange_rates.rate` permite **numeric(15,4)**.

**Corrección autorizada y acotada a las tasas:** parser fijo hasta cuatro decimales, sin redondeo silencioso; campo mensual con validación visible, estado `Aplicando…`, feedback de éxito/error y bloqueo frente a pulsaciones repetidas. Se mantiene la acción explícita `Aplicar al mes` y se esperan guardados diarios pendientes. El modelo de tasa agrega una representación opcional precisa en unidades de 1/10000 conservando `rateInCents` para compatibilidad POS/Drift. Las lecturas/escrituras del repositorio remoto conservan cuatro decimales; el editor diario admite y muestra también cuatro decimales, para evitar inconsistencia luego de recargar el mes. El repositorio local mantiene su funcionamiento anterior de dos decimales; no se modificaron tablas SQL, ventas ni POS.

**QA obligatorio antes de actualizar 8081:** `flutter analyze`, pruebas focalizadas de Tasas, prueba con `36.6243` sin pérdida de precisión, revisión de `36.62435` (error), `0` (error), estados de aplicación masiva y render posterior a la recarga. Comprobar que `rateInTenThousandths` no afecta los consumidores existentes de `rateInCents`. Si alguna prueba o compilación falla, corregir de forma focalizada y conservar el preview anterior; cuando todo sea correcto, actualizar `8081` **en el mismo trabajo**, preservando el worktree original, `main`, POS, producción y los stashes.

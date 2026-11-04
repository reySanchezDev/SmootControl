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

## Regla obligatoria UX-041 — Retroalimentación de todas las acciones (2026-11-04)

**Mandato del propietario, aplicable a todo el Backoffice presente y futuro:** ninguna operación ejecutable debe dejar al usuario sin información sobre su resultado. Cada acción con efecto debe comunicar su estado de manera coherente con lo que realmente ocurrió.

1. **En proceso:** indicar `Guardando…`, `Aplicando…`, `Eliminando…` u otra descripción exacta durante operaciones asíncronas; impedir envíos duplicados que pudieran causar efectos secundarios.
2. **Éxito:** comunicar `Guardado correctamente`, `Aplicado al mes`, etc., únicamente cuando la capa correspondiente confirme una respuesta satisfactoria. Jamás mostrar éxito solo por el clic o una solicitud HTTP iniciada.
3. **Rechazo o validación:** comunicar qué dato no se acepta y cómo corregirlo, con mensaje junto al campo afectado y, cuando se pulse una acción explícita, aviso general visible. No terminar silenciosamente por un `return`.
4. **Error remoto o parcial:** comunicar claramente que no se completó, conservar la edición cuando sea posible y evitar una confirmación engañosa. Si hay escrituras múltiples potencialmente parciales, **no afirmar que todo se guardó** hasta que se compruebe el resultado; indicar la posibilidad de un resultado parcial y cómo verificarlo.
5. **Información y advertencia:** distinguir un resultado informativo, una advertencia y un error del éxito. Usar texto explícito acompañado de icono; nunca depender exclusivamente de color ni de un icono sin texto.
6. **Interacción proporcional:** una edición rápida repetitiva (p. ej. celdas tipo Excel) presenta estado local `Guardando / Guardado / Error` sin interrumpir cada celda; una acción explícita como `Aplicar al mes`, crear, modificar o eliminar presenta **diálogo modal según resultado**. Confirmaciones previas solo cuando la acción sea destructiva o tenga efectos masivos que deban autorizarse.
7. **Consistencia:** reutilizar `BackofficeActionFeedback.show` para **diálogos de resultado tipificados** (éxito, advertencia, error, información), con icono, título, mensaje completo y botón `Aceptar`; no sustituirlos por Snackbars o mensajes temporales para acciones explícitas. Mantener el feedback inline para ediciones repetitivas. Conservar idioma, accesibilidad, foco y uso responsive.
8. **Alcance y QA:** auditar los callbacks y ramas de `AppResult` de todos los módulos administrativos, corrigiendo ausencia de feedback en lotes posteriores. Probar aceptación, rechazo, fallo remoto y espera según la acción. No alterar reglas de negocio ni POS para implementar solamente mensajes; las operaciones funcionales que requieran cambios deben recibir autorización.

**Aplicación inmediata — Tasas de cambio:** `Aplicar al mes` muestra **diálogo Atención** ante rechazo de formato vacío/negativo/con más de cuatro decimales; `Aplicando…` mientras se ejecuta; **diálogo Operación exitosa** solo tras `AppSuccess`; **diálogo Error** tras `AppFailureResult` o excepción, advirtiendo de escrituras parciales. Cada tasa diaria mantiene mensajes inline en su propio campo para no interrumpir la navegación tipo Excel. No alterar la precisión `numeric(15,4)` ni eliminar la posibilidad de guardar tasas con dos decimales.

**Estado:** regla documentada y aplicada al módulo Tasas. No afirmar que el resto del Backoffice cumple UX-041 hasta finalizar su auditoría.

### Aclaración obligatoria de UX-041: modalidad de presentación

En la revisión visual de 2026-11-04 el usuario rechazó expresamente los Snackbars inferiores. Para **acciones explícitas** (por ejemplo, `Aplicar al mes`) el resultado debe presentarse **en una ventana de diálogo modal** con tipo reconocible: éxito, advertencia, error o información. No basta cambiar colores o textos de una notificación fugaz. El usuario cierra el diálogo mediante `Aceptar`. El estado de ejecución previo permanece en el botón correspondiente. Las acciones de edición continua por teclado (tasas por día) conservan estados inline, porque mostrar un diálogo por celda impediría su uso como hoja de cálculo. Cada nuevo módulo debe aplicar esta distinción y verificarla con pruebas.

## F3 — Gastos, Usuarios y Roles/permisos: consistencia de formularios y selección (2026-11-04)

Tasas de cambio quedó aprobada por el propietario en el navegador sobre el SHA `f1b41c5f50f39f0b29bb72f5241436463d66c9f9`, tras la validación focalizada 14/14 de Tasas y 4/4 del feedback modal UX-041.

En la inspección de los tres módulos se detectó:
- **Usuarios:** editor limitado a 380 px, sin scroll en el contenido, sin agrupación visual de los controles de estado; tarjeta compacta duplicaba botones Editar/Inactivar pese a disponer de `BackofficeCollectionView.selectionActions`.
- **Roles y permisos:** editor de 420 px con lista extensa de permisos, grupos demasiado próximos; tarjeta compacta duplicaba las mismas acciones de la botonera seleccionada.
- **Gastos:** editor de categorías a 360 px, con campos de cobertura condicional y sin desplazamiento en el contenido; espaciado de 8 px distinto del estándar. `ExpensesBackofficeTable` ya utilizaba correctamente la selección y comandos explícitos.

**Correcciones de presentación:**
- Diálogos de Usuarios y Categorías de Gastos: ancho preferido `BackofficeFormStandards.dialogWidth` (520), contenido con `SingleChildScrollView` y espacios uniformes.
- Diálogo de Roles: ancho preferido `wideDialogWidth` (680), separación entre bloques de datos/estado/permisos. La matriz de permisos y sus callbacks no cambian.
- Usuarios y Roles: tarjetas compactas sin botoneras duplicadas; editar e inactivar siguen disponibles a través de los comandos explícitos de la barra de selección, tanto en escritorio como en móvil.

**Límite explícito de UX-041:** la persistencia de estos tres módulos se ejecuta mediante eventos BLoC (`ExpenseCategorySaved`, `ExpenseCategoryDeleted`, `UserSaved`, `RoleSaved`). Sus estados de UI actuales (`Loading`, `Loaded`, `Failure`) no diferencian si `Loaded` provino de una carga inicial o de una mutación confirmada, y algunos flujos vuelven a leer después de guardar. Por tanto, está **prohibido** presentar un diálogo de «Guardado correctamente» al recibir el resultado del formulario, emitir el evento o entrar genéricamente en `Loaded`. Para aplicar UX-041 a estos módulos deberá introducirse, previa revisión funcional específica, un resultado identificable por operación y correlación con la mutación. No alterar repositorios, reglas de roles ni permisos sin autorización.

**QA focalizado para este lote:** formatear solo los cinco archivos Dart afectados, ejecutar `flutter analyze` y pruebas disponibles de diálogos/tablas de selección. En la misma ejecución, tras superar validaciones, compilar Web oficial y actualizar solamente `8081` con Supabase/Drift. Revisar 390 px y escritorio (1366/1920). No ejecutar regresión general ni guardar datos reales de Usuarios, Roles o Gastos.

## F3 — Corrección visual Roles y nueva fase de UX-041 (2026-11-04)

El propietario aprobó visualmente el lote de Gastos, Usuarios y Roles salvo el campo **Nombre** del diálogo «Editar rol», cuya etiqueta flotante se recortaba al inicio del área desplazable. Se añadió un margen superior del estándar de formulario antes del primer campo en `CreateRoleDialog`, sin cambiar valores, validaciones ni callbacks.

**Nueva fase, primer módulo: Rol y permisos con retroalimentación confiable.** Los guardados se componen de `saveRole` seguido de `setRolePermissions` y recarga. Para evitar éxitos falsos se añadieron dos estados de evento diferenciados de la carga normal: `RolesActionSucceeded` únicamente después de que **ambas escrituras** devuelvan éxito y `RolesActionFailed` si la primera escritura falla o la segunda falla con `mayBePartial=true`. La página escucha esos resultados mediante `BlocConsumer` y presenta los diálogos modales tipificados del patrón UX-041. El guardado, el servicio, la autorización, las reglas de rol, los repositorios y el comportamiento del POS no se modificaron.

**QA requerido:** `flutter analyze`, pruebas `roles_bloc_test.dart` (incluye confirmación posterior a ambas escrituras y posible fallo parcial), prueba de feedback modal, inspección del campo «Nombre» en desktop y ancho 390px. Si pasa todo, build oficial y actualizar **8081 en la misma ejecución**. Ningún guardado de prueba debe tocar Supabase real.

**Pendiente siguiente:** correlación equivalente para los guardados y eliminaciones de **Usuarios** y **Gastos**, que todavía no presentan diálogos de éxito/fracaso ligados a su persistencia. No declarar cumplimiento integral de UX-041.

## F3 — UX-041 en Usuarios y Gastos (2026-11-04)

Base validada por Codex para Roles: `c48b2b1319b13970c400227520cc33233b67c08e`; análisis limpio, Roles 4/4, feedback modal 4/4 y preview Web `8081` actualizado. La revisión de escritorio/móvil de la etiqueta flotante «Nombre» sigue pendiente en navegador.

**Usuarios:** se incorporaron `UsersActionSucceeded` y `UsersActionFailed`, diferenciados de `UsersLoaded` y `UsersFailure`. `UsersBloc` solo emite éxito de guardado después de `_usersRepository.saveUser` con `AppSuccess`; el evento inicial de lectura nunca genera confirmación. `UsersPage` utiliza `BlocConsumer` para presentar exclusivamente el diálogo modal UX-041 de éxito o error. La desactivación usa el mismo flujo `UserSaved` y conserva su confirmación previa. Sin cambio de permisos, reglas PIN o repositorios.

**Gastos:** se incorporaron `ExpensesActionSucceeded` y `ExpensesActionFailed` para categoría guardada, categoría eliminada y gasto registrado, después del resultado explícito del repositorio y antes de la recarga del catálogo. `ExpensesPage` escucha solo estos resultados para diálogos modales UX-041. Las lecturas iniciales y fallas de carga conservan sus estados sin mostrar éxito. La confirmación previa de eliminación permanece. Sin cambios en los repositorios ni en los importes/persistencia.

Se ampliaron las pruebas focalizadas de `users_bloc_test.dart` (éxito/fallo de escritura) y `expenses_bloc_test.dart` (éxitos de cada operación y fallo sin éxito). Todo está **pendiente de ejecución por Codex**. La aprobación no podrá declararse hasta ejecutar `flutter analyze`, estas pruebas y la prueba del feedback modal. Si pasa todo, aplicar formato focalizado, publicar y reconstruir **8081 en esa misma ejecución** usando el build Web oficial. Preservar worktree original, 17 stashes, 8080, main, POS, producción y datos reales. No ejecutar operaciones reales de prueba.

## F3 — Métodos de pago y avance restante (2026-11-04)

El propietario aprobó visualmente Roles, Usuarios y Gastos tras SHA `26e39c237ab2286e944e04c7922740b1fae0c8c5`; las pruebas del lote fueron 15/15 y el preview 8081 estaba actualizado.

**Lote Métodos de pago (presentación exclusivamente):** el diálogo `CreatePaymentMethodDialog` cambia ancho fijo 360 por `BackofficeFormStandards.dialogWidth` (520 lógico), añade margen superior para que no se corte la etiqueta flotante «Nombre» y sustituye los huecos de 8 por `fieldGap` (12). En la lista compacta se eliminan los comandos de edición, desactivación y eliminación duplicados en cada tarjeta; los mismos callbacks y condiciones de negocio permanecen disponibles por la barra `BackofficeCollectionView.selectionActions`. Se conserva el árbol jerárquico y la sangría por nivel; no hay cambios en operaciones, permisos, valores, repositorios, POS ni persistencia. Las pruebas y revisión visual de este lote están pendientes.

**Estimación operativa de avance F3:** aproximadamente **80 %**, orientativa y no resultado de un conteo exhaustivo de pantallas; el catálogo de `lib/features` incluye rutas POS y administración y no se puede equiparar el número de archivos con porcentaje de aceptación. Restan auditoría de Métodos de pago/otros catálogos, coherencia de Inventario y Movimientos, Caja y Reportes/Configuración, aplicación UX-041 a las operaciones aún no cubiertas, y cierre con inspección responsive y pruebas de no regresión. No declarar F3 terminada hasta validación visual y funcional integral.

**QA proporcional:** ejecutar `flutter analyze`, pruebas focalizadas existentes de Métodos de pago/selección y verificar formato solo de tres archivos modificados. Si pasa todo, ejecutar build Web oficial con Supabase/Drift y actualizar `8081` en la misma tarea. No ejecutar cambios reales en Supabase, no alterar `main`, POS, `8080`, producción ni stashes.

## F3 — Lote ampliado de revisión transversal, una sola validación (2026-11-04)

A petición del propietario, se agruparon cambios previamente separados para ejecutar **un único ciclo de Codex**, con `flutter analyze`, pruebas focalizadas secuenciales y, si todo pasa, build y actualización de `8081` en la misma tarea.

**Incluido en el mismo lote (no declarado validado aún):**
- Métodos de pago: diálogo de 520 px lógicos, margen superior que protege la etiqueta Nombre, separación uniforme y eliminación de comandos duplicados por tarjeta móvil, conservando acciones en barra contextual.
- Inventario: tres diálogos administrativos (ajustes, compras de productos por lote y compras de empaques por lote) usan `BackofficeFormStandards.wideDialogWidth` en escritorio, y espacios `fieldGap/sectionGap`. Mantienen ancho adaptable en móvil, controles de búsqueda, filas, comprobaciones, servicios, callbacks y guardado originales.
- Inventario: las tres advertencias «sin productos/empaques» pasan de Snackbar inferior a diálogo modal de advertencia UX-041. No se modificó la condición de disponibilidad ni la operación.
- Reportes: el comando de generación de PDF en el resumen se muestra con **icono y texto**, conservando el callback y la desactivación cuando no existe resumen.
- Configuración: tras `BusinessSettingsLoaded(saved: true)`, la confirmación se presenta como diálogo modal **Operación exitosa** de UX-041, sin mensaje por carga inicial; se preserva el flujo de guardado.

**Excluido deliberadamente por riesgo:** los diálogos de abrir/cerrar caja compartidos con el POS, permisos, movimientos reales, modificaciones a Supabase, lógica de ventas, seguridad y operaciones de producción. Caja y Movimientos ya tenían mejoras de filtros/tabla, pero no se declaran completamente auditados solo por este lote.

**QA antes de publicación visual:** formatear únicamente los archivos Dart alterados, comprobar imports de `part of` (incluido `BackofficeFormStandards` en `inventory_page.dart`), ejecutar `flutter analyze`; pruebas focalizadas de Métodos de pago, Inventario y sus diálogos, Reportes, Configuración y feedback modal, más la selección compartida. En caso de fallos corregir solo problemas de este lote. Si pasa todo, commit/push y construir con Supabase+Drift para actualizar exclusivamente `8081`, verificando SHA servido y HTTP 200. Mantener 17 stashes, `8080`, `main`, POS, producción y datos reales intactos. No ejecutar regresión general para cambios puramente visuales.

## F3 — Lote residual de Caja, Auditoría, Movimientos y Reportes (2026-11-04)

Codex validó y publicó el lote anterior bajo SHA `75c3d0eadb871bdc917535bf2f660d30014103e3`: `flutter analyze` limpio, pruebas focalizadas de Métodos de pago, Inventario, Reportes, Configuración, selección y UX-041 aprobadas; build oficial Supabase/Drift y preview `8081` actualizados. Quedó pendiente inspección visual manual de los tres diálogos de Inventario por ausencia de tests widget específicos.

Se agrupa para **una sola validación posterior** el siguiente lote exclusivamente de presentación:
- **Caja administrativa:** `_handleMutationResult` usa `BackofficeActionFeedback` para distinguir diálogos modal **Operación exitosa** y **Error** después de resultados `AppSuccess` o `AppFailureResult`. Mantiene confirmación previa destructiva, callbacks `_edit/_delete`, `_service.update/delete` y `_load` original. No modifica apertura/cierre de caja POS.
- **Auditoría:** control de fecha con rótulo explícito `Fecha: dd/MM/yyyy`, y detalle de auditoría con ancho preferido `wideDialogWidth` y scroll interno, apto para detalles extensos.
- **Movimientos:** legibilidad de etiquetas (`líneas`) y separación del encabezado de detalle mediante `BackofficeFormStandards.fieldGap`. Sin modificar filtros, fechas, llamadas remotas o navegación.
- **Reportes:** ortografía profesional de textos visibles (ventas, desempeño, costos, gastos y vacaciones), sin tocar rutas, generación de PDF ni cálculos.

**Pruebas exigidas:** `dart format` solo de los cuatro archivos modificados, `flutter analyze`, pruebas focalizadas disponibles de Caja, Auditoría, Movimientos, Reportes, feedback modal y selección. Si faltan tests widget de estas pantallas, reportarlo; no afirmar cobertura visual inexistente. Validar que `part of` de Movimientos dispone de `BackofficeFormStandards` importado en `inventory_movements_page.dart`. Si todo es correcto, publicar exclusivamente formato/lint y compilar Web para actualizar únicamente `8081` **en la misma ejecución**. No modificar 8080, main, POS, producción, stashes ni datos reales. Inspección responsive desktop 1366×768 /1920×1080 y móvil 390px queda como control de aceptación final.

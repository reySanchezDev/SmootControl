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

# Backoffice V2 — Adopción de Quantix Engineering Standards

**Rama:** `develop/backoffice-v2`  
**Norma de referencia:** `reySanchezDev/QuantixEngineeringStandar`, v0.1.3, revisión fijada en `AGENTS.md`.  
**Estado:** implementación transversal parcial; pendiente de validación ejecutada con Flutter y QA visual de todos los módulos. No equivale a certificación UX completa.

## Trabajo integrado en la rama

### Base compartida — impacto transversal

- `AGENTS.md` con referencia fija y copia accesible de normas en `Documentation/Standards/`.
- `BackofficeWorkspace`: menú compacto responsivo, múltiples pestañas, Inicio cerrable, marca no duplicada, cierre de sesión único en shell.
- `BackofficeSidebar`: etiquetas multilínea legibles, expansión/contracción, artista de borde extraído para respetar <=300 líneas.
- `BackofficeWorkspaceDrawer`: módulos agrupados en dispositivos estrechos.
- `BackofficeWorkspaceScope` + `AppPageScaffold`: evitar encabezado duplicado de páginas dentro del workspace y preservar acciones arriba a la derecha.
- `BackofficeDataTable`: alineación por tipo configurable; encabezados fijos y celdas de altura variable para mostrar información completa.
- `AppInput`: marcador requerido, error contextual, foco y avance con teclado; secreto enmascarado según parámetro existente.
- `AppButton` y `AppEmptyState`: evitar reducción excesiva del texto y truncamiento.
- `AppMessageDialog`: mensaje y confirmación personalizados, reutilizables, con acciones destructivas diferenciadas.

### Navegación real

- Catálogos arriba: Productos, Categorías, Recetas, Unidades, Modificadores, Métodos de pago, Mesas, Empaques.
- Resumen (Inicio cerrable), Operaciones, Personal, Reportes y Administración.
- Visibilidad basada en los permisos existentes de `RouteAccess`, guardas existentes al abrir la página; sin nuevas autorizaciones implícitas.
- No se han inventado módulos ni métricas.

### Productos — adaptación de referencia

- Título duplicado eliminado; acción `Nuevo` arriba a la derecha y accesible aun con catálogo vacío.
- Búsqueda ampliada, selector de categorías con búsqueda, filtros de dominio, ordenación de columnas de datos, paginación comprensible.
- Importes alineados a la derecha; datos con ajuste de línea, etiquetas semánticas y colores del tema.
- Formulario de tamaño adaptable, acciones superiores, requeridos marcados, foco al primer campo inválido.
- Detección de cambios sin guardar, confirmación para descartarlos y confirmación previa de edición.
- Aviso de guardado tras el éxito del BLoC, usando diálogo compartido; textos clave localizados ES/EN.
- Archivos Dart manuales afectados divididos para quedar por debajo de 300 líneas.

## Segunda pasada — propagación por módulos (30/10/2026)

La primera pasada sólo había renovado Productos. La inspección visual detectó
que Categorías y Recetas seguían usando listas antiguas. En esta segunda
pasada se agregó `BackofficeCollectionView<T>`, con búsquedas, ordenación
semántica por columna, paginación uniforme, encabezados fijos, alineación y
tarjetas móviles; sin duplicar tablas por módulo.

**Módulos adaptados en código**:
- Categorías: tabla con nombre, tipo, padre, posición, estado y acciones;
  conserva árbol jerárquico en móvil.
- Recetas: tabla con búsqueda, paginación y edición, sin inventar alta directa.
- Unidades: búsqueda, factor, costo no aplicable, estado, edición y
  confirmación de inactivación.
- Mesas: tabla con estados y operaciones claras.
- Métodos de pago: tabla con moneda, grupo y operaciones; conserva reglas de
  negocio y vista jerárquica compacta.
- Modificadores: grupos y opciones editables; vista expandible móvil.
- Gastos: tabla de categorías, cobertura, jerarquía y acciones.
- Inventario: existencias de productos y empaques con unidades, costos y fecha.
- Movimientos: tabla con documentos, fecha, tipo, líneas y neto.
- Empaques: las tres pestañas usan tablas estándar, manteniendo formularios
  y operaciones reales. Las interacciones requieren QA visual y funcional.
- Roles: tabla de nombre, descripción, cantidad de permisos, estado y
  operaciones existentes, conservando protección de roles del sistema.
- Usuarios: tabla de usuario, correo, rol, estado y acciones, sin mostrar
  secretos en el listado.
- Marcadas: botón primario compartido y mensajes/confirmación destructiva
  personalizados; el listado detallado sigue pendiente de una revisión.
- Vacaciones: botón primario reutilizable; formularios, acciones de estado
  y tabla especializada pendientes de auditoría funcional.
- Todos los módulos que usan `AppPageScaffold`: acciones superiores ahora
  admiten múltiples líneas para impedir overflow.

**No certificar cumplimiento total:** Ventas, Caja, Personal, Planilla,
Reportes, Ajustes y Auditoría; además quedan adaptaciones funcionales de
Marcadas, Vacaciones y formularios internos de otros módulos.
La adopción de una tabla no acredita automáticamente las 37 reglas.

La comprobación UX-034 y los tests no sustituyen QA visual; las capturas
anteriores corresponden a una compilación local **anterior** a esta pasada.
No actualizar servidores locales mediante el repositorio remoto de manera
automática; sincronizar y reconstruir después de CI exitoso y aprobación QA.

## Retiro definitivo del prototipo ilustrativo — 31/10/2026

Por decisión explícita del propietario, **no se crearán prototipos visuales
aislados ni pantallas con datos ficticios para validar Backoffice V2**.
Las mejoras se hacen directamente sobre los módulos operativos y sus
componentes compartidos, respetando la autenticación y permisos.

- Eliminados `BackofficePreviewPage` y `BackofficePreviewGuard`.
- Retirada de `AppRoutes` la ruta pública de preview.
- Para conservar marcadores del navegador, la dirección histórica
  `/#/backoffice-v2-preview` abre el `AuthGate` real, nunca datos de ejemplo.
- La entrada principal sigue siendo `http://127.0.0.1:8081/` tras
  actualizar y reconstruir el servidor local; no es un entorno de demostración.
- Empaques: las tres pestañas operativas (Tipos de venta, Empaques y Reglas)
  usan `BackofficeCollectionView`, con búsqueda, ordenación, paginación y
  etiquetas completas, sin tocar los repositorios de datos.
- Comprobaciones automáticas nuevas de rutas heredadas y navegación real.

Esta actualización **no se verá en el puerto 8081** hasta que Codex actualice
el código local y reconstruya el servidor. El CI verifica compilación/tests,
no sustituye el QA visual ni la validación de cada regla por pantalla.

## UX-038 — Congruencia espacial de controles — 31/10/2026

Adoptada de Quantix Engineering Standards **v0.1.2**, tanto en
`AGENTS.md` como en `Documentation/Standards/`.

- Pie de paginación único: `BackofficePaginationFooter`. Ubica **«Registros
  por página» a la izquierda** y **rango, total y navegación a la derecha**
  en todas las páginas administrativas que utilizan
  `BackofficeCollectionView<T>`.
- `_BackofficeProductsTable` utiliza el mismo componente compartido.
  Su acción principal `Nuevo` queda alineada a la derecha, como en módulos
  equivalentes.
- En móvil, el pie conserva ambos grupos y los apila sin ocultar cifras.
- Pruebas de escritorio/móvil en
  `test/core/design_system/backoffice_pagination_footer_test.dart`.
- **Pendiente**: auditar y adaptar listados especiales que todavía no usen la
  colección compartida. No se declara cumplimiento universal sin QA.
- Ningún cambio sobre `main`, producción, datos reales ni lógica del POS.

## Alcance estricto: solamente Backoffice administrativo — 02/11/2026

**Límite arquitectónico vinculante**:
- La capa de apariencia `BackofficeTheme.executiveIvory` se instala
  exclusivamente en `BackofficeHomePage` dentro de la sesión administrativa.
- El tema global `AppTheme.light` sigue siendo exclusivo de la aplicación
  común y los flujos App/POS y Tableta. No se ha modificado `AppTheme.light`,
  `AppPalette`, `features/pos/`, rutas de POS ni `TimeClockGate`.
- Las mejoras que dependen de `BackofficeWorkspaceScope` se activan
  únicamente al renderizar la vista dentro del workspace Backoffice.
- Un viewport de anchura tablet **dentro del Backoffice web** puede adoptar
  el diseño responsive; esto no cambia el **modo Tableta** del POS.
- No modificar permisos, servicios, repositorios, esquemas ni persistencia
  para conseguir cambios de presentación.

**Cambios funcionalmente conservadores de esta pasada**:
- Ventas: `SalesSearchableList` usa `BackofficeCollectionView` solo cuando
  pertenece al workspace Backoffice; mantiene el listado anterior fuera de él.
- Caja: fechas, importes, estado, cajero, dispositivo, edición y eliminación
  mediante tabla administrativa; confirmación destructiva y respuesta uniforme.
- Auditoría: búsqueda, ordenación y paginación; detalle mediante la
  visualización formateada existente, sin volcar metadatos técnicos en celdas.
- Personal: tabla administrativa, búsqueda, acciones con texto y tarjetas
  móviles; archivo separado para respetar 300 líneas.
- Vacaciones: tabla paginada y filtrable, conserva aprobación/rechazo y
  confirma eliminación antes de enviar la operación al repositorio.
- Configuración: acción Guardar arriba, campos obligatorios señalados.
- `BackofficeTheme`: color principal con contraste AA sobre blanco, texto
  secundario y variantes reutilizables de diálogos, pestañas y botones.
- Test: `backoffice_theme_isolation_test.dart` comprueba que la paleta de
  Backoffice es independiente de App/POS y que sus acciones tienen contraste
  WCAG AA.

**No sustituye QA completo**: siguen requiriendo revisión los formularios
especializados, flujos de pago/Planilla y las pantallas de informes. Un
componente compartido no certifica automáticamente todas las reglas UX.

## Verificación automatizada preparada

- `tool/verify_backoffice_v2_ux.ps1` comprueba límite de 300 líneas en Dart modificado, regenera l10n, ejecuta `flutter analyze`, pruebas de diseño y `flutter build web --release`.
- Workflow de GitHub Actions `.github/workflows/backoffice-v2-ux-quality.yml`, disparado en PR contra `main` o manualmente.
- Pruebas añadidas para confirmaciones, campos requeridos, Inicio cerrable y Drawer móvil.

**Importante:** la comprobación real se ejecuta mediante GitHub Actions. Los avisos introducidos por estos cambios deben corregirse. El validador conserva una lista explícita de cuatro hallazgos preexistentes fuera del alcance UX (autenticación, gastos, ventas, mantenimiento); estos no equivalen a una aprobación de análisis global con cero avisos. Los errores de compilación y nuevos avisos sí bloquean CI. El navegador y QA manual requieren validación aparte.

## Brechas aún abiertas — NO CERTIFICADAS

1. Revisar individualmente los formularios de Categorías, Recetas, Inventario, Movimientos, Ventas, Caja, Gastos, Personal, Marcadas, Vacaciones, Planilla, Reportes y Administración. El uso del scaffold común no garantiza cumplimiento completo de UX-001..039.
2. Migrar mensajes críticos de los demás módulos al diálogo compartido y conectar detección de formularios modificados a sus cierres.
3. Convertir la página Inicio en un resumen de métricas **reales** con fuentes y autorizaciones verificables; hoy es principalmente navegación a módulos. Nunca inventar cifras.
4. Validar de punta a punta pantallas móviles y escritorio, escalado de texto, teclado, navegación, múltiples idiomas, accesibilidad, filtros, formularios y permisos.
5. Inspeccionar reglas de más de 300 líneas en archivos preexistentes no modificados y resolver de manera gradual, sin refactorización masiva ciega.
6. Ejecutar QA de módulos con datos reales de prueba y verificar resultados de análisis/compilación antes de merge.

## Procedimiento de validación local

```powershell
git switch develop/backoffice-v2
git pull --ff-only
pwsh ./tool/verify_backoffice_v2_ux.ps1
```

Después, realizar recorrido de negocio con perfiles de acceso distintos y vistas
390×844, 768×1024, 1366×768, 1920×1080, más zoom de texto.
Registrar errores con módulo, captura, pasos, resultado esperado y real.

**Política:** no realizar merge a `main` ni despliegue de producción sin QA aprobado. Conservar modificaciones locales ajenas del usuario.

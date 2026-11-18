# FE-E5 — Aislamiento del acceso heredado de Empaques

Fecha: 2026-11-08. Rama: `fix/packaging-legacy-route-isolation`.
**Estado: implementación propuesta; sin compilación ni QA ejecutada en este cambio.**

## Base verificada externamente
Codex aplicó 87/87 migraciones en Docker local y validó REST CRUD por rol, rechazo cross-tenant y guardas RPC. Las suites declaradas pasaron (navegación 8/8, design system 35/35, ventas 23/23, inventario 7/7, sync 48/48). Flutter analyze no concluyó. No hay autorización para producción.

## Cambios
- La ruta antigua `/packaging` ya **no monta** `PackagingPage(view: all)`: abre `PackagingLegacyEntryPage`, un selector que filtra destinos según los permisos efectivos del rol. No presenta ningún editor compartido.
- El selector mantiene el enlace heredado y ofrece únicamente destinos permitidos; las rutas nuevas conservan sus guardas propias y el backend las políticas RLS 085–087.
- Los destinos de Modalidades y Empaques cargan sólo su recurso de datos, por lo que una falla de productos/reglas no bloquea esos dos catálogos. Reglas sigue utilizando datos relacionados.
- No se modifican SQL, esquema ni RPC. El resto de interfaces POS e inventario permanece intacto.

## Riesgos y pruebas obligatorias Codex
1. `dart format`, `dart analyze` o `flutter analyze` con salida completa; aislar bloqueo del analizador y registrar causa.
2. Flutter test de navegación/Backoffice y Ventas/Inventario/Sync.
3. Widget test real de `/packaging` con los tres perfiles (solo modalidades, solo empaques, admin): no debe montarse el editor cruzado, ni aparecer destino sin permiso.
4. Entrar por deep link /packaging, seleccionar destino, cerrar pestaña, retroceder, repetir después de cerrar sesión y volver a entrar. Confirmar guardas y ausencia de enlaces de escritura indebida.
5. Escenario de falla `getProducts/getRules`: las vistas Modalidades y Empaques permanecen operativas.
6. Confirmar que el selector no presenta permisos obsoletos tras modificación de rol y que el backend rechaza el JWT no autorizado.
7. Mantener entorno Docker aislado en `127.0.0.1`, 87 migraciones, 17 stashes y Tentrix intactos.
8. QA visual autenticado por el usuario sigue pendiente; ficha del producto y reglas por pedido permanecen fuera de este cambio.

El gate FE-E5 sigue **pendiente** hasta recibir evidencia de Codex. No fusionar ni desplegar.

## Validación Codex

Fecha: 2026-11-08. Worktree: `SmooControl-packaging-legacy-lab`.

- El worktree se creó desde `origin/fix/packaging-legacy-route-isolation` en
  `11e0f462c9847e2ed2764ecfdc4be7d3c9932943`. No se modificaron `main`, los
  worktrees existentes ni los 17 stashes.
- `dart format` se ejecutó sobre los tres Dart del lote y sobre la prueba nueva;
  solo produjo cambios equivalentes de formato en la página heredada.
- Se agregó una inyección opcional de lector de permisos exclusivamente para
  pruebas aisladas; el comportamiento de producción continúa usando el lector
  remoto por defecto. La prueba widget cubre administrador completo,
  `tipos_venta.gestionar`, `empaques.gestionar` y ausencia de permisos. En los
  cuatro casos el editor combinado no se monta y no aparecen destinos ajenos.
- Pruebas focalizadas: widget/legacy y navegación 10/10; diseño compartido y
  Backoffice 35/35; Ventas 23/23; Inventario 7/7; Sincronización 48/48.
- `dart analyze` y `flutter analyze --no-pub` no concluyeron. Ambos quedaron
  bloqueados en el análisis sin producir diagnóstico; los procesos fueron
  identificados por la línea de comandos de esta ejecución (el servidor Dart
  llegó a aproximadamente 362 MB y 14 s de CPU) y se detuvieron sin tocar los
  procesos persistentes de VS Code/Flutter. Por ello el análisis está pendiente
  y no se declara aprobado.
- El laboratorio local respondió REST HTTP 200 en `127.0.0.1:54321`, PostgreSQL
  quedó publicado solo en `127.0.0.1:54324`, la base conserva 87 migraciones y
  las políticas/RPC de `sales_types`, `packaging_items` y
  `product_packaging_rules` siguen presentes. No se hicieron escrituras.
- No se realizó QA visual autenticado en navegador ni se verificaron sesiones
  reales, deep links interactivos o cierre de sesión; quedan pendientes para
  revisión manual. Las pruebas automatizadas sí cubren clasificación de ruta,
  filtrado de destinos y no montaje del editor combinado.

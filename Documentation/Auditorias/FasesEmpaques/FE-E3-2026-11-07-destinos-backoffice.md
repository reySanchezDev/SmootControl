# FE-E3 — Primera separación funcional de destinos Backoffice

**Fecha:** 2026-11-07. **Estado:** cambios GitHub listos para validación local; **no ejecutados ni aprobados**.  
**Origen:** `fix/packaging-sale-void-contract` con corrección 084 validada en laboratorio; 84/84 migraciones, 76/76 tests Flutter y anulaciones remotas aprobadas.  
**Rama:** `feature/packaging-backoffice-destinations`.

## Cambios implementados (primera iteración E2/E3)
- Tres rutas de Backoffice: `/settings/sales-types` (Modalidades de servicio), `/catalog/packaging-items` (Empaques) y `/catalog/packaging-rules` (Reglas de empaque).
- Sidebar: Modalidades pasa a Administración, Empaques y Reglas pasan a Catálogos como destinos separados. Se retira únicamente la entrada compartida del menú, **no la ruta antigua `/packaging`**.
- `PackagingPageView` presenta sólo el editor/lista del destino; reutiliza widgets existentes, modelos, repositorios, CRUD, UUID y contratos. La ruta legacy continúa ofreciendo las tres pestañas.
- Cada ruta nueva tiene permiso de navegación preciso: `tipos_venta.gestionar` o `empaques.gestionar`, y forma parte de Backoffice con requerimiento online. Se añade test de propiedad de ruta y contrato de permisos.
- No se modifican tablas, sales_types, empaques, movimientos de ventas ni POS. La migración 084 se hereda sin cambio.

## Límites aún no resueltos (impiden declarar el refactor final)
1. **Carga aún compartida:** `_loadSnapshot()` sigue consultando 4 recursos, aunque la página sea de un único catálogo. Implementar por destino y manejar fallos separados antes del gate final.
2. **Ruta legacy con autorización OR:** sigue accesible con cualquiera de dos permisos y permite visualizar tres editores. Debe corregirse con autorización por acción y backend; no declarar aislados los permisos por solo cambiar menú/ruta.
3. **Backend RLS:** el acceso de edición remoto está restringido por restaurante, pero falta auditar enforcement de permiso específico `tipos_venta.gestionar` vs `empaques.gestionar`. Prueba de roles parciales mediante APIs Auth antes de dar por seguro.
4. **Reglas en ficha de producto:** todavía no integradas. La lista separada es una vista intermedia de administración, no el destino final del producto.
5. **Catálogo de empaques:** se usa la misma entidad `packaging_items`; no es todavía un maestro de Artículos agregado con productos.
6. **Compatibilidad/despliegue:** no hay QA visual, test real de widgets, ni evaluación de cierre de pestaña y deep link. No fusionar ni desplegar.
7. **Consumo por pedido** y permisos/default por terminal siguen en fases posteriores con gates G-NUM/G-CON.

## Pruebas para Codex local
1. Sincronizar HEAD, `dart format` de archivos cambiados, `flutter analyze`.
2. `flutter test test/core/navigation/packaging_destinations_test.dart` y navegación, UI, Ventas/Inventario/Sync.
3. Verificar en Backoffice real autenticado, con fixtures Docker locales: menú y listas CRUD, permisos A/B (solo tipos/solo empaques), rutas legacy, orden de tabs y confirmación; detectar accesos indebidos.
4. Verificar binding de Docker sigue `127.0.0.1`, 84 migraciones y nada conecta a producción; no hacer resets.
5. Capturar evidencia literal y registrar fallos; no declarar QA visual aprobado sin usuario.

## Validación local de Codex — 2026-11-07

### Resultado ejecutado

- HEAD examinado: `6c30076decf8d1e7aa243fdf8d819f574a2c9142` desde un worktree
  independiente. El worktree principal, sus 17 stashes y los demás worktrees no
  fueron modificados.
- `dart analyze`: correcto, sin issues. `flutter analyze --no-pub` no terminó
  después de varios minutos y fue detenido; no produjo diagnósticos. Esto queda
  como limitación del entorno, no como aprobación equivalente.
- `flutter test test/core/navigation -r expanded`: 8/8 correctos.
- `flutter test test/core/design_system -r expanded`: 35/35 correctos.
- `flutter test test/features/sales -r expanded`: 23/23 correctos.
- `flutter test test/features/inventory -r expanded`: 7/7 correctos.
- `flutter test test/features/sync -r expanded`: 48/48 correctos.
- Los tests de navegación confirman las tres rutas nuevas, sus permisos de
  navegación y la compatibilidad de `/packaging`. No existe una prueba widget
  específica que certifique creación/edición de los tres catálogos con datos
  reales, ni QA visual autenticada.

### Laboratorio y datos

- Docker publica Kong/API sólo en `127.0.0.1:54321` y PostgreSQL sólo en
  `127.0.0.1:54324`; las conexiones activas observadas fueron loopback.
- `supabase_migrations.schema_migrations` contiene 84 migraciones.
- En el restaurante sintético local se observaron 3 modalidades, 3 empaques y
  3 reglas. La capa de presentación muestra nombres, estados y relaciones
  resueltas; no renderiza UUID internos en las columnas revisadas.
- La inspección de código confirma callbacks de crear/editar que generan UUID
  internamente para altas y reutilizan el identificador de la entidad al editar.
  No se ejecutaron escrituras de CRUD desde un navegador autenticado.

### Permisos: bloqueo comprobado

- Las rutas nuevas están separadas correctamente: `tipos_venta.gestionar` para
  `/settings/sales-types` y `empaques.gestionar` para los dos catálogos de
  empaques. La ruta legacy `/packaging` conserva autorización OR por
  compatibilidad y no puede considerarse aislada por catálogo.
- Las políticas RLS locales de `sales_types`, `packaging_items` y
  `product_packaging_rules` son `ALL` para `authenticated` y sólo evalúan
  `is_same_restaurant(restaurant_id)`. Los privilegios de tabla también incluyen
  INSERT/UPDATE/DELETE para `authenticated`. No hay enforcement visible del
  permiso específico en estas políticas.
- Por tanto, la protección de ruta es correcta a nivel Flutter, pero la
  autorización REST/RLS por usuario parcial no está demostrada y existe una
  exposición potencial de operaciones si un usuario autenticado del mismo
  restaurante invoca directamente PostgREST. No se alteraron RLS, permisos ni
  backend; el cierre de E3 queda bloqueado hasta una auditoría/corrección
  autorizada del backend.

### Correcciones de esta validación

- Sólo se ajustaron avisos estáticos sin cambio de comportamiento: formato de
  los constructores de `PackagingPage` en `app_router.dart` y documentación de
  los valores públicos de `PackagingPageView`.
- No se modificaron reglas, callbacks, repositorios, SQL, POS ni sincronización.
- `flutter pub get` regeneró cambios locales en los tres archivos de
  localización; se conservaron fuera del commit.

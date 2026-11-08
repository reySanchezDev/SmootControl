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

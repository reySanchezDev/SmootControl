# FE-E9 — Reorganización acordada: Artículos, Empaques y Reglas

**Fecha:** 2026-11-08  
**Base:** `fix/backoffice-remote-route-permissions` (PR #16); `main` y producción fuera de alcance.  
**Rama:** `feature/articles-packaging-final-ux`.  
**Contrato:** `Documentation/Auditorias/AUD-2026-11-06-007-integracion-reorganizacion-empaques.md`, apartados Destino recomendado, I-20/H5, F-06, E2/E3. **No reabrir diseño**.

## Diseño de llegada (no provisional)

| Necesidad del usuario | Dónde se presenta | Fuente física original |
|---|---|---|
| Productos de venta | Catálogos → Productos, filtro Productos de venta | `products` |
| Materias primas | Catálogos → Productos, filtro Materias primas | `products` |
| Empaques (artículo no vendible) | Catálogos → Productos, filtro Empaques | `packaging_items` |
| Modalidades de servicio | Configuración → Modalidades de servicio | `sales_types` |
| Reglas de consumo | Configuración → Reglas de consumo | `product_packaging_rules` |
| Reglas de producto específico | Ficha del producto → Empaque y consumo (acceso contextual) | mismos `product_packaging_rules` |
| Stock, compras y movimientos de empaques | Inventario | `packaging_stock`, `packaging_movements` |

**Importante:** Un empaque aparece **como artículo en el catálogo visual**, pero no se transforma físicamente en `products`. Se preservan `packaging_items.id`, compras, movimientos, referencias de reglas, sincronización y anulaciones. Tampoco se expone precio de venta de empaques: son insumos no vendibles.

## Implementación GitHub

- `ArticlesPage` es la única pantalla visible de Productos en Backoffice y proyecta ambas fuentes en filas tipadas con identificadores de selección prefijados (`product:` / `packaging:`). Los UUID subyacentes siguen intactos. La lectura de cada catálogo es independiente: un error parcial muestra aviso/reintento y no oculta la fuente que sí respondió; las acciones de la fuente fallida permanecen deshabilitadas.
- Filtro de tipo con Todos, Productos de venta, Materias primas y Empaques. Búsqueda, ordenamiento, paginación, selección y comandos explícitos `Nuevo producto`, `Nuevo empaque`, `Editar`, `Inactivar`, sin `...` ni columna de acciones.
- Edición de productos reutiliza `CreateProductDialog`, incluidas unidades y acceso contextual a reglas, y `SupabaseAdminRepository.saveProduct`; empaque edita los campos de `packaging_items` mediante su repositorio existente.
- El catálogo verifica permisos de Supabase antes de cargar cada fuente: `productos.gestionar` para productos y `empaques.gestionar` para empaques. Una cuenta con permiso parcial ve únicamente filas y acciones de su ámbito. Los controles REST/RLS 085–087 continúan siendo autoridad de escritura.
- En sidebar se elimina **solo** la entrada separada `Empaques` y `Reglas de empaque` de Catálogos; `Modalidades de servicio` y `Reglas de consumo` van a grupo Configuración, junto con `Configuración`.
- `AppRoutes.products` usa `ArticlesPage`. Ruta heredada `/catalog/packaging-items` conserva acceso compatible al mismo catálogo filtrado por Empaques. `/catalog/packaging-rules` conserva ruta y edición, ahora presentada desde Configuración. `/packaging` sigue siendo selector de alias con permisos, sin triples editores.
- No se modifican SQL, migraciones, engine de venta, POS, Drift, ni contratos RPC; se conserva 87/87 aplicado localmente. No se crean filas duplicadas ni nuevos UUID en proyección.

## Criterios estrictos de aceptación para Codex (obligatorios)

1. Sincronizar rama en worktree independiente y preservar 17 stashes, `main`, localizaciones generadas y Tentrix.
2. `dart format` de archivos modificados; `flutter test` completos sobre navegación, Backoffice, productos, empaques, ventas, inventario y sincronización. `flutter analyze`: si queda bloqueado, registrar expresamente **inconcluso** y usar compilación real de Web para detectar errores; no falsear 0 incidencias.
3. Tests del listado único: filas provenientes de ambas tablas, búsqueda, filtro de 4 tipos, selección+Editar, Inactivar, Nuevo producto y Nuevo empaque, importes/estado/unidades, ausencia de UUID/«Más». Rol solo productos no ve empaques, solo empaques no ve productos, ambos ve todo, sin permisos bloqueado.
4. Validación HTTP/Auth con admin sintético **del restaurante Kivo Laboratorio**; bloquear otras configuraciones. Ejecutar creación/edición/inactivación con fixtures sintéticos y JWT real: confirmar tabla/ID originales, no mutación accidental entre entidades, RLS, refresh entre vistas y reglas.
5. Comprobar `Configuración → Modalidades de servicio` y `Configuración → Reglas de consumo`; CRUD consistente con reglas contextuales en ficha, mismo UUID y conjunto, sin pantallas de empaques duplicadas en Catálogos.
6. Comprobar deep links y bookmarks heredados de empaques: deben redirigir/abrir el filtro correcto sin exponer editores ajenos. Cierre de sesión y nueva sesión no retienen permisos incorrectos.
7. Ensayar venta POS de modalidad con regla, stock insufficient, idempotencia de reenvío, anulación y devolución de movimientos originales. Mantener `tracks_stock` y `tracks_inventory` previos. No ejecutar contra producción.
8. Verificar visualmente —por navegador local, cuando esté disponible— tema Executive Ivory, menú, tabla, filtros y diálogos responsive. **Si no hay navegador controlable, es validación pendiente del usuario, no aprobada.**
9. Si existe problema por mezcla de recursos, selección, render, permisos o escritura, corregirlo en esta misma rama y repetir pruebas hasta resolver. No reemplazar por nueva arquitectura ni PR parcial.
10. Recompilar y servir la rama exacta en `http://127.0.0.1:8092/`, `SMOO_APP_MODE=backoffice`, apuntando a API `127.0.0.1:54321`, restaurante `Kivo Laboratorio`, credenciales sintéticas en memoria. Solo reiniciar ese preview. Validar que HTML y JS correspondan al SHA nuevo, sin suponer que HTTP 200 prueba login.
11. Documentar resultados, fixes y excepciones aquí y publicar commit. No fusionar PR, ni tocar `main` ni producción.
12. El usuario **aprueba o rechaza visualmente** el resultado final; nada se declara comercialmente terminado antes de su decisión.

## Riesgos que NO se deben esconder

- `flutter analyze` sigue bloqueado por problema específico del proyecto en Windows; requiere salida completa para certificación global. No bloquear pruebas funcionales de laboratorio por ello, pero no permitir despliegue.
- La proyección de Artículos es virtual (dos tablas). Una **unificación física** requeriría migración transaccional y compatibilidad POS, no autorizada en esta fase.
- El caso del default de modalidad A→B en SQL remoto no se certificó con las pruebas de empaques previas; verificarlo aparte antes de atribuirle estado aprobado.
- Concurrencia multi-terminal simultánea y QA visual autenticado siguen sujetos a evidencia, no suposiciones.

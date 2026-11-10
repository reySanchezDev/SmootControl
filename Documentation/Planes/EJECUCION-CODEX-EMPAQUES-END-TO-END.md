# PLAN RECTOR VIVO — Core de artículos de Kivo

**Identificador:** KIVO-ITEM-CORE  
**Última actualización:** 2026-11-10  
**Estado:** DECISIÓN ARQUITECTÓNICA APROBADA; DISEÑO DEL CORE EN REVISIÓN; MIGRACIÓN NO AUTORIZADA  
**Repositorio:** `reySanchezDev/SmootControl`  
**Documento único de planificación:** este archivo. Se actualiza en cada avance, sin crear un plan por PR/fase.

> **REGLA INNEGOCIABLE:** No se considerará implementado un maestro único porque dos tablas aparezcan juntas en una pantalla, en una vista SQL UNION, o por crear una tercera tabla que reciba copias sincronizadas. Solo se cumple cuando `items` es la **única autoridad de los datos maestros**, los servicios operativos usan `item_id`, las referencias históricas y la sincronización están preservadas y no existe escritura funcional paralela definitiva.

## 1. Decisión técnica ratificada

Kivo adoptará el principio de **catálogo maestro único de artículos** usado por Business Central/LS Central, **sin copiar su esquema físico ni su complejidad**.

La auditoría de Codex en la carpeta de Drive `POS` — `00-fuentes-y-alcance.md`, `01-resumen-arquitectura-items.md`, `02-auditoria-integral-items-ls.md` — distingue código AL, SQL observado e inferencias. En AL/tabla 27 se observó el tipo `Item Type`; en SQL se observó el catálogo común y relaciones de BOM, vinculados y modificaciones. No se certificaron las semánticas precisas de todas las opciones y empaques de LS: Kivo deberá decidirlas y probarlas por separado.

**Modelo de negocio definitivo:**

- **`items`**: única entidad maestra y única identidad de un artículo por restaurante; código comercial único dentro del restaurante, nombre, estado, atributos comerciales y fiscales necesarios. Identificador técnico UUID inmutable y generado por el sistema; nunca pedirlo al usuario.
- **Tipo técnico** (obligatorio): `inventory`, `non_inventory`, `service`. Determina si puede tener movimientos de inventario, tratamiento de costo y validaciones contables; su cambio está restringido cuando hay movimientos/documentos incompatibles.
- **Clasificación funcional** (separada de tipo): producto vendible, ingrediente, empaque, material de consumo y otras categorías reales. Una clasificación puede ser una relación N:M mediante `item_classifications`; **no atar toda la capacidad comercial a un enum excluyente**. Un mismo artículo puede venderse, comprarse y consumirse como componente o empaque según reglas.
- **Capacidades explícitas**: vendible, comprable, aparece en POS, consumible en receta, control de inventario, bloqueos de venta/compra, activo. Validar combinaciones (servicio no genera existencias físicas; empaque puede ser inventariable o no).
- **Unidades**: `item_units` referidas a unidad base, compra y venta con conversión exacta y validaciones de magnitudes. La descripción no determina equivalencia.
- **Precio/costo**: costos y precios del artículo, preparación para listas de precios y vigencias; los valores de ventas contabilizadas deben mantener snapshots históricos.
- **Inventario**: un **libro lógico autoritativo** de movimientos con `item_id`, restaurante, ubicación, unidad base, cantidad, costo y origen/idempotencia; saldo derivado/materializado del libro, no campo fuente en `items`. No se duplican movimientos existentes.
- **Relaciones separadas por dominio**: receta y componentes, reglas contextuales de consumo/empaque, artículos vinculados/adicionales, opciones/modificadores, menú POS, ventas y cocina. Todas las referencias nuevas a artículos utilizan `item_id`; no duplicar nombres/costos como fuente actual, salvo snapshots históricos necesarios en transacciones.
- **Seguridad**: multiempresa por `restaurant_id`, FKs tenant-consistentes, RLS y validación de permisos backend en operaciones directas y RPC `SECURITY DEFINER`.

**NO hacer:** `packaging_items` como segundo maestro permanente, maestros en espejo indefinido, identificadores duplicados, saldos autoritativos separados, deducciones por texto «EMPAQUE», políticas solo en Flutter o pantallas que oculten deuda de schema.

### Ejemplos normativos

| Artículo | Tipo | Clasificaciones/capacidades | Inventario |
|---|---|---|---|
| Bolsa para delivery | inventory | empaque, comprable, consumible | sí |
| Servilleta sin kardex | non_inventory | empaque, consumible | no |
| Carne | inventory | ingrediente, comprable, consumible en receta | sí |
| Bebida embotellada | inventory | vendible y, si aplica, componente | sí |
| Hamburguesa preparada | según política de stock | vendible, receta | conforme configuración |
| Servicio de envío | service | vendible, no físico | no |

## 2. Auditoría de estado inicial (no confundir con implementación final)

Migraciones SQL versionadas 001–087: `products`, `packaging_items`, inventarios `inventory_*` y `packaging_*`, `product_packaging_rules`, `sale_items`, recetas, ventas y sincronización poseen FKs y contratos propios. En el laboratorio se reportaron 87/87 migraciones antes del trabajo de maestro; **confirmar el estado real nuevamente antes de cualquier aplicación**.

- Rama `feature/articles-packaging-final-ux` / PR #17: construyó **catálogo visual virtual** de productos y empaques. No satisface el core maestro.
- Rama `feature/item-master-db-foundation` / PR #18: propuso migración `088_item_master_foundation.sql` con backfill, triggers legacy → items, y vistas de stock/movimientos. **NO constituye la arquitectura final**: mantiene escrituras legadas como autoridad y un espejo de tercera tabla. **Congelada; no ejecutar, desplegar ni fusionar** mientras se define su sustitución.
- Las auditorías AUD-007 y FE-E1…FE-E10 son **evidencia histórica**, no órdenes operativas vigentes que puedan reemplazar este plan. Los resultados probados de RLS, autenticación, POS y packaging siguen siendo activos valiosos, no justificación para saltar gates de unificación.
- No asumir que la 088 no está aplicada: Codex debe consultar el ledger `supabase_migrations.schema_migrations` y objetos de schema de la instancia local. Si ya está aplicada, **prohibido editarla y reaplicarla silenciosamente**: preparar migración compensatoria/aditiva según la realidad, con backup y pruebas.

## 3. Modelo de datos objetivo (contratos, no DDL aprobado)

```text
restaurants
  └── items (PK item_id, UNIQUE restaurant + business_code)
        ├── item_categories / item_classifications
        ├── item_units (base, purchase, sale, conversion)
        ├── item_prices (policy, channel, effective dates)
        ├── item_inventory_policies (cost method, negative stock, reorder)
        ├── recipe_components (parent_item_id, component_item_id, version)
        ├── consumption_rules (context, source_item_id?, consumed_item_id, qty, unit)
        ├── linked_items / modifiers (explicit item references)
        ├── menu_items (item_id, visibility by channel/terminal)
        ├── sale_lines (item_id + immutable transaction snapshot)
        └── item_ledger_entries (item_id, location, qty, cost, source, idempotency)
              └── item_stock_balance (projection, never competing authority)
```

Este diagrama es la dirección de arquitectura. **Cada tabla se introducirá solo cuando la auditoría de dependencias y las necesidades de Kivo lo requieran**; prohibido crear tablas vacías por imitar LS Central.

**Reglas críticas:** toda operación que cambie inventario debe ser transaccional e idempotente; anulación revierte movimientos originales, no recalcula reglas actuales; receta y modificador preservan versión/snapshot; ventas, cocina y POS no consumen saldos ajenos a la contabilidad; códigos comerciales no son UUID; recursos cross-tenant nunca se enlazan.

## 4. Fases secuenciales y gates obligatorios

| Fase | Entregable verificable | Gate de salida |
|---|---|---|
| **F0. Censo y contrato del core** | Auditoría real de BD local: conteos, entidades, PK/FK, rutas de escritura, RPC, POS/Drift/offline, consumo/void, roles; modelo relacional final, mapa de compatibilidad, plan de migración y rollback | **G0:** evidencias SQL y diseño firmes; sin migraciones aplicadas y sin UI |
| **F1. Maestro autoritativo** | SQL migratorio sobre laboratorio que establece `items` como única autoridad; categorías/capacidades/unidades esenciales; migración de artículos existentes con claves, costos y controles intactos; contratos compatibles sin escrituras maestras paralelas | **G1:** integridad 1:1, todas las clases/tipos, RLS por rol/tenant, CRUD, sin divergencia ni duplicados |
| **F2. Inventario y relaciones operativas** | Convertir ledgers, compras, recetas, reglas, líneas de venta y sync a referencias canónicas de artículos; compatibilidad temporal con clientes POS antiguos; retiro medible de rutas legadas | **G2:** equivalencia de saldos, costo, compra, venta, receta, empaques, anulación, reenvío y offline; concurrencia y rollback |
| **F3. Interfaz sobre core aprobado** | Único formulario/listado de artículos, filtros y validaciones de capacidades, reglas en Configuración, sin maestro alternativo oculto | **G3:** UX autenticada aprobada por propietario, pantallas con CRUD real, responsive, permisos y accesibilidad |
| **F4. Despliegue controlado** | Migraciones productivas con snapshots/backup, plan de rollout y rollback; monitoreo POS multiversión | **G4:** autorización explícita, comprobación de integridad en staging y ensayo de reversión; nunca desplegar por aprobar solo UI |

**Alcance solicitado ahora:** F0 y F1 de base de datos. **Prohibido comenzar F3/pantallas** por tener una proyección funcional o un build correcto. F2 se planifica desde F0 para que F1 no produzca deuda estructural; se ejecuta antes de considerar la unificación operativa completa.

## 5. Estrategia de migración segura (debe convertirse en checklist ejecutable en F0)

1. Capturar esquema y datos del laboratorio **read-only**, versión exacta, preflight de IDs, duplicados, códigos, referencias cruzadas, precio/costo/unidades y ledger; guardar conteos e indicadores, jamás secretos.
2. Enumerar **cada escritor**: REST, RPC, triggers, Drift local, offline queue, pull, transacciones POS, web admin y servicios. Inventariar rutas que escriben `products` y `packaging_items`; ninguna puede quedar como autoridad definitiva paralela.
3. Elegir preservación de UUID por registro; si colisionan IDs o códigos, diseñar mapeo auditado **sin renumerar transacciones históricas**. No resolver colisiones borrando o sobrescribiendo.
4. Crear el core canónico y migrar relaciones. Durante coexistencia, **solo un dueño de escritura por dato** y adaptadores explícitos versionados para clientes anteriores; compatibilidad con caducidad y condición de retiro. Evitar doble escritura bidireccional y loops de trigger.
5. Stock: reconciliar movimientos por origen+ID y saldo exacto, con huella/idempotencia determinista; no duplicar el costo histórico ni recalcular anulaciones a partir de reglas editadas.
6. Validar SECURITY DEFINER, RLS, roles parciales, otro restaurante, JWT de test y ausencia de bypass por RPC/triggers; validar restricciones del tipo Servicio frente al inventario.
7. Probar bajo transacciones de rollback y datasets sintéticos, luego pruebas POS/sync reales locales; no hacer `supabase db reset`, no tocar producción ni Tentrix.
8. Al cerrar cada gate, actualizar **este mismo archivo** con SHA, entorno, conteos, pruebas verificadas, fallos, riesgo y decisión. No crear otro plan. Evidencias técnicas específicas podrán permanecer en auditorías históricas, sin reemplazar el estado rector.

## 6. Criterios de aceptación no negociables

- Una única autoridad real de alta/edición de artículos (no UNION visual, no espejo definitivo).
- UUID y códigos históricos preservados, o mapeo trazable que no reescriba operaciones contabilizadas.
- Empaques y materias primas son artículos ordinarios; tipo inventario/no inventario se combina con capacidades/roles independientes; Servicio no genera stock físico.
- FK y RLS multiempresa para cualquier relación; sin permisos concedidos por mostrar un menú.
- Movimientos, saldos, costos, recetas, ventas, reversión, consumo y sincronización coherentes e idempotentes.
- POS antiguo continúa operando durante ventana de transición sin ser fuente paralela de verdad.
- No se fusiona `main`, despliega ni retira tablas hasta autorizarlo tras pruebas.
- Prohibido afirmar completado por número de migraciones, HTTP 200, tests focalizados o ausencia de errores en widgets.
- Si `flutter analyze` permanece inconcluso, registrar el hecho: no certificarlo por sustitución con build Web.

## 7. Control de cambios y avance — actualizar EN ESTE ARCHIVO

| Fecha | Etapa | Referencia | Evidencia | Resultado / gate |
|---|---|---|---|---|
| 2026-11-06 | Auditoría inicial empaques | AUD-007 | Separación original de entidades/UX; riesgos de venta, RLS y sync | Histórico; no representa nuevo core |
| 2026-11-08 | Catálogo visual de Artículos | PR #17, `d9a4db62000d6cb88a9cc119ef337abfa53971f6` | Codex informó 126/126 tests focalizados, build Web y preview 8092 | **Solo UX/proyección**, no core |
| 2026-11-10 | Propuesta maestro espejo | PR #18 / migración 088 | Tabla nueva + triggers sobre fuentes legadas, sin auditoría real del lab aquí | **CONGELADA / NO APROBADA** |
| 2026-11-10 | Auditoría externa LS Central | Drive carpeta POS, 4 ficheros | `Item` AL tabla 27; SQL BOM, vinculados, modificadores; límites expresos | **Decisión core único ratificada** |
| 2026-11-10 | Plan rector actualizado | este documento | Objetivo autoritativo, gates F0–F4, no maquillaje UI | **F0 PENDIENTE** |

### Plantilla obligatoria de actualización

Al completar trabajo, editar la fecha/estado de cabecera, la fila de fase y añadir una línea aquí con: `fecha | fase | rama/SHA | schema/migraciones | tests con conteos y exit codes | anomalías | gate/decisión | siguiente trabajo permitido`. No inventar aprobaciones ni abrir otro plan. Si hay decisión de arquitectura nueva, agregar sección **ADR breve dentro de este archivo**, con motivación, alternativas, riesgos y fecha.

## 8. Referencias y precedencia documental

1. **Este plan rector**: fuente operativa de arquitectura, etapas, gates y estado actual.
2. **AUD-007** (`Documentation/Auditorias/AUD-2026-11-06-007-integracion-reorganizacion-empaques.md`): hallazgos originales y riesgos. La recomendación de catálogo virtual allí era **transitoria**; no prevalece sobre la decisión actual de core persistente.
3. **FE-E10** (`Documentation/Auditorias/FasesEmpaques/FE-E10-2026-11-10-maestro-articulos-db.md`): evidencia estática y descripción histórica de PR #18; su migración 088 permanece congelada.
4. **Investigación LS Central**: carpeta privada `POS` de Google Drive, `02-auditoria-integral-items-ls.md`, `01-resumen-arquitectura-items.md`, `00-fuentes-y-alcance.md`. Evidencia AL/SQL/hipótesis separadas.
5. **Microsoft Learn**: https://learn.microsoft.com/es-es/dynamics365/business-central/inventory-about-item-types (tipos de artículo; inspiración conceptual, no schema obligatorio).
6. Normas de implementación `AGENTS.md`, `CONTEXTO_PROYECTO.md` y QuantixEngineeringStandar aplicable.

**Jerarquía de autoridad:** requisitos acordados del core y este plan > contratos de seguridad/integridad verificados > historial de auditoría > soluciones transitorias de interfaz. Un PR o Codex no modifica la arquitectura por su cuenta. Cualquier contradicción se documenta aquí antes de ejecutar código.

## 9. Próxima acción autorizada

**F0: inventario read-only y diseño relacional detallado del core y transición.** Confirmar estado real de migración 088 y FKs del laboratorio; **sin aplicar 088, sin crear nuevas tablas, sin editar pantallas**. El desarrollo de F1 se autorizará solo al cerrar G0 con la evidencia correspondiente.

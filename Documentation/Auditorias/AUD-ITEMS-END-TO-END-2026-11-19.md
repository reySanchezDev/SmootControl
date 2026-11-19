# Auditoría técnica — Items end-to-end

**Fecha:** 2026-11-19  
**Estado:** borrador independiente para aprobación del propietario. NO autoriza correcciones, migraciones ni despliegues.  
**Base inmutable revisada:** main `4181999ee58ba9eb65ec96d13b48de95ee2669cb`; PR #40 fusionado, HEAD de integración `26ce371044ec4a137105cc9e16014215d47c6cc0`.  
**Rama del informe:** `audit/items-end-to-end-2026-11-19`.

## 1. Dictamen ejecutivo

La integración contiene avances arquitectónicos reales, pero no procede certificar cierre integral. Se detectan rutas de compatibilidad todavía disponibles, divergencias potenciales entre modelo canónico y proyecciones locales, riesgos de atomicidad y de actualización de catálogo y documentación que no refleja el estado final. No se recomienda reescribir el sistema ni retirar objetos históricos indiscriminadamente.

Esta es una auditoría **estática dirigida por riesgos** sobre los contratos y fuentes del SHA indicado. Se inspeccionó el árbol de 1599 entradas y se abrieron archivos críticos de los flujos. No se ejecutó Flutter, PostgreSQL, Docker, navegador, ni POS; no se consultó la base productiva. No equivale a un barrido completo línea por línea de todo el repositorio ni a certificación RLS o E2E. Los hallazgos identifican condiciones verificables en código y escenarios a reproducir. Una tentativa de lectura masiva excedió el límite de llamadas del conector; por ello el inventario de tamaños/hardcodes es muestral. No se afirma que no existan otros defectos o secretos.

## 2. Criterios normativos

Fuentes: `AGENTS.md`, `rules.md`, `Documentation/Standards/{ENGINEERING_STANDARD,UX_UI_STANDARD,COMPONENT_CONTRACTS,SMOOCONTROL_RULES}.md`; repositorio central [QuantixEngineeringStandar](https://github.com/reySanchezDev/QuantixEngineeringStandar), revisión adoptada declarada 0.1.9, commit 0c7c7b69bd77ab009fb0b0ce4d12c15f62371d14. Se contrastaron reglas centrales de ingeniería, UX y proyecto. No adoptar silenciosamente revisiones posteriores.

ENG-001 reutilización; ENG-002 causa raíz; ENG-003 autoridad única; ENG-004 necesidad de capas/migraciones; ENG-005 documentación; ENG-006 seguridad; ENG-007 regresión; ENG-008 identificadores; ENG-009 colaboración. SMO-001 300 líneas; SMO-002 separación Admin/POS; SMO-005 permisos; SMO-008 evitar pantallas paralelas; SMO-009 acciones por selección; SMO-010 protocolo (existe colisión documental, hallazgo D02). UX-025 protección de cambios; UX-037/038 consistencia; UX-048 edición en misma pestaña; reglas locales de i18n ARB, tokens, credenciales y cola offline. Las pruebas y fixtures pueden usar constantes deliberadas; los enums y códigos técnicos de contrato no son automáticamente hardcoding indebido.

## 3. Hallazgos priorizados

Severidad Alta = riesgo de integridad, indisponibilidad, seguridad o promoción; Media = incumplimiento de estándar, mantenibilidad o evidencia relevante. Estado C = constatación estática; R = riesgo cuya materialización debe reproducirse; P = pendiente de decisión, no defecto por sí solo.

| ID | Severidad | Estado | Hallazgo |
|---|---|---|---|
| A01 | Alta | C/R | Ruta de Productos legacy bajo flag y carga inicial innecesaria |
| A02 | Alta | C/R | Sender de ventas alternativo no atómico |
| A03 | Alta | C/R | Proyección POS separada de snapshot y metadatos |
| A04 | Alta | C/R | Proyección de empaques/stock puede dejar residuos |
| A05 | Alta | C/R | Puente de empaques aún depende de origen técnico |
| A06 | Alta | C/R | DROP CASCADE destructivo sin preflight en migración |
| A07 | Alta | R | Versionado de catálogo y cola: ACK no prueba drenaje |
| A08 | Alta | R | Clasificación comercial de revisión puede omitir cambios relacionados |
| A09 | Alta | C/R | Movimiento canónico no valida tracking en la primitiva |
| A10 | Alta | R | Permisos y aislamiento de helpers históricos por confirmar |
| U01 | Media | C | Modales de edición de catálogos y recetas |
| U02 | Media | R | Protección de cierre de ficha fuera de Regresar |
| H01 | Media | C | Textos UI fuera de ARB |
| H02 | Media | C/R | Categoría sintética, constante de orden y JSON vacío en proyección |
| H03 | Media | C/R | Rol admin fijo habilita acciones sin consultar permisos efectivos |
| E01 | Media | C | Archivos manuales exceden SMO-001 |
| E02 | Media | C/R | Migraciones encadenadas con sustitución textual de funciones |
| E03 | Alta | C/R | CI no prueba por sí solo cadena real de migraciones y E2E |
| D01 | Media | C | Plan Rector con gates desactualizados, mojibake y estados contradictorios |
| D02 | Media | C | Colisión de identificadores normativos y norma de rama histórica |
| D03 | Media | C | CONTEXTO_PROYECTO desactualizado |
| P01 | Media | P | Reclasificación mantiene bloqueo hasta decisión/contrato aprobado |

## 4. Detalle de hallazgos

### A01 — Alta — una sola pantalla operativa debe ser realmente canónica
**Evidencia:** `lib/features/products/presentation/pages/articles_page.dart`, initState/_load y build (últimas ~20 líneas). Inicializa _future = _load() incluso si el define SMOO_ITEM_CORE_V2_QA está activo. _load consulta getProducts/getPackagingItems; rama alternativa contiene _editProduct/_editPackaging con showDialog. `tool/build_web_release.ps1` añade el define y SMOO_APP_MODE solo en -CanonicalItemsQa. Migración 117 elimina products. `canonical_items_content.dart` todavía se describe QA-only.
**Impacto:** compilación sin el flag vuelve al modelo anterior; incluso con flag hay una carga no necesaria. No se ha confirmado qué defines tiene el bundle productivo.
**Corrección:** consolidar ArticlesPage como ruta real canónica, eliminar lectura legacy innecesaria tras demostrar cero clientes dependientes. Configuración de modo explícita por plataforma; no usar flag de QA como contrato de publicación. Conservar compatibilidad offline distinta del catálogo admin.
**Aceptación:** build RELEASE de producción y QA con configuración soportada; rastrear tráfico de inicio y comprobar ausencia de llamadas a catálogo legacy, CRUD/F5 y UX-048.

### A02 — Alta — ventas y atomicidad
**Evidencia:** `lib/features/sync/data/datasources/supabase_sync_remote_sender_sales_part.dart` líneas 4–~100; _pushSale envía RPC con dispositivo; si no hay credenciales de dispositivo pero existe token remoto y payload no versionado, ejecuta _upsert sales, _upsert sale_items, luego _applyInventoryMovement, _applyPackagingMovement y void por separado. No hay transacción remota que abarque esas llamadas.
**Impacto:** fallo intermedio puede dejar cabecera/líneas/movimientos parcialmente persistidos si este camino está autorizado. Puede también fallar si esquema/permisos ya no admiten legacy. No se afirma explotación ni ocurrencia productiva.
**Corrección/aceptación:** inventario de colas antiguas; migrar o bloquear explícitamente ruta sin dispositivo, no perder pendientes. Una RPC autorizada y atómica por venta. Inyectar fallo después de cada etapa; comprobar stock, folio, líneas y reintento sin duplicado.

### A03 — Alta — frontera transaccional del pull
**Evidencia:** `supabase_catalog_pull_service.dart` ~273–282 llama sucesivamente ItemCatalogSnapshotApplier.apply, CanonicalItemPosProjector.project y ACK. Applier escribe metadatos en su transacción; projector hace transacción aparte. La transacción de datos de otros catálogos termina antes.
**Impacto:** fallo entre etapas puede dejar metadatos nuevos y vistas POS antiguas antes del ACK; riesgo de que venta tome revisión que no representa lo que realmente ve. También hay riesgo con refresh concurrente. ACK posterior es positivo pero insuficiente por sí solo.
**Aceptación:** interrumpir proceso entre commit snapshot/proyección/ACK, reiniciar y vender; no permitir venta con revisión incorrecta; testar dos pulls concurrentes y protección de cola. Diseñar unidad atómica de datos+proyección+metadatos y ACK posterior o estado explícito de readiness. No reportar como bug reproducido hasta prueba.

### A04 — Alta — residuos de catálogo y saldo local
**Evidencia:** `canonical_item_pos_projector.dart` 46–~125 upsert de localPackagingItems/localPackagingStock cuando clase packaging y tracking; stock de productos se inserta solo si tracking y fila visible. Bloque final ~130–145 solo inactiva localProducts no visibles; no hay reconciliación equivalente de empaques/saldos en ese método. `supabase_catalog_pull_service.dart` 185–198/246–250 actualiza también catálogo legacy de empaques.
**Impacto:** tras retirada, cambio de clase o tracking, posible empaque activo/saldo obsoleto o divergencia entre lectores. La otra fase de pull podría compensar algunos casos; verificar precedencia y no confundir proyección local con segundo maestro remoto.
**Aceptación:** snapshots consecutivos con cambios de actividad, visibilidad, clase y tracking; dos dispositivos y dos tenants; conservar movimientos/ventas ya capturados, no borrar por ausencia parcial ni sobrescribir deltas offline pendientes.

### A05 — Alta — procedencia aún condiciona empaques
**Evidencia:** migración 123, helper apply_canonical_packaging_movement filtra source_kind='packaging'; el hook del RPC bifurca por existencia en packaging_items. `filter_legacy_packaging_movements` conserva filas según tabla legacy. `canonical_item_pos_projector.dart` selecciona por itemClass. Migración 121 fija source_kind según clase al crear y restringe cambio. 
**Impacto:** dos criterios de encaminamiento (“función” vs “origen”). El helper inserta inventory_movements incluso si no tracks_inventory, aunque no modifica saldo: verificar si el contrato de Movimientos (solo consumo físico) se viola. Posible divergencia de ledger o reportes. No eliminar las tablas todavía.
**Aceptación:** compra/venta/anulación para empaque con y sin fila legacy, rastreable/no rastreable, verificar autoridad única, cantidad y referencialidad. Establecer compatibilidad explícita por contrato y retirar trigger/tabla solo con evidencia.

### A06 — Alta — eliminación destructiva
**Evidencia:** `supabase/migrations/117_remove_legacy_product_catalog.sql` líneas 2–10 comenta que es intencionalmente destructiva para QA y ejecuta cinco DROP TABLE ... CASCADE, sin preflight ejecutable en ese archivo. Plan Rector exige cero dependencias y no usar CASCADE como atajo.
**Impacto:** posible pérdida de datos o eliminación de objetos dependientes al promover. El documento contiene afirmaciones posteriores de paridad 001–119, no comprobadas por este auditor. No reaplicar ni editar una migración instalada para “corregirla”.
**Aceptación:** identificar estado real por ambiente, backup restaurado, conteos y mapeos previos/posteriores, pg_depend, funciones, grants, vistas, FKs, triggers y smoke tests. Si ya se aplicó, auditar efectos y reparar aditivamente; si no, plan explícito de despliegue y preflight independiente. No ejecutar DDL productivo desde esta auditoría.

### A07 — Alta — ACK no es prueba de ausencia de operación pendiente
**Evidencia:** migraciones 129–130. ACK registra revisión/snapshot V3 por dispositivo; trigger de cambio de clase consulta que todos los activos estén al día. No comprueba en ese helper cola no sincronizada, carrito abierto ni ventas en vuelo; una terminal sin conexión puede haber ACK antes de generar venta. 131 permite reintentos existentes y cambios exclusivamente comerciales.
**Impacto:** ACK no es barrera distribuida de corte. Una operación ya cobrada con catálogo viejo puede quedar rechazada; también debe preservarse anulación histórica. No habilitar cambio de clase solo con ACK.
**Aceptación:** concurrencia venta/cambio de tipo/reclasificación, dos terminales, terminal desconectada, cola antigua, reintento de venta ya aceptada y anulación. Definir política de resolución explícita, no relabel de payload ni descarte de venta. Si se mantiene reclasificación bloqueada, documentar esa limitación.

### A08 — Alta — clasificación de cambios comerciales
**Evidencia:** migración 131, classify_item_catalog_edit compara únicamente NEW/OLD de items excluyendo name, category_id, commercial_code, base_unit_price, base_unit_cost y updated_at. Usa GUC de transacción; bump registra kind y lo limpia. Migración 121 modifica item_classification_links después del upsert del artículo, antes de bump; no se observa clasificación de links en 131.
**Riesgo:** una edición de artículo con cambio de relaciones o capacidades indirectas podría etiquetarse commercial cuando debería ser operational, según semántica efectiva de dichas relaciones y triggers instalados. Asimismo validar costo de componentes/costo de venta snapshot antes de considerar cambios de costo “inocuos”. No se afirma que cada clasificación sea operativa.
**Aceptación:** matriz de cada escritor/tabla y revisión resultante, edición de nombre/precio/costo, links, receta, unidades, reglas, tipo, estado, múltiples modificaciones en transacción; huecos de historial y retry idempotente. Verificar función activa mediante pg_get_functiondef.

### A09 — Alta — autoridad de stock en primitiva
**Evidencia:** migración 126 redefine apply_inventory_movement_v2; selecciona item_class, no tracks_inventory ni item_type, crea inventory_stock y movimiento. La 128 deriva tracking del tipo, y restringe desactivación con saldo no cero, pero no cambia esta primitiva.
**Impacto:** si un caller no filtra inventariables, puede producir saldo para un artículo sin tracking. No concluir acceso directo de cliente: 125 revoca ejecución pública y concede service_role.
**Aceptación:** auditar todos los callers efectivos (purchase, adjustment, sale, void, staff, recipe), probar servicio/no inventariable, saldo cero con historial, concurrencia de cambio de tipo y movimiento. Mantener reversas originales y excepción negativa de receta sin ampliar indebidamente. Guardas de servidor, no solo UI.

### A10 — Alta — autorización de helpers y RLS
**Evidencia:** migración 123 filter_legacy_packaging_movements es SECURITY DEFINER y concede EXECUTE a authenticated; acepta restaurante y payload sin comprobación de tenant en su cuerpo, filtra por el restaurante solicitado. No expone filas completas ajenas, pero permite comprobar pertenencia de UUIDs proporcionados si no hay otra protección. Las funciones previas renombradas también exigen inventario ACL; 128 sí revoca su helper anterior.
**Aceptación:** pg_proc/proacl, owners, search_path, revocaciones de roles heredados, default privileges, todas las tables/policies y RPC con anon, usuario sin permiso, POS, tenant ajeno y admin. Revocar accesos directos a helpers internos si no son API; usar pruebas JWT reales. No afirmar filtración de datos ni seguridad certificada sin pruebas.

### U01 — Media — UX-048 incompleta
**Evidencia:** `articles_page.dart` rama legacy utiliza CreateProductDialog y _ArticlePackagingDialog. `canonical_items_content_actions_part.dart` líneas 28/65 abre CanonicalRecipeDialog y CanonicalPackagingRulesDialog. `recipes_page.dart` ~87 usa showDialog. La ficha principal sí está embebida en IndexedStack.
**Corrección:** reutilizar editor/página operativa con misma pestaña para maestros; confirmar alcance de diálogos de reglas como subeditor frente a edición de registro (no prohibir confirmaciones ni capturas transaccionales). No crear páginas de demostración. Verificar selección, permisos, filtros, orden, paginación, Regresar, viewport, contraste, teclado.

### U02 — Media — cambios pendientes fuera de Regresar
**Evidencia:** `canonical_item_editor.dart` _hasChanges/_back solicita confirmación al regresar; no se demuestra desde ese archivo protección al cerrar pestaña del workspace, cerrar sesión o navegación externa. UX-025 requiere proteger abandono; cambiar de pestaña sin cierre no debe interrumpir.
**Aceptación:** modificar campo, cambiar pestaña y volver, cerrar pestaña, logout, fallo de guardado, recarga de navegador; guardar/descartar/seguir editando conforme al estándar. Mantener valores en fallo.

### H01 — Media — i18n
**Evidencia:** rules.md ~137 prohíbe textos UI hardcodeados fuera de ARB. `canonical_item_editor.dart` ~122,177–178,203,221: mensajes y botones en español literal. `canonical_item_editor_fields_part.dart`: Información general, Nombre *, Unidad base *, secciones y switches, aunque algunos labels ya usan l10n. `articles_page.dart` mensajes y tipos literales. `canonical_item_pos_projector.dart` nombre Sin categoría persistido en modelo local.
**Corrección:** migrar cadenas visibles a ARB/strings compartidos; diferenciar mensajes de máquina, enums, claves i18n y datos reales. Prueba en todos los idiomas soportados. No cambiar textos de negocio almacenados por traducción indiscriminada.

### H02 — Media — constantes de proyección
**Evidencia:** `canonical_item_pos_projector.dart`: _uncategorizedId='__canonical_uncategorized__', nombre Sin categoría, sortOrder 999999, optionGroupsJson y modifierGroupIdsJson='[]', isRawMaterial=false en proyección vendible. Son valores de fallback o adaptación, no necesariamente datos reales.
**Riesgo:** ID sintético global en almacenamiento local con varios tenants, pérdida de grupos/modificadores si esta proyección es sobrescritura final, traducción y orden inesperados. 
**Aceptación:** artículo sin categoría, artículo con modificadores/unidades, reglas de precio, cambios de restaurante; comprobar snapshot y producto proyectado. Definir sentinel local con scope explícito y documentar fallback; no fijar IDs comerciales reales. No se ha confirmado pérdida funcional.

### H03 — Media — rol fijo
**Evidencia:** `canonical_catalog_access.dart` retorna ambos permisos si session.roleId == DefaultAccessRoles.adminId; `default_access_roles.dart` define 'role-admin'. `articles_page.dart` tiene bypass equivalente. 
**Riesgo:** UI diverge de permisos efectivos por tenant/rol; el servidor puede denegar correctamente, pero habilitar acciones no autorizadas viola SMO-005. El identificador reservado puede estar previsto en POS local; demostrar correspondencia en admin remoto.
**Aceptación:** role admin real vs rol sintético, rol sin derechos, cambio de permisos durante sesión; validar servidor, no eliminar seguridad del backend.

### E01 — Media — SMO-001
**Evidencia muestral de líneas físicas no vacías al final (incluye líneas interiores):**
- lib/features/sync/domain/entities/item_catalog_snapshot_v2.dart: 568.
- lib/features/sync/data/datasources/supabase_catalog_pull_service.dart: 311.
- Se verificaron bajo límite: articles_page.dart 290; canonical_items_content.dart 279; canonical_item_editor.dart 244; canonical_item_editor_fields_part.dart 281.
El estándar permite tratamiento documentado de legado/generado. Confirmar excepción para archivos modificados; no dividir artificialmente.
**Aceptación:** inventario automatizado de todos los archivos manuales nuevos/modificados respecto de base; refactor por responsabilidad, prueba de regresión. El workflow YAML largo y SQL histórico no se clasifican automáticamente como infracción sin determinar tratamiento normativo.

### E02 — Media — cadena SQL frágil
**Evidencia:** 124, 127, 129, 130 y 131 utilizan pg_get_functiondef/replace con marcadores textuales. Varias redefiniciones y wrappers acumulan lógica. Tienen guardas de marcador ausente, pero alta sensibilidad al orden/formato/estado de migración.
**Corrección:** congelar migraciones aplicadas; versión posterior consolidada cuando se apruebe, con contratos explícitos y pruebas de upgrade. No “limpiar” el historial mediante edición.
**Aceptación:** aplicar cadena en clon base representativo y base actual, validar firma/cuerpo/ACL, repetición controlada, diferencias estructurales y rollback según alcance.

### E03 — Alta — cobertura certificable
**Evidencia:** .github/workflows/item-core-quality.yml ejecuta varios contratos de supabase/design/*_DRAFT.sql y fixtures aislados; .github/workflows/item-core-web-qa.yml usa URL invalid.example, qa-placeholder, UUID sintético y etiqueta compile-only. Existen tests reales de 095/096/097 y SQL de compras/empaques/recetas. Los valores dummy de CI no constituyen secretos ni hardcode de producción.
**Impacto:** éxito CI no prueba que todas las migraciones reales 089–131 estén instaladas correctamente ni POS/offline en runtime. No se consultaron logs completos del merge ni se ejecutaron suites aquí.
**Aceptación:** pipeline de instalación/upgrade real en Supabase aislado, inventario de esquema/ACL, pruebas E2E autenticadas y dos dispositivos, build RELEASE real y QA visual propietario. Adjuntar SHA y evidencia reproducible. No aplicar 088 fuera del procedimiento aprobado; verificar su situación histórica exacta en cada ambiente.

### D01 — Media — Plan Rector
**Evidencia:** Documentation/Planes/EJECUCION-CODEX-EMPAQUES-END-TO-END.md (~2079 líneas) tiene checklists F1/F2/F3 pendientes, addenda de paridad y cierre que no se reconcilian; sección “Addendum de implementaciÃ³n” y texto mojibake visibles. Afirma estado remoto hasta 119 en un momento y otras secciones solo local. No hay un acta final inequívoca del merge 4181999, gates, versiones y pendientes 128–131.
**Corrección:** conservar historia, añadir portada de estado vigente y matriz de evidencias SHA/fecha/ambiente; distinguir merge, despliegue, migración, CI, QA visual. Corregir codificación UTF-8 en cambio documental aprobado.

### D02 — Media — divergencia del estándar
**Evidencia:** AGENTS.md fija 0.1.9 pero llama UX-041 a feedback modal, mientras estándar central UX-041 trata IDs internos. SMO-010 local se usa para estados vacíos, central para protocolo Kivo. AGENTS.md conserva instrucción de trabajar develop/backoffice-v2 aunque PR #40 está integrado a main.
**Corrección:** sincronizar revisión central exacta, corregir identificadores sin inventar normas, conservar obligaciones de feedback y formularios aunque cambie su ID. Actualizar rama de continuidad para fase posterior; no hacer cambios al estándar universal sin ratificación.

### D03 — Media — continuidad
**Evidencia:** CONTEXTO_PROYECTO.md ~142 líneas describe como trabajo actual feature/packaging-e2e-rule-consumption, SHA ede5bb1, tests no ejecutados y referencias de 6 de noviembre, anteriores al merge del 19. Hay enlaces a documentos históricos cuya presencia debe comprobarse.
**Corrección:** actualizar sección estado y handoff con integración actual, último SHA aprobado, límites de QA y referencias válidas. No borrar historial útil.

### P01 — Decisión pendiente — reclasificación
**Evidencia:** migración 121 rechaza item_class_identity_conversion_not_allowed; editor deshabilita selector para existentes. 130 incorpora ACK antes de cambio de clase, pero esto no autoriza quitar la restricción. Caso del artículo 4 y plan documental de reclasificación siguen siendo relevantes.
**Conclusión:** no es incumplimiento automáticamente porque el propietario aún no ha aprobado el contrato de conversión. No habilitar dropdown por comodidad; definir dependencias, saldo, histórico, origen y barrera de POS. Separar clasificación de tratamiento inventariable. Mantener 128 como autoridad actual del tipo mientras no se apruebe otro modelo.

## 5. Cobertura end-to-end y siguiente evidencia

| Flujo | Estado de esta auditoría | Prueba exigida para cierre |
|---|---|---|
| Artículos, unidades, clases, categorías, códigos | Lectura parcial de contrato/UI | CRUD JWT, numeración concurrente por tenant, F5, campos técnicos invisibles, cambio de tipo con saldo |
| Inventario, compras, ajustes | Contrato y evidencia histórica documental; no runtime | mezcla de clases, stock cero, compra/ajuste, concurrencia, negativos y unidades |
| Recetas, empaques y modificadores | Riesgos de proyección/puentes identificados | receta multinivel, consumo por línea/pedido/sales type configurado, no doble consumo, modificadores y costo |
| POS y ventas | Sender, snapshot, ACK y guards inspeccionados | dos terminales, ventas online/offline, reintentos, colas antiguas, folios, fallo parcial |
| Anulaciones | Contratos 126–131 y riesgos estáticos | reversión original después de editar precio/receta/tipo, anulación idempotente, saldo negativo permitido solo según contrato |
| Personal/nómina | Evidencia histórica del plan; no revisión profunda de todos los escritores | consumo/edición/eliminación y nómina cerrada; reintentos y seguridad |
| Reportes y costos | Evidencia documental; no conciliación DB | venta/void, costos históricos, stock/ledger/reportes, unidades decimales |
| Seguridad | Inspección de funciones seleccionadas | matriz JWT, pg_depend/ACL/RLS y escaneo de secretos sin reproducir valores |
| Estándares UI y código | Muestra de archivos y documentación | auditoría automática completa de líneas/i18n/tokens y QA responsive sobre release real |
| Documentación | Plan Rector, AGENTS, contexto y reglas contrastados | acta vigente, matriz de gates y revisión central exacta |

## 6. Orden recomendado de remediación (solo después de aprobación)

1. Verificar estado real de main/producción/laboratorio, migraciones, backup restaurable y CI. No revertir automáticamente el merge.
2. A01–A05 y A09: unificar autoridad operativa, eliminar rutas de escritura no atómicas y cerrar proyecciones/ledger con pruebas.
3. A06–A08 y A10: validar efectos destructivos ya ocurridos, seguridad y transición de catálogo/colas; decidir compatibilidad. No habilitar reclasificación sin decisión.
4. E01–E03, H01–H03 y U01–U02: reforzar CI, estándares, i18n/permisos y UX sin pantallas duplicadas.
5. D01–D03: actualizar estado documental y evidencias en cada corrección.
6. Gate final: Docker local, JWT real, dos terminales o simulación equivalente aprobada, rollback/datos de prueba controlados, Flutter análisis y tests, RELEASE por script oficial, QA visual del propietario. Promoción separada y autorizada.

## 7. Entrega y límites

Este informe es el único artefacto agregado a la rama de auditoría. No contiene correcciones de código. No se abrió PR ni se fusionó. Se podrá editar/eliminar antes de aprobar. El propietario decide qué hallazgos acepta; Codex puede consultar esta rama sin incorporarla a main y debe reportar evidencia y commits sobre una rama de remediación acordada. Mantener separación de hallazgos comprobados y riesgos; no declarar 100% de cumplimiento ni fallos productivos no observados.

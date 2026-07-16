# Plan Vivo: Recetas, Materias Primas y Explosion de Inventario

## Estado

- Fecha de creacion: 2026-07-15
- Fase actual: implementacion por etapas
- Objetivo: soportar productos compuestos con recetas, unidades de medida,
  conversion a unidad base y descarga de materias primas al sincronizar ventas
  POS en Supabase.
- Regla principal: no romper produccion ni los datos existentes.

## Principios Del Proyecto Que Aplican

- Admin lee y escribe directo en Supabase.
- POS sigue offline-first y sincroniza ventas despues.
- Supabase debe ser la autoridad para aplicar inventario final de ventas.
- En la primera version de recetas, la falta de materia prima no debe bloquear
  la sincronizacion ni la venta remota.
- La facilidad de inventario negativo aplica solo al stock de materias primas
  consumidas por explosion de receta. Un producto vendible puede tener receta,
  pero el negativo no aplica al stock propio del producto vendido ni a empaques.
- Esta facilidad debe depender de una regla de negocio configurable, no de una
  constante en codigo.
- No se debe quemar consecutivo ni duplicar movimientos por reintentos.
- Toda migracion remota necesaria debe crearse y aplicarse en la misma etapa de implementacion.
- Cualquier cambio Drift debe ser no destructivo y probado como actualizacion sobre APK existente.
- No exponer ids tecnicos en pantallas.
- Archivos Dart nuevos o modificados deben mantenerse bajo 300 lineas.

## Situacion Actual Auditada

### Productos

- Tabla remota `products` ya tiene `is_raw_material`.
- Tabla local `LocalProducts` ya tiene:
  - `isRawMaterial`
  - `tracksInventory`
  - `priceInCents`
  - `costInCents`
- La pantalla de productos ya permite distinguir producto vendible y materia prima.
- El catalog pull descarga `is_raw_material` y evita mostrar materias primas en
  POS, pero la mejora debe ir mas lejos: el POS no debe descargar productos de
  tipo materia prima como parte del catalogo operativo de venta.

### Inventario

- Stock local actual: `LocalInventoryStock.quantityOnHand` es entero.
- Stock remoto actual: `inventory_stock.quantity_on_hand` se usa como cantidad entera.
- Movimientos actuales:
  - `purchase`
  - `sale`
  - `sale_void`
  - `adjustment`
- `apply_inventory_movement` valida stock suficiente y evita duplicados por `movement_id`.
- Compras admin por lote actualizan stock remoto y costo actual del producto.

### Ventas POS y Sync

- POS guarda ventas localmente y encola `sales`.
- Payload actual incluye:
  - `sale`
  - `items`
  - `inventoryMovements`
  - `packagingMovements`
- Hoy el POS genera movimientos de inventario local por producto vendido si `tracksInventory = true`.
- Supabase sincroniza por RPC `pos_sync_sale`.
- Supabase ya filtra movimientos viejos segun reglas remotas actuales con `pos_sale_payload_for_current_stock_rules`.
- Staff consumption usa flujo similar con `pos_sync_staff_consumption`.

### Reportes

- Reportes de venta/costo usan `sale_items.unit_cost` historico.
- Reporte de valor de inventario usa productos y stock.
- La futura receta impactara:
  - costo real de productos compuestos;
  - costo de venta;
  - valor de inventario;
  - movimientos de inventario;
  - auditoria de ventas.

## Problemas A Resolver

1. Productos compuestos no consumen materias primas reales.
2. Materias primas pueden comprarse en una unidad y consumirse en otra.
3. Algunas recetas pueden consumir otras recetas.
4. La descarga debe ocurrir al sincronizar venta en remoto.
5. El POS debe seguir operando offline.
6. Datos existentes no tienen receta configurada.
7. Stock actual usa enteros, pero recetas requieren decimales o unidades menores.
8. No se deben duplicar consumos si una venta se reintenta.
9. Anulaciones deben reintegrar materias primas explotadas.
10. Reportes deben poder distinguir costo estimado historico vs costo por receta.
11. El catalogo POS debe sincronizar solo productos vendibles, no materias primas.
12. Cada producto que participe en inventario/receta debe tener unidad base para
    convertir compras y consumos de receta de forma consistente.

## Decision De Arquitectura Recomendada

### Enfoque

Implementar recetas remote-first para Admin y explosion remote-authoritative en Supabase.

El POS no debe calcular la explosion completa en V1 de recetas. El POS seguira
vendiendo productos finales y enviando ventas normales. Supabase, al aceptar la
venta, explotara la receta vigente y aplicara movimientos de materias primas.
Durante el primer release de recetas, la explosion no debe bloquear la venta si
falta materia prima; ese caso debe quedar registrado como alerta operativa o
movimiento pendiente de regularizacion segun la etapa implementada.

### Por que remoto

- Evita divergencias entre tablets.
- Permite corregir recetas sin reconstruir APK.
- Hace idempotente la aplicacion de inventario.
- Respeta que Admin es remoto directo.
- Centraliza conversiones y recetas anidadas.

### Rol Del POS

- Mostrar y vender productos finales.
- Seguir offline.
- Sincronizar ventas FIFO.
- Recibir stock actualizado al sincronizar catalogos.
- Descargar solo productos vendibles en el catalogo operativo de POS.
- No descargar materias primas como productos seleccionables ni como catalogo
  operativo innecesario.
- Opcional en fase posterior: validacion local aproximada de disponibilidad.

## Modelo De Datos Propuesto

### Unidad De Medida

Nueva tabla remota `measurement_units`:

- `id uuid`
- `restaurant_id uuid`
- `code text`
- `name text`
- `unit_type text`
- `base_factor numeric(18, 6)`
- `is_base boolean`
- `is_active boolean`
- `created_at timestamptz`
- `updated_at timestamptz`

Ejemplos:

- unidad: base_factor `1`
- docena: base_factor `12` hacia unidad
- gramo: base_factor `1`
- kilogramo: base_factor `1000` hacia gramo
- onza: base_factor segun unidad base elegida
- litro/ml segun grupo.

Nota: no mezclar tipos incompatibles. Una unidad de masa no debe convertirse a unidad.

### Unidades Por Producto

Cada producto que controle inventario o participe en una receta debe tener una
unidad base/inventario. Esa unidad es la unidad tecnica en la que Supabase guarda
stock y calcula consumos.

Campos requeridos por producto:

- `inventory_unit_id`: unidad base para stock.
- `purchase_unit_id`: unidad usual de compra.
- `purchase_to_inventory_factor`: conversion desde compra hacia unidad base.

Ejemplos:

- Pan hamburguesa:
  - unidad base: unidad
  - unidad compra: bolsa
  - factor: 12
  - compra 3 bolsas => stock base 36 unidades
  - receta consume 1 unidad => descuenta 1 unidad
- Salsa de tomate:
  - unidad base: onza o gramo, segun se defina operativamente
  - unidad compra: galon, litro, botella o bolsa
  - factor: equivalente hacia unidad base
  - receta consume 0.5 onzas => descuenta 0.5 unidades base si base es onza
- Arroz:
  - unidad base: gramo
  - unidad compra: libra o kilogramo
  - receta consume 4 onzas => convertir onzas a gramos y descontar gramos

Reglas:

- La receta puede capturar una unidad distinta a la unidad base del producto.
- La unidad de la receta debe ser compatible con la unidad base del componente.
- Toda cantidad de receta se convierte a `inventory_unit_id` antes de afectar
  stock.
- Si el producto no tiene unidad base configurada, no debe poder usarse como
  componente de receta.

### Extension De Productos

Agregar columnas remotas a `products`:

- `product_kind text not null default 'finished'`
  - `finished`: producto final vendible.
  - `raw_material`: materia prima.
  - `preparation`: receta intermedia no vendible o semi-elaborado.
- `uses_recipe boolean not null default false`
  - indica si el producto explota receta al venderse o consumirse como
    preparacion.
  - permite que un producto sea vendible y con receta a la vez, por ejemplo
    hamburguesa, tacos, enchiladas, smoothies o nachos.
- `purchase_unit_id uuid null`
- `inventory_unit_id uuid null`
- `purchase_to_inventory_factor numeric(18, 6) null`
- `recipe_yield_quantity numeric(18, 6) null`
- `recipe_yield_unit_id uuid null`

Compatibilidad:

- Migrar productos actuales:
  - `is_raw_material = true` => `product_kind = 'raw_material'`
  - `is_raw_material = false` => `product_kind = 'finished'`
- Mantener `is_raw_material` durante transicion para no romper app actual.

### Recetas

Nueva tabla `product_recipes`:

- `id uuid`
- `restaurant_id uuid`
- `product_id uuid`
- `version integer`
- `status text`
- `effective_from timestamptz`
- `created_at timestamptz`
- `updated_at timestamptz`

Nueva tabla `product_recipe_lines`:

- `id uuid`
- `restaurant_id uuid`
- `recipe_id uuid`
- `component_product_id uuid`
- `quantity numeric(18, 6)`
- `unit_id uuid`
- `waste_percent numeric(8, 4) default 0`
- `display_order integer default 0`
- `is_active boolean default true`
- `created_at timestamptz`
- `updated_at timestamptz`

Reglas:

- Un producto final vendible puede tener receta activa si `uses_recipe = true`.
- Una preparacion puede tener receta activa si `uses_recipe = true`.
- Una materia prima no debe tener receta.
- Una receta puede consumir materias primas o preparaciones.
- No permitir ciclos: A consume B y B consume A.

### Reglas De Negocio

Agregar una regla configurable en la pantalla Admin **Reglas del negocio**:

- `allow_raw_material_negative_stock_from_recipes`
  - tipo: booleano.
  - valor inicial V1: `true`.
  - si esta en `true`, la explosion de receta descuenta completo y permite que
    materias primas queden en negativo.
  - si esta en `false`, Supabase no debe permitir que una explosion deje
    materias primas en negativo.
  - aplica solo a componentes `raw_material` consumidos por receta.
  - no aplica al stock propio del producto vendido, empaques ni otros
    inventarios operativos.

Motivo:

- En V1 ayuda a operar aunque las compras se registren tarde.
- Mas adelante permite endurecer inventario sin reestructurar recetas.
- Deja trazabilidad clara para supervisores mediante el reporte de inventario
  negativo.

### Movimientos De Inventario

Recomendacion fuerte: evolucionar cantidades a decimal normalizado.

Opcion segura por etapas:

1. Agregar columnas nuevas sin romper las actuales:
   - `inventory_stock.quantity_on_hand_decimal numeric(18, 6)`
   - `inventory_movements.quantity_delta_decimal numeric(18, 6)`
   - `inventory_movements.unit_id uuid null`
   - `inventory_movements.source_sale_item_id uuid null`
   - `inventory_movements.recipe_id uuid null`
   - `inventory_movements.recipe_line_id uuid null`
2. Poblar decimal desde entero actual.
3. Mantener entero como compatibilidad temporal.
4. Nuevas recetas usan decimal.
5. Reportes nuevos leen decimal.
6. En una fase futura se depreca entero.

No cambiar directamente entero a numeric en una sola migracion, porque hay codigo POS/local y RPCs existentes que asumen integer.

## Flujo Propuesto

### Compra De Materia Prima

1. Admin registra compra por lote.
2. Si compra pan en bolsas:
   - producto: Pan hamburguesa
   - cantidad: 3
   - unidad compra: bolsa
   - conversion: bolsa = 12 unidades
3. RPC convierte a unidad base/inventario.
4. Stock remoto aumenta en 36 unidades.
5. POS descarga stock en proxima sincronizacion.

### Venta POS

1. POS vende Hamburguesa.
2. POS guarda venta local y encola.
3. Supabase recibe `pos_sync_sale`.
4. Supabase inserta venta y detalle.
5. Supabase explota receta activa:
   - 1 pan
   - X gramos carne
   - X onzas salsa
6. Supabase descuenta materias primas con movimientos idempotentes.
7. Si no hay receta, conserva comportamiento actual para no romper produccion.

### Anulacion

1. POS anula venta.
2. Sync remoto detecta `sale_void`.
3. Supabase reintegra los movimientos generados por la explosion de esa venta.
4. Debe usar referencias/movement ids deterministas para no duplicar.

### Staff Consumption

Debe usar la misma explosion que venta normal, porque tambien consume inventario.

## Plan De Implementacion Por Etapas

### Etapa 0 - Auditoria Profunda Y Backups

Estado: implementacion base completada.

Objetivo:

- Confirmar estructura real remota y conteo de datos productivos.
- Listar productos con `is_raw_material`, `tracks_inventory`, stock y ventas recientes.
- Identificar productos compuestos candidatos.

Acciones:

- Consultar Supabase:
  - productos por tipo actual;
  - productos con stock;
  - movimientos de inventario por tipo;
  - ventas con items;
  - productos vendidos que controlan inventario.
- Documentar riesgos de datos.
- Confirmar estrategia de backup antes de migraciones.

Pruebas:

- No aplica cambios.
- Solo lectura.

### Etapa 1 - Base De Unidades Y Tipos De Producto

Estado: en progreso avanzado.

Objetivo:

- Crear soporte remoto para unidades, tipo de producto y unidad base por
  producto sin cambiar aun la logica de venta POS.

Cambios:

- Migracion Supabase:
  - `measurement_units`
  - columnas nuevas en `products`
  - constraints no destructivos
  - backfill desde `is_raw_material`
  - regla `allow_raw_material_negative_stock_from_recipes`
- Admin Productos:
  - mostrar tipo: producto final y materia prima en V1.
  - dejar `preparation` para la etapa de CRUD de recetas.
  - seleccionar unidad base/inventario.
  - seleccionar unidad usual de compra.
  - configurar factor de conversion compra => inventario.
  - impedir que un producto de inventario/receta quede sin unidad base.
  - V1 implementada: flag `uses_recipe` para productos vendibles.
  - V1 implementada: materias primas permiten precio 0 y muestran unidades de
    compra/base cuando el catalogo de unidades esta disponible.
- Catalog pull:
  - descargar nuevos campos localmente solo si el POS los necesita.
  - preparar filtrado para que POS solo reciba productos vendibles.
  - V1 implementada: pull local filtra materias primas y stock no descargado.

Pruebas:

- Crear/editar producto existente.
- Materia prima mantiene precio 0 permitido.
- POS sigue ocultando materias primas.
- Catalog pull POS no descarga materias primas como productos operativos.
- Sync catalogos no rompe productos actuales.

### Etapa 2 - Compras Con Conversion De Unidad

Estado: pendiente.

Objetivo:

- Permitir compras por unidad de compra y guardar stock en unidad base/inventario.

Cambios:

- RPC de compras por lote acepta `quantity`, `purchase_unit_id`.
- RPC convierte a cantidad base decimal usando la unidad base del producto y el
  factor de conversion configurado.
- UI inventario muestra unidad.
- Mantener compatibilidad con compras actuales sin unidad.
- V1 implementada: la RPC acepta `purchase_unit_id`; si viene configurado,
  multiplica la cantidad por `purchase_to_inventory_factor`, guarda stock en la
  unidad base entera actual y normaliza el costo unitario a costo base.
- V1 implementada: si no viene `purchase_unit_id`, conserva el comportamiento
  anterior para no romper compras existentes.

Pruebas:

- Compra 3 bolsas de 12 panes => stock 36 unidades.
- Compra 1 kg => stock 1000 gramos, si aplica.
- Compra con producto sin unidad base configurada debe rechazarse de forma clara.
- Compra existente sin unidad sigue funcionando con fallback.

### Etapa 3 - CRUD De Recetas En Admin

Estado: UI inicial completada.

Objetivo:

- Crear y editar recetas de productos finales/preparaciones.

Cambios:

- Tablas `product_recipes` y `product_recipe_lines`.
- RPCs admin:
  - crear/actualizar receta activa en transaccion.
  - validar componentes.
  - validar unidades compatibles.
  - prevenir ciclos.
- V1 implementada: migracion `050_product_recipes_foundation.sql` crea tablas,
  RLS, validacion de ciclos y RPC `app_save_product_recipe`.
- V1 implementada: servicio Dart remoto `SupabaseProductRecipesService` lee
  receta activa y guarda nueva version via RPC.
- Pantalla Admin:
  - acceso desde Productos o nueva opcion Recetas.
  - selector de producto final/preparacion.
  - lineas con materia prima/preparacion, cantidad y unidad.
- V1 implementada: accion `Receta` en la pantalla Productos para productos no
  materia prima.
- V1 implementada: dialogo movil/web para agregar, editar y guardar lineas de
  receta contra Supabase directo.

Pruebas:

- Crear receta Hamburguesa.
- Editar receta agregando ingrediente.
- Intentar ciclo y validar rechazo.
- Intentar usar producto final como componente y validar rechazo.

### Etapa 4 - Explosion Remota De Receta En Ventas

Estado: completado inicial.

Objetivo:

- Descontar materias primas al sincronizar ventas, sin duplicar ni romper ventas sin receta.

Cambios:

- Nueva funcion:
  - `pos_apply_recipe_inventory_movements(p_restaurant_id, p_sale_id, p_reference_type)`
- Integrar en:
  - `pos_sync_sale`
  - `pos_sync_staff_consumption`
- Movimientos generados:
  - `movement_type = 'recipe_consumption'`
  - `reference_type = sale` o `staff_consumption`
  - `reference_id = sale_id`
- Idempotencia:
  - movement id deterministico por `sale_id`, `sale_item_id` y
    `component_product_id`.
- Modo V1:
  - no bloquear sincronizacion por falta de materia prima;
  - consultar regla `allow_raw_material_negative_stock_from_recipes`;
  - si la regla esta activa, aplicar el descuento completo aunque el stock
    quede negativo;
  - si la regla esta inactiva, rechazar la sincronizacion antes de generar
    movimientos que dejarian materia prima negativa;
  - permitir inventario negativo solo si el componente descontado es
    `raw_material`;
  - si el producto vendido es `finished` y `uses_recipe = true`, se explota su
    receta y el negativo puede quedar solo en las materias primas resultantes;
  - no permitir esta facilidad para el stock propio del producto vendido ni para
    empaques;
  - registrar el stock negativo como resultado normal del movimiento, no como
    error de sincronizacion;
  - registrar alerta/auditoria cuando el stock base no cubra la receta;
  - permitir que la venta quede sincronizada para no frenar caja ni facturacion.
- Implementado en `051_recipe_inventory_explosion.sql`:
  - se elimina del payload remoto el movimiento de inventario del producto
    final cuando `uses_recipe = true`, evitando doble descuento;
  - despues de sincronizar venta o consumo de personal, Supabase explota la
    receta activa;
  - las recetas anidadas se recorren hasta 20 niveles y se agregan las materias
    primas finales;
  - las unidades de receta se convierten contra la unidad base de inventario;
  - las cantidades se redondean hacia arriba porque el stock actual sigue en
    enteros;
  - la regla `allow_raw_material_negative_stock_from_recipes` decide si una
    explosion puede dejar materia prima negativa.

Pruebas:

- Venta online/offline sincroniza y descuenta materias primas.
- Reintento no duplica movimientos.
- Venta sin receta no falla.
- Producto con receta anidada descuenta hojas finales.
- Venta con materia prima insuficiente sincroniza, descuenta y deja stock
  negativo auditable.
- Producto final vendible con `uses_recipe = true` dispara explosion, pero su
  stock propio no queda negativo por esta regla.
- Empaque con stock insuficiente no usa la regla de inventario negativo de
  recetas.
- Con `allow_raw_material_negative_stock_from_recipes = true`, la venta con
  materia prima insuficiente sincroniza y deja negativo.
- Con `allow_raw_material_negative_stock_from_recipes = false`, la misma venta
  debe ser rechazada por Supabase con error claro y reintentable.

### Etapa 5 - Anulaciones Y Reintegracion

Estado: completado inicial.

Objetivo:

- Reintegrar materias primas de recetas al anular.

Cambios:

- Funcion remota inversa:
  - `pos_reverse_recipe_inventory_movements`
- Integrar con anulacion remota.
- No reintegrar dos veces.
- Implementado en `052_recipe_inventory_void_reversal.sql`:
  - busca movimientos `recipe_consumption` de la venta;
  - crea movimientos positivos `sale_void` con id `recipe_void:<movimiento_original>`;
  - actualiza el stock de materias primas;
  - si la anulacion se reintenta, no duplica reintegros.

Pruebas:

- Venta con receta y anulacion reintegra materias primas.
- Reintento de anulacion es idempotente.

### Etapa 6 - POS Local Y Sync Catalogos

Estado: pendiente.

Objetivo:

- Mantener POS estable mientras remoto aplica receta.

Cambios recomendados:

- Fase inicial: POS no descuenta receta localmente.
- Catalog pull descarga stock remoto actualizado.
- Catalog pull de productos POS debe excluir `product_kind = raw_material`.
- Catalog pull de productos POS debe incluir solo productos vendibles/finales y
  activos.
- Evaluar si se desactiva `tracksInventory` de productos finales con receta para evitar doble descuento local.
- Si se requiere control offline estricto, agregar tablas locales de receta en fase posterior.

Pruebas:

- POS puede vender offline.
- Materias primas no aparecen ni se descargan como productos operativos del POS.
- Venta sincroniza aunque falte materia prima en V1.
- Si falta materia prima, el remoto descuenta completo, deja stock negativo y
  evidencia auditable para correccion.

### Etapa 7 - Costeo Y Reportes

Estado: pendiente.

Objetivo:

- Reportar costo real por receta y mejorar toma de decisiones.

Cambios:

- Calcular costo teorico de producto final desde receta activa.
- Guardar costo historico en `sale_items.unit_cost` al sincronizar, o crear campo adicional de costo explotado.
- Reportes:
  - productos rentables;
  - valor inventario;
  - inventario negativo por materia prima;
  - costo vendido;
  - margen real por receta.
- Reporte de inventario negativo:
  - listar materias primas con stock menor a cero;
  - mostrar cantidad negativa en unidad base;
  - mostrar ultima fecha de movimiento que genero o aumento el negativo;
  - mostrar productos/ventas relacionadas cuando venga de explosion de receta;
  - servir como alerta para que supervisores ingresen compras pendientes.

Pruebas:

- Cambiar costo materia prima afecta costo estimado futuro.
- Materia prima en negativo aparece en reporte y desaparece al ingresar compra
  suficiente.
- Ventas antiguas conservan costo historico.

### Etapa 8 - Documentacion Y Operacion

Estado: pendiente.

Objetivo:

- Dejar reglas operativas claras para equipo y futuros cambios.

Actualizar:

- `Documentation/BUSINESS_RULES.md`
- `Documentation/DATABASE.md`
- `Documentation/OFFLINE_SYNC.md`
- `Documentation/SCREENS_AND_FLOWS.md`

## Riesgos Criticos

### Riesgo 1: Doble Descuento

Si POS descuenta producto final localmente y Supabase descuenta receta, podria duplicarse inventario.

Mitigacion:

- Fase 4 debe definir una regla unica:
  - productos con receta se descuentan por receta en remoto;
  - productos sin receta conservan descuento actual.

### Riesgo 2: Cantidades Decimales

El sistema actual usa enteros para stock.

Mitigacion:

- Introducir columnas decimal paralelas.
- Migrar gradualmente.
- No borrar columnas existentes en V1.

### Riesgo 3: Recetas Anidadas Con Ciclos

Un ciclo puede crear recursion infinita.

Mitigacion:

- Validar ciclos al guardar receta.
- Limitar profundidad razonable en funcion de explosion.

### Riesgo 4: Ventas Antiguas

Ventas ya sincronizadas no deben recalcular inventario automaticamente.

Mitigacion:

- La explosion aplica solo al sincronizar ventas nuevas.
- Si se requiere recalcular ventas antiguas, debe ser una utilidad separada y manual.

### Riesgo 5: Inventario Negativo En Produccion

Al activar recetas, puede aparecer stock negativo cuando las compras no se
registran a tiempo. Operativamente eso es valido en V1: si el producto se vendio,
la materia prima existia de alguna forma, pero la compra o ajuste no se registro
todavia.

Mitigacion:

- V1 no bloquea venta ni sincronizacion por falta de materia prima.
- Permitir inventario negativo remoto solo si la regla de negocio
  `allow_raw_material_negative_stock_from_recipes` esta activa.
- Aun con la regla activa, permitir negativo solo para materias primas
  consumidas por receta.
- Permitir que productos vendibles con `uses_recipe = true` disparen explosion,
  dejando negativo solo en materias primas.
- Mantener fuera de esta regla el stock propio del producto vendido, empaques y
  otros inventarios operativos.
- Registrar movimientos negativos completos para conservar trazabilidad.
- Crear reporte operativo de inventario negativo para que supervisores ingresen
  compras o ajustes pendientes.
- Evaluar bloqueo estricto solo en una fase futura, despues de estabilizar
  stock real, recetas y unidades base.

## Decisiones Pendientes

1. Unidad base por tipo:
   - masa: gramos
   - volumen: ml u onzas
   - conteo: unidades
2. Confirmado: V1 de recetas no bloquea venta remota por falta de materia prima;
   descuenta completo y permite inventario negativo solo en materias primas
   resultantes de productos con `uses_recipe = true`, mientras la regla
   `allow_raw_material_negative_stock_from_recipes` este activa.
3. Si POS local debe validar stock de receta offline en una fase futura.
4. Si productos tipo `preparation` seran visibles en inventario y ocultos en POS.
5. Como manejar merma: porcentaje por linea o producto separado.
6. Confirmado: V1 debe incluir reporte de inventario negativo para supervision.

## Criterio De Listo Para Implementar

- Auditoria remota completada.
- Backup confirmado.
- Unidades base definidas.
- Conversion compra => unidad base definida por producto de inventario/receta.
- Catalog pull POS definido para sincronizar solo productos vendibles.
- Regla V1 no bloqueante documentada.
- Regla de negocio `allow_raw_material_negative_stock_from_recipes` definida en
  Admin Reglas del negocio.
- Regla V1 de inventario negativo exclusivo para materias primas de recetas
  documentada.
- Reporte de inventario negativo incluido en el alcance inicial.
- Estrategia de doble descuento definida.
- Plan de migraciones aprobado.
- Pruebas de integracion por etapa definidas.

## Bitacora De Avance

| Fecha | Etapa | Estado | Nota |
|---|---|---|---|
| 2026-07-15 | Auditoria inicial | Completado | Se mapeo productos, inventario, ventas, sync y reglas del proyecto. |
| 2026-07-16 | Etapa 1 base | En progreso | Migracion `048_recipe_foundation.sql` aplicada; Admin Productos guarda `uses_recipe`; POS pull filtra materias primas. |
| 2026-07-16 | Etapa 1 unidades | En progreso avanzado | Admin Productos lee unidades remotas, configura unidad de compra/base y factor para materias primas; sync remoto conserva esos campos. |
| 2026-07-16 | Etapa 2 compras | Base completada | Migracion `049_inventory_purchase_unit_conversion.sql` aplicada; compras por lote convierten unidad de compra a unidad base sin romper payload viejo. |
| 2026-07-16 | Etapa 3 recetas | Base remota completada | Migracion `050_product_recipes_foundation.sql` aplicada; tablas/RPC transaccional y servicio remoto Dart listos para UI. |
| 2026-07-16 | Etapa 3 recetas UI | Completado inicial | Pantalla Productos incluye accion Receta; dialogo permite cargar receta activa y guardar nueva version remota. |
| 2026-07-16 | Etapa 4 explosion remota | Completado inicial | Migracion `051_recipe_inventory_explosion.sql` aplicada; ventas y consumos explotan recetas en Supabase con movimientos idempotentes `recipe_consumption`. |
| 2026-07-16 | Etapa 5 anulaciones | Completado inicial | Migracion `052_recipe_inventory_void_reversal.sql` aplicada; anulaciones reintegran materias primas con movimientos idempotentes `sale_void`. |

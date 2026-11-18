# Revisión de arquitectura: identidad, tipo, función y existencias de artículos

**Fecha:** 2026-11-18
**Estado:** recomendación técnica para revisión del equipo; no autoriza cambios de código, datos, esquema ni producción.
**Documentos revisados:** auditoría original, propuesta Clase/Stock y referencia Business Central/LS Central.

## Decisión recomendada

Mantener **dos dimensiones editables, con nombres y responsabilidades inequívocos**, y una proyección técnica derivada:

1. **Tipo de artículo** (`item_type`): `inventory`, `non_inventory` o `service`. Es la autoridad de capacidades y seguimiento de inventario.
2. **Función operativa** (`item_class`): Producto de venta (`sale_product`), Materia prima (`raw_material`) o Empaque (`packaging`). Servicio deja de ser una opción editable aquí; durante compatibilidad, su valor de base `item_class=service` se deriva automáticamente de `item_type=service`.
3. **`tracks_inventory`**: proyección técnica no editable; debe ser exactamente `item_type = inventory`. Ninguna pantalla ni cliente puede establecerla por separado.

En la interfaz, usar las etiquetas **Tipo de artículo** y **Función operativa** (no los rótulos genéricos Tipo/Clase). Mostrar opciones inequívocas: Inventariable, No inventariable, Servicio; y Producto de venta, Materia prima, Empaque. Al escoger Servicio, completar internamente su clase compatible, fijar existencias/receta a No y deshabilitar esos controles. No mostrar Servicio una segunda vez.

Esta dirección conserva el contrato ya adoptado por la migración 124 y el significado de los consumidores actuales. **No se recomienda invertir ahora la autoridad** y hacer que `tracks_inventory` sea la fuente primaria, como plantea la propuesta, salvo que el equipo apruebe una migración deliberada de todos los escritores, lectores, POS y clientes offline.

## Por qué las dimensiones son distintas

- `item_type` responde: **¿qué tratamiento de inventario/costo permite este artículo?** BC define Inventory, Non-Inventory y Service; Inventory controla cantidad/valor, mientras Non-Inventory y Service no permiten mantener esas cantidades/valores. Los tres tipos permiten compra/venta según su matriz de funciones. [Microsoft: tipos de artículo](https://learn.microsoft.com/en-us/dynamics365/business-central/inventory-about-item-types).
- `item_class` responde: **¿qué papel operativo tiene en SmooControl?** La clase gobierna restricciones y flujos locales: producto de venta, componente/materia prima o empaque. No es equivalente a categoría comercial ni al tipo de inventario.
- LS Central agrega **Recipe Item Type** como dimensión aparte: Blank, Ingredient o Recipe; una receta es un artículo con BOM. Sus métodos también separan cuándo se desglosa o produce la receta. Esto respalda la separación de responsabilidades, pero **no** establece una equivalencia uno-a-uno con `item_class`, `uses_recipe` o las reglas de empaque de SmooControl. [LS Central: Recipe Item Type](https://help.lscentral.lsretail.com/Content/Fields/T_27_10001203.htm), [Recipes](https://help.lscentral.lsretail.com/Content/LS-Hospitality/Order-And-Sales-Management/Recipe/Recipe.htm), [BOM Methods](https://help.lscentral.lsretail.com/Content/LS-Hospitality/Order-And-Sales-Management/Recipe/Recipe-BOM-Methods.htm).
- Categoría (`category_id`) agrupa artículos; clasificaciones adicionales son etiquetas. Ninguna debe determinar por sí sola stock, venta, receta o consumo de empaque.
- `uses_recipe` y la relación de receta representan BOM/receta del producto. La clase Empaque más las reglas de consumo representan otra relación; no deben fusionarse con la receta sin una regla de negocio explícita.

BC/LS sirven como referencias de separación conceptual, no como especificación que SmooControl deba copiar íntegramente. Las capacidades y reglas comerciales propias de SmooControl siguen siendo las definidas por su producto.

## Coherencia con SmooControl actual

La recomendación se apoya en evidencia del repositorio y del Docker local:

- `CanonicalItemType` ya contiene Inventory, Non-Inventory y Service; `CanonicalItemClass` contiene sale_product, raw_material, packaging y service.
- La ficha permite escoger Servicio en ambos campos. Elegir Tipo=Servicio no completa actualmente `item_class=service`; elegir Clase=Servicio sí cambia Tipo. Esto deja una dirección de sincronización incompleta y permite combinaciones rechazadas después por el escritor SQL.
- La migración 124 modifica el escritor para guardar `tracks_inventory = (item_type = 'inventory')`. En el Docker local constan aplicadas 120, 121 y 124–127, y la definición activa del escritor contiene esa derivación.
- La restricción SQL actual solo impide `tracks_inventory=true` cuando `item_type` no es inventory; **permite** `item_type=inventory` junto con `tracks_inventory=false`. La migración 124 no reconcilia por sí sola los registros previos ni sustituye esa restricción por equivalencia estricta.
- En la instantánea local inspeccionada: 4 Productos tienen `item_type=inventory` y `tracks_inventory=false`; 1 Materia prima es `non_inventory/false`; los empaques incluyen 2 `inventory/true` y 6 `non_inventory/false`. El primer grupo requiere investigación por artículo; el segundo y los empaques no inventariables pueden ser intencionales. No convertirlos automáticamente.
- El artículo comercial 4, VASO 16ONZ QA, está como Empaque + No inventariable y no tiene saldo asociado. Por el contrato actual es correcto que Inventario lo excluya. La intención comercial del artículo debe confirmarla el propietario.
- Servicio es una identidad de clase interna exigida por contratos actuales; quitar ese valor físicamente requiere revisar constraints, `source_kind`, escritores, POS y sincronización. La propuesta debe distinguir eliminarlo del formulario de eliminarlo del esquema.

## Combinaciones funcionales recomendadas

| Tipo de artículo | Función operativa | Existencias | Ejemplo/efecto |
|---|---|---|---|
| Inventariable | Producto de venta | Sí | Producto terminado almacenado; la venta descuenta su saldo |
| No inventariable | Producto de venta | No | Platillo preparado al momento; si tiene receta, consume componentes según el contrato de venta |
| Inventariable | Materia prima | Sí | Ingrediente con saldo, compras, ajustes y consumo por receta |
| No inventariable | Materia prima | No | Componente usado/costeado sin saldo físico propio |
| Inventariable | Empaque | Sí | Vaso/bolsa con compras, ajustes, saldo y consumo por regla |
| No inventariable | Empaque | No | Servilleta u otro consumible sin saldo propio; no generar movimientos ficticios |
| Servicio | Derivada: Servicio | No | Prestación no física; receta y stock deshabilitados. La venta/visibilidad POS debe ajustarse al contrato comercial aprobado |

No se recomienda permitir Servicio + stock, ni exponer `tracks_inventory` como tercer campo editable. `can_sell`, `can_purchase`, visibilidad POS, receta, cocina y permisos son capacidades separadas, sujetas a las restricciones de negocio existentes; el tipo de artículo no debe inventar por sí solo permisos de venta.

## Contradicciones/ajustes necesarios en la propuesta recibida

1. **Fuente de verdad invertida:** propone `tracks_inventory` como autoridad y `item_type` derivado; esto contradice la migración 124 activa, los comentarios del esquema y usos de `item_type` en recetas/reglas. La recomendación es conservar `item_type` como autoridad y completar la proyección estricta de `tracks_inventory`.
2. **“Servicio no obligatorio” para stock:** reemplazar por **Servicio siempre sin existencias**. El tipo Service no es una variante física con stock opcional.
3. **Servicio en Clase:** retirarlo de las opciones editables, pero conservarlo temporalmente como valor derivado/compatibilidad; eliminarlo de BD solo en una fase posterior con auditoría de dependencias.
4. **Cuatro registros Producto/inventory/no-track:** son incoherentes con la derivación de la migración 124. Deben resolverse uno por uno con saldo, kardex, compras/ventas y decisión operativa antes de constraint/backfill.
5. **Venta/compra de servicios y empaques:** BC permite operaciones que no necesariamente coincide con el POS de SmooControl. No habilitar venta de Servicio ni compra de no inventariables sin verificar RPC, caja, costo, permisos y la experiencia acordada.
6. **Receta/producción:** los métodos LS muestran que producción anticipada y consumo al vender son procesos distintos. SmooControl no debe ofrecer producción ni descontar componentes dos veces sin contrato de producción aprobado.

## Plan medible para implementación posterior

| Fase | Trabajo | Criterio de salida |
|---|---|---|
| A — ratificar modelo | Confirmar autoridad `item_type`, nomenclatura, servicio y política de venta/compra | Decisión del propietario registrada; UX y SQL con misma matriz |
| B — reconciliar datos | Exportar anomalías locales por tenant; revisar balance, ledger, compras, ventas y colas | Cada fila `inventory/false` tiene disposición aprobada; sin corrección inferida |
| C — contrato SQL | Normalizar escritor y compatibilidad; garantizar `tracks_inventory = (item_type='inventory')`; luego añadir/validar constraint | Escribe el RPC canónico; pruebas de transacción, tenant, permisos, rollback e integridad |
| D — Backoffice | Etiquetas claras; una sola opción Servicio; derivación bidireccional en formularios; helper de stock | Widget tests de todas las combinaciones válidas e inválidas; sin campos duplicados |
| E — consumidores | Inventario, compras, ajustes, recetas, empaques, POS, venta/anulación y snapshots offline | Matriz E2E: item inventariable/no inventariable, empaque, ingrediente, servicio y reintento/sync |
| F — compatibilidad | Actualizar payload/versiones POS y clientes anteriores; definir retirada de `item_class=service` | Dispositivo antiguo no produce estado divergente; rollback/version gate comprobado |
| G — liberación | `dart format`, analyze, pruebas dirigidas/E2E locales, RELEASE contra Docker, QA visual | Evidencias reproducibles; sin tocar 088/producción; aprobación antes de migrar remoto |

### Pruebas de aceptación mínimas

- Cada artículo tiene exactamente un `item_type`; el servidor deriva `tracks_inventory` de forma idéntica en crear/editar/sync.
- Servicio no guarda stock ni receta y no puede quedar con clase de producto por selección unilateral.
- Empaque inventariable aparece en Inventario y sus compras/ajustes/ventas generan los movimientos definidos; empaque no inventariable no inventa saldo.
- Materia prima inventariable conserva la regla aprobada de negativos solo en el ámbito documentado; no extenderla a producto/empaque.
- Producto terminado inventariable, producto preparado con receta y anulaciones generan consumos/reversiones únicos, sin doble descuento.
- Aislamiento multitenant, autorización JWT/RLS, persistencia tras F5 y POS offline/sincronización comprobados.
- La clasificación/cambio de tipo con saldo o cola pendiente se bloquea o pasa por una operación auditable, nunca destruye historia.

## Límites y decisiones que siguen abiertas

- Confirmar con el equipo la semántica de los campos concretos de su instalación LS Central; el documento oficial público no describe sus extensiones ni parametrización de Casa del Café.
- Confirmar si el VASO 16ONZ código 4 debe controlar saldo.
- Decidir si una misma materia prima puede venderse directamente además de usarse como ingrediente. Si se requiere multirol, evaluar relaciones de roles después de cerrar los flujos actuales; no convertir el enum a multiselección sin caso de uso probado.
- Confirmar el flujo comercial de servicios en POS y si compra de artículo no inventariable debe registrarse como costo/gasto o solo línea comercial.

**No se modificaron artículos, migraciones, reglas de POS ni interfaces.** Esta revisión corrige la recomendación arquitectónica para que el equipo la apruebe antes de iniciar implementación.

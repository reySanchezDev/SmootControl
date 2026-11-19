# Referencia funcional: artículos en Business Central y LS Central

**Fecha de consulta:** 2026-11-18  
**Estado:** investigación documental, no propuesta aprobada ni especificación de implementación.  
**Documentos relacionados:** [Auditoría original](ARTICULOS-TIPO-CLASE-STOCK-2026-11-18.md) · [Propuesta SmooControl](PROPUESTA-ARTICULOS-CLASE-STOCK-SMOOCONTROL-2026-11-18.md).

## 1. Business Central: maestro y tipo de artículo

El maestro estándar es Item (tabla 27). La ficha Item Card contiene Type, unidad base, descripción, categoría y otros datos comerciales. El campo Type determina las operaciones de inventario admitidas [1][2][3].

| Type | Significado | Control de cantidad y valor de inventario |
|---|---|---|
| Inventory | Artículo sujeto a procesos completos de inventario | Sí |
| Non-Inventory | Bien que se comercializa o consume sin seguimiento completo de stock | No |
| Service | Unidad de prestación de servicios | No |

En el estándar documentado, no se necesita un segundo selector independiente que pueda contradecir Type para determinar el seguimiento de existencias. Inventory no equivale exclusivamente a materia física: puede representar bienes identificables no físicos cuando se requiere control. [1]

### Operaciones admitidas

| Operación | Inventory | Non-Inventory | Service |
|---|---|---|---|
| Venta y compra | Sí | Sí | Sí |
| Consumo en ensamblaje/producción | Sí | Sí | No |
| Salida de ensamblaje/producción | Sí | No | No |
| Transferencia, conteo físico y revalorización | Sí | No | No |
| Reserva y almacén | Sí | No | No |

Fuente: matriz oficial de capacidades por tipo [1]. La posibilidad de contabilizar consumo de un artículo Non-Inventory no significa que mantenga un saldo físico inventariable.

### Costos y movimientos

Microsoft distingue la contabilización inventariable en movimientos de artículo y movimientos de valor de los importes de costo no inventariable. Los tipos Non-Inventory y Service pueden tener costo unitario sin controlar cantidad o valor de stock. [1]

## 2. Clasificaciones de negocio

Business Central permite organizar artículos por Item Category Code y atributos. Categoría, atributos y variantes tienen finalidades diferentes de Type. [3][4]

Por ejemplo, bebidas, materias primas o empaques pueden ser categorías del catálogo; esto no demuestra que exista un enum base obligatorio Producto/Materia prima/Empaque/Servicio equivalente al de SmooControl. Tampoco se debe deducir que una categoría determine por sí misma el stock.

## 3. LS Central: ampliación gastronómica del maestro

LS Central añade el campo **Recipe Item Type** sobre Item. Sus valores documentados son [5]:

| Valor | Propósito |
|---|---|
| Blank | Sin función específica de receta |
| Ingredient | Elegible como ingrediente |
| Recipe | Artículo con información de receta y BOM asociada |

La ficha Hospitality Item Card expone Blank e Ingredient. La Recipe Card asigna el valor Recipe. La documentación distingue tres vistas del mismo concepto de artículo: catálogo Retail (todos), Hospitality (ingredientes) y Recipe (recetas). [5][6]

Las recetas incluyen ingredientes, otras recetas y componentes adicionales con cantidades. Se apoyan en Assembly BOM; tienen costos y precios como los demás artículos. [6][7]

**Distinción clave:** Type y Recipe Item Type responden preguntas distintas. El primero controla capacidades de inventario; el segundo representa participación en recetas. No existe una equivalencia exacta entre Recipe Item Type y las cuatro clases propuestas en SmooControl.

## 4. Cuándo se consumen los ingredientes

LS Central documenta cuatro BOM Methods [8]:

| Método | Momento |
|---|---|
| No exploding | No desglosa la receta |
| Explode at Entry | Desglose cuando se registra el artículo en POS |
| Explode at Posting | Desglose al contabilizar el statement; considera sales type |
| Produce | Producción mediante Day Plan |

Estas opciones permiten distinguir preparación vinculada a venta y producción anticipada. Explode at Posting puede agrupar los consumos antes de contabilizarlos si la configuración correspondiente está activada.

No debe concluirse que todas las instalaciones de LS descuentan inventario inmediatamente en caja; depende del método y del proceso de contabilización. Tampoco se confirma aquí que cualquier combinación de Type y Recipe Item Type esté permitida en todas las versiones.

LS documenta además componentes de BOM como ingredientes o artículos adicionales [9], y funciones de reposición orientadas a componentes consumidos [10]. Esto demuestra que la función del componente y su consumo pueden gestionarse por separado de la identidad del artículo vendido. No demuestra una clase nativa universal llamada Empaque ni reproduce automáticamente las reglas de SmooControl por pedido.

## 5. Ejemplos explicativos (no configuración real de una instalación)

- Una bebida embotellada que mantiene cantidades propias: Inventory; el rol de receta puede quedar sin asignar.
- Carne que se controla por peso y se incorpora a una receta: Inventory + Ingredient.
- Un consumible barato sin control de saldo: Non-Inventory; su uso como componente debe verificarse según el proceso.
- Un producto compuesto: Recipe + método BOM según preparación/producción; confirmar compatibilidad del Type con esa versión de LS y método.
- Un servicio de entrega: Service en el maestro BC; la comercialización concreta en POS de LS depende de configuración y capacidades de la instalación.

## 6. Diferencias con SmooControl

| Dimensión | Business Central / LS Central | SmooControl actual |
|---|---|---|
| Comportamiento de stock | Type en Item | item_type y tracks_inventory |
| Función gastronómica | Recipe Item Type, BOM | item_class, uses_recipe, relaciones de recetas |
| Agrupación | Item Category Code, atributos | category_id, item_classifications |
| Consumo | BOM Method y contabilización | RPC de venta/receta y reglas de empaque |
| Identidad | Maestro Item | items canónico por item_id |

El hallazgo aprovechable es separar identidad, comportamiento inventariable y función operativa, evitando autoridades de stock contradictorias. Esta tabla es un análisis comparativo, no equivalencia de campos uno a uno.

## 7. Límites de la investigación

La documentación pública describe el estándar de Business Central y LS Central. No se inspeccionó el entorno productivo de Casa del Café, sus extensiones AL, código personalizado ni parametrización del statement. No afirmar que sus campos de clase/familia, opciones específicas de empaques o comportamiento de producción correspondan a una funcionalidad base sin comprobarlos. Las capturas del propietario sirven como referencia de ficha y listado, no como evidencia de todas las reglas internas.

## Fuentes oficiales

1. Microsoft Learn, [About item types](https://learn.microsoft.com/en-us/dynamics365/business-central/inventory-about-item-types).
2. Microsoft Learn, [Create item cards for goods or services](https://learn.microsoft.com/en-gb/dynamics365/business-central/inventory-how-register-new-items).
3. Microsoft Learn, [Table Item](https://learn.microsoft.com/en-us/dynamics365/business-central/application/base-application/table/microsoft.inventory.item.item).
4. Microsoft Learn, [Categorize items](https://learn.microsoft.com/en-us/dynamics365/business-central/inventory-how-categorize-items).
5. LS Retail Help, [Recipe Item Type, Item](https://help.lscentral.lsretail.com/Content/Fields/T_27_10001203.htm).
6. LS Retail Help, [Recipes](https://help.lscentral.lsretail.com/Content/LS-Hospitality/Order-And-Sales-Management/Recipe/Recipe.htm).
7. LS Retail Help, [Recipe Ingredients](https://help.lscentral.lsretail.com/Content/LS-Hospitality/Order-And-Sales-Management/Recipe/Recipe-Ingredients.htm).
8. LS Retail Help, [Recipe BOM Methods](https://help.lscentral.lsretail.com/Content/LS-Hospitality/Order-And-Sales-Management/Recipe/Recipe-BOM-Methods.htm).
9. LS Retail Help, [BOM Component Type](https://help.lscentral.lsretail.com/Content/Fields/T_10001213_11.htm).
10. LS Retail Help, [Replenishment for BOM and Components](https://help.lscentral.lsretail.com/Content/LS-Retail/Replenishment/Automatic-Replenishment/Process/Replenishment-for-BOM-and-Components.htm).

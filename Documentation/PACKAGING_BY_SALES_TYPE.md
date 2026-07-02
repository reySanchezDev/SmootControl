# Empaques Por Tipo De Venta

## Regla De Negocio

El tipo de venta aplica a toda la orden del POS. Por defecto una orden inicia como `Comer aqui`. Si el usuario cambia la orden a `Para llevar`, el cobro valida y descuenta los empaques configurados para cada producto vendido.

Si una mesa primero consume en sitio y luego pide productos para llevar, esos productos deben cobrarse en una orden separada. En esta version el tipo de venta no se maneja por linea.

## Catalogos

- `sales_types`: define los tipos de venta activos, orden visual y cual es el valor por defecto.
- `packaging_items`: define empaques no vendibles, costo unitario historico y si controlan stock.
- `product_packaging_rules`: define cuanto empaque consume un producto segun el tipo de venta.

Ejemplo:

```text
Producto: POLLO
Tipo de venta: Para llevar
Empaque: Bandeja
Cantidad por unidad: 1
```

## POS

El selector de tipo de venta se muestra siempre en la banda del ticket donde estan `Ocultar/Mostrar productos`, tasa de cambio y total. La seleccion se guarda por orden abierta para no perderse al salir y volver al POS.

Al cobrar:

1. El POS suma las cantidades vendidas por producto.
2. Busca reglas activas para el tipo de venta seleccionado.
3. Calcula el consumo total por empaque.
4. Si falta stock de algun empaque que controla inventario, bloquea el cobro.
5. Si todo alcanza, guarda venta, detalle, movimientos de producto y movimientos de empaque en una sola transaccion local.

## Inventario

El stock de empaques vive separado del stock de productos:

- `packaging_stock`: existencia actual por empaque.
- `packaging_movements`: auditoria de compras, ventas y anulaciones de empaques.

La pantalla `Inventario` tiene pestañas para `Productos` y `Empaques`. Registrar compra en la pestaña de empaques alimenta `packaging_stock` mediante un movimiento `packaging_purchase`.

## Anulaciones

Una anulacion no borra movimientos anteriores. Crea movimientos inversos `packaging_sale_void` con base en los movimientos originales de la venta, para reintegrar exactamente lo que se consumio al cobrar.

## Sincronizacion

`Sincronizar datos` descarga tipos de venta, empaques, reglas y stock de empaques desde Supabase.

Las ventas offline suben sus movimientos de empaque junto con la venta. La aplicacion remota usa movimientos idempotentes por `packaging_movements.id`, de modo que un reintento de sincronizacion no descuenta dos veces.

## Supuestos De Esta Version

- El empaque no modifica el precio de venta.
- El empaque no es producto vendible.
- La falta de stock de empaque bloquea el cobro.
- Se trabaja con una sola tableta POS para inventario operativo.
- La evolucion a tipo de venta por linea queda fuera de esta version.

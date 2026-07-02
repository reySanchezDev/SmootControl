# Cierre De Piloto

Esta utilidad permite preparar el restaurante para produccion despues de haber
usado datos de capacitacion o pruebas.

## Regla De Negocio

El cierre de piloto elimina solo datos operativos:

- ventas y detalles de ventas;
- anulaciones;
- cajas abiertas o cerradas;
- gastos registrados;
- cuentas separadas y tickets abiertos del POS;
- cola/logs de sincronizacion;
- movimientos de inventario y empaque.

El cierre conserva datos maestros:

- usuarios, roles y permisos;
- categorias, productos, modificadores y mesas;
- metodos de pago;
- tipos de venta, empaques y reglas de empaque;
- tasas de cambio y configuracion base.

Al finalizar, el inventario de productos y empaques queda en `0`, y el
consecutivo de facturas vuelve al numero inicial configurado. Esto obliga a
cargar compras reales antes de iniciar produccion con productos que controlan
existencia.

## Seguridad

La accion requiere el permiso `sistema.reiniciar_operacion` y exige escribir
exactamente `REINICIAR PRODUCCION`.

La limpieza remota se ejecuta mediante la funcion Supabase
`reset_pilot_operation`, que valida restaurante, sesion administrativa y
permiso antes de borrar datos. Luego la app limpia su copia local para que el
POS quede alineado.

## Uso

Entrar como administrador remoto y abrir:

`Dashboard -> Utilidades -> Cierre de piloto`

Despues del cierre, sincronizar o reiniciar los dispositivos POS antes de
operar.

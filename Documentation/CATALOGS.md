# Catalogos - SmooControl

## Metodos De Pago

| Codigo | Grupo POS | Opcion POS | Moneda | Requiere referencia | Afecta efectivo |
| --- | --- | --- | --- | --- | --- |
| `cash_nio` | Efectivo | Cordoba | NIO | No | Si |
| `cash_usd` | Efectivo | Dolar | USD | No | Si |
| `card` | Tarjeta | Tarjeta |  | Configurable | No |
| `transfer` | Transferencia | Transferencia |  | Configurable | No |
| `other` | Otros | Otro |  | Configurable | No |

- El POS muestra primero los grupos de pago y luego las opciones de ese grupo.
- Ejemplo: tocar `Efectivo` muestra `Cordoba` y `Dolar`.
- Los metodos se pintan dinamicamente segun el catalogo activo.

## Categorias De Gastos

- Las categorias pueden vivir en raiz como grupos operativos.
- Ejemplos de grupos: gastos administrativos, gastos de combustible, mantenimiento.
- Dentro de cada grupo se crean las categorias registrables.
- Ejemplos registrables: papeleria, gasolina moto, reparacion de cocina.
- Categorias legacy sin padre siguen siendo registrables para no bloquear datos existentes.
- El mantenimiento elimina categorias de gasto; al eliminar un grupo, sus hijas pasan a raiz.

## Categorias De Productos

- El catalogo de productos permite multiples niveles mediante `parent_id`.
- Una categoria sin padre aparece en la raiz del POS.
- Una categoria con padre aparece dentro de la categoria seleccionada.
- Ejemplo: `CAFE CALIENTE > CAPUCCINO > 8 OZ`.
- Los productos se asignan a la categoria final donde deben venderse.
- La pantalla no solicita IDs ni orden manual; el sistema los gestiona.
- Producto activo significa que existe para mantenimiento e historico.
- Producto disponible en POS significa que se vende hoy y aparece al cajero/mesero.

## Opciones De Productos

- Los acompanamientos se modelan como grupos de opciones configurados en el producto.
- Ejemplo de grupo: `Acompañamiento`.
- Ejemplo de opciones: `Tajadas`, `Maduro frito`, `Tortilla`.
- En V1 cada grupo puede ser requerido u opcional y soporta una opcion por grupo sin cambiar precio.
- Los grupos nuevos quedan requeridos por defecto para evitar omisiones accidentales.
- La configuracion se captura en productos con un editor guiado de grupos y opciones.
- Ejemplo de grupo: `Base`; opciones: `Gallo pinto`, `Arroz blanco`.
- La seleccion queda visible en el carrito, cuentas separadas y PDF.
- La seleccion se guarda en la linea de venta para auditoria y cocina.
- Productos sin grupos de opciones se agregan directo al POS.
- Si un grupo opcional se omite, no se guarda una seleccion vacia en la linea de venta.

## Roles Iniciales

| ID interno | Nombre | Uso |
| --- | --- | --- |
| `role-admin` | Administrador | Acceso completo al sistema. |
| `role-cashier` | Cajero | Ventas, caja, PDF, anulaciones y cuentas separadas. |
| `role-waiter` | Mesero | Registro de ventas y separacion de cuentas. |

## Permisos Iniciales

| Codigo | Nombre |
| --- | --- |
| `usuarios.gestionar` | Gestionar usuarios |
| `roles.gestionar` | Gestionar roles |
| `mesas.gestionar` | Gestionar mesas |
| `productos.gestionar` | Gestionar productos |
| `ventas.registrar` | Registrar ventas |
| `caja.aperturar` | Aperturar caja |
| `caja.cerrar` | Cerrar caja |
| `gastos.categorias.gestionar` | Gestionar categorias de gastos |
| `gastos.registrar` | Registrar gastos operativos |
| `pdf.generar` | Generar PDF |
| `pagos.gestionar` | Gestionar pagos |
| `cuentas.separar` | Separar cuentas |
| `ventas.anular` | Anular ventas |
| `reportes.ver` | Ver reportes |
| `configuracion.gestionar` | Gestionar configuracion |
| `tasas.gestionar` | Gestionar tasas de cambio |
| `auditoria.ver` | Ver auditoria |
| `sync.configurar` | Configurar sync |

## Semilla De Acceso V1

- Si roles/permisos estan vacios, la app crea roles, permisos y asignaciones base localmente.
- El administrador recibe todos los permisos.
- Cajero y mesero reciben permisos operativos minimos.
- Esta semilla permite usar Usuarios aunque el usuario entre antes a Roles.

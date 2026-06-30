# Pantallas Y Flujos - SmooControl

## Pantallas V1

- Login local por correo y PIN.
- Dashboard operativo. Base creada.
- POS. Ruta base creada.
- Separar cuentas.
- Transacciones por fecha. Base creada en ventas con PDF basico.
- Mesas. Base creada.
- Categorias y productos. Base creada con alta y mantenimiento basico.
- Metodos de pago. Base creada con alta y mantenimiento basico.
- Mesas. Base creada con alta y mantenimiento basico.
- Caja diaria. Sin pantalla independiente en V1; apertura y cierre operativo se hacen desde POS.
- Gastos operativos. Base creada con alta de categorias y gastos.
- Anulaciones. Base creada desde ventas.
- Reportes.
- Tasas de cambio.
- Inventario.
- Settings.
- Sincronizacion local.

## POS

- Panel de detalle visible.
- Navegacion por categorias y subcategorias de multiples niveles.
- Productos directos por categoria.
- Seleccion por toque en movil.
- Grillas amplias en tablet/web.
- Estado implementado: POS responsivo con estilo terminal para tableta. Usa franjas dinamicas: ticket superior, productos/subcategorias del nivel seleccionado, categorias principales, mesas y barra inferior dividida en acciones importantes, mas opciones y metodos de pago.
- Regla tactil global: los mensajes de error, informacion o advertencia se muestran como modal con boton `OK`; no se usan mensajes inferiores tipo snackbar.
- Regla de UI tactil: el POS no usa listas desplegables para categorias, mesas ni metodos de pago; usa botones dinamicos que se redistribuyen segun la cantidad disponible.
- Regla de UI tactil: los botones de accion no pueden mostrar texto truncado; si no cabe, se reduce el texto o se adapta el layout.
- Regla de entrada tactil: cualquier campo de texto o monto usado dentro del POS abre un teclado modal reutilizable; no depende del teclado fisico del navegador/dispositivo.
- Regla de seguridad tactil: acciones destructivas como limpiar pedido, quitar productos o quitar una cuenta separada siempre piden confirmacion antes de cambiar el pedido.
- Regla de formularios: ningun campo debe traer texto de ejemplo como valor editable que el usuario tenga que borrar; se usa placeholder/hint.
- Regla de pago jerarquico: la seccion de metodos de pago funciona como arbol tactil. Puede navegar `Efectivo > Cordoba`, `Transferencias > BANPRO > Cuenta 7888889` o cualquier profundidad configurada.
- Regla de mesas: tocar una mesa cambia el contexto del ticket y marca visualmente la mesa seleccionada. Cada mesa conserva su cuenta independiente mientras el POS esta abierto; una mesa con pedido muestra etiqueta `Ocupada`, no conteo de items.
- Regla visual de mesas: la fila de mesas tiene scroll horizontal; muestra primero mesas ocupadas segun el orden en que se ocuparon y luego mesas libres ordenadas de menor a mayor.
- Regla visual: debajo del detalle de lineas se muestra una franja compacta de total; no debe ocupar alto excesivo porque el POS esta optimizado para tableta.
- Regla visual: la franja del total incluye un boton compacto de accion para `Ocultar` o `Mostrar` productos; usa color de la paleta y no debe verse como etiqueta pasiva ni ocupar ancho excesivo.
- Regla visual: la franja del total muestra siempre la tasa de cambio cerca del total de `Monto`, en el carril monetario previo, para que el cajero la vea antes de cobrar en moneda extranjera.
- Regla visual: el detalle de lineas muestra `Servido` como estado operativo persistido. Si un producto servido se vuelve a pedir, aparece como una nueva fila pendiente; al cobrar o imprimir, las filas iguales se consolidan comercialmente.
- Regla visual: en raiz se muestran categorias principales; al entrar a una categoria se muestran sus categorias hijas y tambien los productos directos de esa categoria.
- Regla visual: si productos esta oculto y el usuario navega categorias o subcategorias, la seccion de productos se muestra automaticamente.
- Regla visual: las categorias activas se muestran aunque esten vacias; la disponibilidad diaria solo oculta productos, no familias de menu.
- Regla de mesa: el usuario debe seleccionar una mesa antes de agregar productos; si no hay mesa seleccionada, los productos no se agregan al ticket. La venta y lineas guardan `table_id`.
- Regla de barra inferior: la seccion central muestra `Mas opciones`; ahi se agregaran acciones futuras sin saturar la pantalla principal.
- Regla de pago: no existe boton separado de `Cobrar`; el cobro inicia al tocar una opcion final de metodo de pago valida.
- Regla de pago: la referencia de pago se solicita en un modal tactil solo si la opcion seleccionada la requiere.
- Regla de efectivo: si el metodo afecta caja, el POS abre un modal numerico tactil con el total precargado y seleccionado; al confirmar con `OK`, valida recibido, calcula cambio y completa la venta.
- Regla de moneda extranjera: si el metodo de pago usa moneda diferente a `NIO`, el POS exige tasa de cambio del dia, pide el recibido en esa moneda, convierte a moneda local y muestra el vuelto en moneda local.
- Regla de inventario: al cobrar, el POS valida productos que controlan inventario, bloquea si falta stock y descuenta localmente en la misma transaccion de venta. Productos sin inventario no cambian su flujo.
- Regla de pago: al cambiar hacia un metodo que no requiere referencia o al completar una venta, cualquier referencia escrita se limpia para evitar datos arrastrados.
- Regla de caja: el POS requiere caja abierta del usuario actual antes de operar; si no existe, muestra apertura de caja y no permite agregar/cobrar productos. Si existe una caja abierta de un dia anterior, muestra cierre obligatorio de esa caja y no permite abrir la caja de hoy hasta cerrarla.
- Regla de transacciones: `Mas opciones` incluye `Ver Transacciones`; abre una pantalla con las ventas cobradas en la caja abierta del usuario actual, sin mezclar otras cajas ni otros cajeros.
- Regla de gastos: `Mas opciones` incluye `Registrar Gasto`; abre una pantalla tactil responsiva con grupos de categorias y categorias registrables, usa teclados tactiles para monto/descripcion y guarda el gasto en la caja abierta del usuario.
- Regla de cierre: `Mas opciones` incluye `Cerrar caja`; al tocarlo valida de inmediato si hay mesas con productos pendientes. Si todo esta libre, solicita solo conteo fisico a ciegas y no muestra efectivo esperado al cajero.
- Regla de salida: `Mas opciones` incluye `Salir`; permite salir aunque existan mesas con productos pendientes porque los pedidos abiertos se restauran al volver al POS. Si el usuario es Cajero o Mesero, salir cierra sesion y vuelve al login; si es Administrador, vuelve al panel operativo.
- Regla de opciones: si el producto tiene grupos configurados, el POS solicita una opcion por grupo antes de agregarlo al carrito.
- Control basico de mesa: inactivar una mesa la deshabilita; reactivarla la deja disponible.
- Regla de nombre de mesa: cada mesa conserva un nombre interno para reportes y puede tener un nombre operativo temporal para el mesero/cajero. Al cobrarse o liberarse, el nombre operativo se limpia y vuelve a mostrarse el nombre interno.

## Separar Cuentas

- Boton `Separar cuentas`.
- Abrir una pantalla completa optimizada para tablet.
- Mostrar un panel fijo con la orden original de la mesa seleccionada.
- Crear automaticamente `Cuenta 1` y `Cuenta 2`.
- Permitir renombrar cada cuenta generada.
- Permitir agregar mas cuentas con `+`.
- Permitir eliminar cuentas generadas desde la pantalla de division; si la cuenta aun no fue confirmada, sus productos regresan a la orden original.
- Web/tablet: arrastrar productos desde la orden original hacia una cuenta.
- Movil/tablet tactil: tocar producto y luego tocar la cuenta destino.
- No confirmar si quedan productos sin asignar.
- Cada cuenta muestra su total dinamico.
- Mesa queda como contenedor de la division y conserva referencia a todas las cuentas.
- Estado implementado: pantalla completa desde POS con panel original fijo, cuentas horizontales, nombres editables, asignacion por toque y drag & drop, devolucion de items a la original y totales por cuenta.
- Validacion implementada: requiere mesa seleccionada, al menos dos cuentas y todos los productos asignados una sola vez.
- Opciones implementadas: los productos asignados conservan la opcion seleccionada para diferenciar variantes del mismo producto.
- Estado implementado: al confirmar la division, las cuentas hijas aparecen junto a la mesa original en la fila de mesas con sus nombres operativos.
- Pendiente controlado: seleccionar una cuenta hija debe cargar su cuenta y permitir cobrarla individualmente sin cobrar toda la mesa original.
- Pendiente controlado: mientras exista una cuenta hija abierta o no pagada, la mesa original debe mantenerse ocupada.
- Pendiente controlado: una cuenta hija confirmada no se elimina desde afuera; solo desde `Editar division`, y nunca si ya fue pagada.
- Pendiente controlado: si una cuenta hija abierta pide mas productos, se le pueden agregar; si ya fue pagada, se crea una orden nueva en una mesa o cliente virtual.
- Pendiente controlado: las mesas o clientes virtuales se crean para pedidos temporales y se destruyen automaticamente al ser cobrados.

## Caja Diaria Desde POS

- Apertura operativa desde POS con efectivo inicial.
- No permite abrir una segunda caja para el mismo cajero y dia.
- Permite cajas separadas para cajeros distintos en el mismo dia.
- Ventas asociadas a caja abierta.
- Gastos desde caja reducen efectivo esperado.
- Cierre operativo desde POS, en `Mas opciones`, con conteo fisico a ciegas.
- Estado implementado: POS requiere caja abierta del usuario para ingresar; gastos consultan la caja abierta del dia y guardan la relacion interna sin solicitar IDs al usuario. No existe opcion independiente `Caja diaria` en el dashboard.
- Resumen implementado: efectivo inicial, ventas en efectivo, gastos desde caja, efectivo esperado, conteo fisico y diferencia.
- Aperturar caja registra auditoria local `cash.open`.
- Cerrar caja registra auditoria local `cash.close`.

## Gastos Operativos

- Categorias de gastos visibles y mantenibles.
- Categorias de gastos agrupables por una categoria padre.
- Categorias de gastos se eliminan desde el mantenimiento; si un grupo eliminado tiene hijas, esas hijas pasan a raiz.
- La pantalla de gastos queda para mantenimiento del catalogo de gastos; no lista gastos registrados hoy.
- Registro operativo de gasto se realiza desde POS en `Mas opciones > Registrar Gasto`.
- Regla visual: no se exponen IDs de categoria, caja ni usuario.

## Reportes

- Periodos implementados: dia, semana, mes y año con selector de fecha base.
- Rango personalizado implementado: permite seleccionar fecha inicial y final libre.
- Rango calculado visible para el periodo seleccionado.
- Ventas brutas.
- Ganancia bruta estimada desde historico de precio y costo de cada venta.
- Gastos operativos del periodo.
- Detalle de gastos del periodo con filtro por categoria.
- Ganancia real: ganancia bruta menos gastos operativos.
- Ticket promedio.
- Cantidad de ventas completadas.
- Cantidad y detalle de anulaciones por fecha de anulacion.
- Caja del periodo: cajas registradas, efectivo inicial, ventas en efectivo, gastos desde caja, efectivo esperado, conteo fisico y diferencia.
- Productos mas vendidos.
- Productos menos vendidos dentro de los productos con ventas del periodo.
- PDF/exportacion implementado: permite compartir un reporte basico con rango, metricas, caja, productos y anulaciones.

## Transacciones Por Fecha

- Lista ventas completadas o anuladas de la fecha seleccionada.
- Permite cambiar la fecha desde la pantalla sin exponer filtros tecnicos.
- Muestra numero de comprobante, estado y total.
- Permite abrir vista previa del comprobante PDF por venta, con acciones de imprimir o compartir desde el visor.
- Permite anular ventas completadas con motivo obligatorio.
- El PDF usa datos de empresa desde settings si estan habilitados.
- Estado implementado: selector de fecha, vista previa integrada de comprobante no fiscal con detalle de productos y opciones seleccionadas, metodo de pago, referencia opcional, subtotal y total; anulacion auditable local.

## Reporte De Gastos

- Vive dentro de `Reportes`.
- Usa los filtros de periodo: dia, semana, mes, año y rango personalizado.
- Muestra gastos del periodo con fecha/hora, categoria, descripcion y monto.
- Permite filtrar por categoria.
- No se muestra dentro del mantenimiento `Gastos`.

## Transacciones De Caja Desde POS

- Se abre desde `Mas opciones > Ver Transacciones`.
- Lista ventas completadas asociadas a la caja abierta del usuario actual.
- Muestra comprobante, hora, metodo de pago y total.
- Muestra total cobrado de la caja abierta segun las ventas listadas.
- No muestra ventas de otras cajas, otros cajeros ni historico por fecha; para eso existe `Transacciones Por Fecha`.

## Tasas De Cambio

- Catalogo administrativo para gestionar tasas del mes visible.
- Permite navegar entre meses.
- Muestra todos los dias del mes y permite guardar la tasa de cada dia.
- Permite escribir una tasa unica y aplicarla a todos los dias del mes.
- El permiso requerido es `tasas.gestionar`.
- El POS usa la tasa del dia actual cuando el metodo de pago cobrable tiene moneda extranjera como `USD`.
- Si falta la tasa del dia, el POS bloquea el cobro extranjero y pide configurar la tasa antes de continuar.

## Inventario

- Catalogo administrativo para productos que controlan inventario.
- El permiso requerido es `inventario.gestionar`.
- Productos permite activar o desactivar `Controla inventario`; el stock no se edita en productos.
- Inventario lista productos con control activo, stock actual y ultima actualizacion.
- `Registrar compra` permite seleccionar producto, cantidad entera y nota opcional.
- Registrar compra crea movimiento `purchase` y actualiza `inventory_stock`.
- El POS crea movimientos `sale` al cobrar y `sale_void` al anular ventas.
- La sincronizacion remota usa movimientos idempotentes para evitar doble descuento en reintentos.

## Anulaciones

- Se ejecutan desde transacciones del dia.
- Requieren motivo obligatorio.
- No eliminan la venta; cambian estado a anulada y registran auditoria local.
- Tambien escriben entrada en bitacora local; la pantalla muestra etiquetas de negocio, no claves internas.
- Las ventas anuladas quedan fuera de calculos de reportes de ventas y ganancias.
- Reportes muestra conteo y detalle de anulaciones segun el periodo seleccionado.
- Auditoria muestra fecha, accion traducida y detalles relevantes sin exponer IDs internos.
- Pendiente: usuario autenticado real.

## Settings

- Datos basicos del negocio: nombre comercial, razon social, RUC, telefono y direccion.
- Control de visibilidad de datos de empresa en PDF.
- Numeracion basica de facturas: prefijo y numero inicial.
- Estado implementado: pantalla conectada a persistencia local Drift.
- Regla visual: no expone IDs ni claves tecnicas; la numeracion se configura como dato de negocio.
- El sistema incrementa automaticamente el siguiente numero al cobrar.
- Guardar configuracion registra auditoria local `settings.save`.

## Roles Y Usuarios

- Login implementado: si no existe ningun usuario activo con PIN, la pantalla inicial permite crear el primer administrador local.
- El acceso local usa correo y PIN. El PIN se guarda como hash con salt, no como texto plano.
- Al iniciar sesion, un usuario marcado como `Usuario POS` entra directo al POS; los demas entran al panel operativo filtrado por permisos.
- El dashboard solo muestra modulos permitidos para el rol del usuario.
- Las rutas tambien validan permisos; escribir una URL manual a un modulo no permitido muestra `Acceso restringido`.
- Roles permite crear/editar nombre, descripcion, estado y permisos asignados.
- La pantalla de roles no expone IDs internos; los permisos se seleccionan por nombre.
- El catalogo local de roles/permisos V1 se siembra automaticamente si esta vacio.
- Al guardar un rol se registra auditoria local `roles.save`.
- Usuarios permite crear/editar nombre visible, correo, PIN, rol, marca `Usuario POS` y estado.
- La pantalla de usuarios no solicita IDs; el sistema los genera y luego se podran mapear a Supabase Auth.
- El rol del usuario se selecciona por lista desplegable de roles activos.
- Si se selecciona rol Cajero o Mesero, la marca `Usuario POS` se activa automaticamente como sugerencia operativa.
- En edicion, dejar el PIN vacio conserva el PIN actual; escribir uno nuevo lo reemplaza.
- Al guardar un usuario se registra auditoria local `users.save`.

## Auditoria

- Permite seleccionar una fecha y listar acciones auditadas localmente.
- Muestra accion, hora y detalles funcionales de la accion.
- No permite editar la bitacora.
- Estado implementado: vista por dia conectada a `local_audit_logs`.

## Sincronizacion

- Permite ver operaciones locales pendientes o con error.
- Permite ejecutar sincronizacion manual desde un boton.
- Muestra resumen del ultimo intento: procesadas, correctas y fallidas.
- Mientras Supabase SmooControl no este configurado, el envio remoto falla de forma explicita y los items quedan en error para reintento.
- Estado implementado: ruta `#/sync`, BLoC local y acceso desde dashboard.

## Mantenimiento De Catalogos

- Categorias y subcategorias multinivel permiten crear, editar, reubicar e inactivar.
- La pantalla de categorias muestra las raices como grupos contraibles; al entrar todas inician contraidas y solo una raiz puede estar abierta a la vez.
- Subcategorias y niveles internos permiten quitar un nivel creado por error, previa confirmacion; la categoria raiz no se puede quitar desde esta accion.
- Al quitar un nivel, sus productos y subniveles directos se mueven al nivel padre para que el POS muestre productos sin la carpeta innecesaria.
- Productos permiten crear, editar precio, costo, categoria e inactivar con confirmacion.
- Productos permiten marcar disponibilidad en POS para operacion diaria.
- Productos permiten marcar si controlan inventario; el stock se gestiona desde `Inventario`.
- Productos permiten asignar grupos modificadores reutilizables para el POS.
- Modificadores POS permite crear grupos como `Bastimento` o `Guarnicion`, marcar si son requeridos y administrar sus opciones disponibles.
- Las opciones modificadoras se pueden marcar disponibles/no disponibles para ocultarlas del POS sin perder historico.
- Modificadores POS muestra las opciones dentro de su grupo; el boton `+` del grupo agrega opciones hijas y el icono de inactivar oculta grupos/opciones previa confirmacion.
- Metodos de pago permiten crear grupos de navegacion y opciones cobrables dentro de cualquier grupo; la ubicacion se selecciona por lista y no se escribe como texto libre.
- Metodos de pago permiten quitar niveles internos creados por error, previa confirmacion; el metodo raiz no se puede quitar desde esta accion.
- Al quitar un nivel de pago, sus bancos, cuentas u opciones directas se mueven al nivel padre para que el POS no muestre pasos innecesarios.
- Metodos de pago permiten inactivar cualquier grupo u opcion cobrable previa confirmacion; quitar nivel queda solo para corregir jerarquias mal creadas.
- Solo las opciones cobrables permiten configurar moneda, referencia requerida, afectacion de caja e inactivacion operativa.
- Mesas permiten crear, editar nombre e inactivar conservando estado operativo.
- Categorias de gastos permiten crear, editar y eliminar previa confirmacion.
- Roles y usuarios permiten crear, editar e inactivar previa confirmacion.
- Categorias de gastos permiten ubicarse en raiz como grupo o dentro de otro grupo activo.
- Guardar categorias/subcategorias registra auditoria local `catalog.category.save`.
- Guardar productos registra auditoria local `products.save`.
- Guardar metodos de pago registra auditoria local `payment_methods.save`.
- Guardar mesas registra auditoria local `tables.save`.
- Guardar categorias de gastos registra auditoria local `expenses.category.save`.
- Guardar gastos operativos registra auditoria local `expenses.save`.
- Regla visual: no se solicitan IDs, ordenes tecnicos ni claves internas.
- Regla visual: el campo de ubicacion permite dejar una categoria en raiz o moverla dentro de cualquier categoria activa permitida.
- Regla de datos: no se elimina fisicamente en V1; se usa estado activo/inactivo para conservar historico.

## Modificadores POS Para Platos

- Algunos productos pueden requerir uno o varios grupos modificadores antes de agregarse al carrito.
- Ejemplo: plato de comida con grupo `Bastimento` y opciones `Tortilla`, `Tajadas` o `Maduro frito`.
- Regla visual: el mesero debe seleccionar la opcion desde botones/lista, no escribir texto libre.
- Estado implementado: los grupos se administran una vez en `Modificadores POS`; el producto solo selecciona que grupos aplican; el POS abre un selector por grupo con botones grandes, avanza automaticamente al siguiente grupo y guarda la seleccion en el carrito, cuentas separadas y detalle de venta.
- Si un grupo opcional se omite, el POS continua sin registrar una opcion vacia.
- Las opciones activas pero no disponibles se ocultan del POS para cubrir agotados o cambios del buffet durante el dia.
- Compatibilidad V1: los productos sin modificadores reutilizables conservan lectura de grupos legacy embebidos; cuando un producto ya tiene modificadores reutilizables, el POS usa solo esos para evitar duplicados.

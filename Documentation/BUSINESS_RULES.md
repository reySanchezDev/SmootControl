# Reglas De Negocio - SmooControl

## Experiencia Tactil

### Regla: Mensajes operativos modales
- Description: Todo mensaje de error, informacion o advertencia debe mostrarse como modal tactil con un unico boton `OK`.
- Rationale: La app se opera principalmente en pantalla tactil; los mensajes inferiores son faciles de perder y no obligan al cajero a reconocer la validacion.
- Example(s): Si el cajero intenta cerrar caja con mesas abiertas, el POS muestra un modal con `OK` y no un mensaje inferior.
- Edge cases: Confirmaciones destructivas pueden conservar botones de confirmar/cancelar; esta regla aplica a mensajes informativos, errores y advertencias sin decision.
- Data impact: Sin impacto de datos; regla de presentacion.

### Regla: Entradas tactiles en POS
- Description: Todo campo del POS o de flujos operativos invocados desde POS que requiera texto o cantidad debe abrir un teclado tactil global de texto o numerico.
- Rationale: El POS se usa en tablet o pantalla tactil sin teclado fisico; escribir en campos nativos hace lento e inconsistente el flujo.
- Example(s): Monto recibido, referencia de transferencia, apertura/cierre de caja y nombre de cuenta separada abren teclado tactil reutilizable.
- Edge cases: Los campos quedan en solo lectura y se llenan desde el teclado modal; cancelar el teclado no cambia el valor actual.
- Data impact: Sin impacto de datos; regla de presentacion.

### Regla: Confirmacion de acciones destructivas
- Description: Toda accion tactil que quite productos, limpie pedidos o descarte cuentas generadas debe pedir confirmacion antes de ejecutarse.
- Rationale: En pantalla tactil un roce accidental puede borrar trabajo operativo si la accion se ejecuta con un solo toque.
- Example(s): `Limpiar`, quitar una linea del ticket o quitar una cuenta hija en separacion muestran un modal con cancelar y confirmar.
- Edge cases: La confirmacion debe aparecer antes de modificar estado; cancelar conserva el pedido intacto.
- Data impact: Sin impacto directo; evita eliminar borradores locales por error.

## POS / Ventas

### Regla: Operador autenticado local
- Description: Ningun flujo operativo debe iniciar sin un usuario local autenticado por correo y PIN. Si no existe ningun usuario activo con PIN, la pantalla inicial obliga a crear el primer administrador. Un usuario marcado como `Usuario POS` entra directo al flujo operativo del POS.
- Rationale: Caja, ventas, gastos y auditoria necesitan un responsable real; `usuario-local` queda solo como respaldo tecnico para pruebas o registros legacy.
- Example(s): Al abrir SmooControl, el administrador inicial crea su usuario con PIN. Luego un cajero marcado como `Usuario POS` inicia sesion y entra directo al POS; su apertura de caja queda asociada a ese usuario.
- Edge cases: Los PIN se guardan como hash con salt, no en texto plano. Usuarios sin PIN no pueden iniciar sesion hasta que un administrador les configure uno. La marca `Usuario POS` define el flujo inicial, pero los permisos del rol siguen definiendo que puede abrir o modificar.
- Data impact: `local_user_profiles.pin_salt`, `local_user_profiles.pin_hash`, `local_user_profiles.is_pos_user`, `CurrentOperatorService`.

### Regla: Venta con metodo de pago
- Description: Toda venta completada debe tener un metodo de pago activo.
- Rationale: Permite reportes y cierre de caja confiables.
- Example(s): Una venta en efectivo incrementa efectivo esperado; una transferencia no lo incrementa.
- Edge cases: Si el metodo requiere referencia, el POS la solicita en un modal antes de completar; si se cambia a un metodo sin referencia o se completa la venta, la referencia escrita se limpia.
- Data impact: `sales.payment_method_id`, `sales.payment_reference`.

### Regla: Cobro POS basico
- Description: El POS solo permite completar una venta si el carrito tiene productos y existe metodo de pago seleccionado.
- Rationale: Evita ventas vacias y transacciones sin clasificacion de pago.
- Example(s): Cajero agrega espresso, selecciona efectivo y cobra; el carrito queda limpio y la venta queda guardada localmente.
- Edge cases: Si el carrito esta vacio o falta referencia requerida, se muestra error y no se crea venta; si la cola de sync falla, la venta local no se revierte en V1.
- Data impact: `sales`, `sale_items`, `local_sync_queue`.

### Regla: Sincronizacion no bloquea ventas
- Description: El POS debe completar la venta local aunque no haya internet o Supabase no responda. La sincronizacion corre despues mediante cola local reintentable.
- Rationale: SmooControl es offline first; la operacion de vender no puede detenerse por problemas de red, Supabase lento o cortes temporales.
- Example(s): El cajero cobra una mesa sin internet. La venta queda guardada localmente, la mesa se libera, la transaccion aparece en la caja actual y la cola queda pendiente/error hasta que sincronice.
- Edge cases: No se hace pre-check de conexion en V1; el intento remoto real, con timeout, determina si se marca como sincronizado o como error reintentable. Si la app se cierra con un item en `syncing`, el item viejo vuelve a ser elegible para reintento. Si el error remoto es permanente por datos invalidos, se seguira reintentando hasta corregir la causa desde sincronizacion.
- Data impact: `sales`, `sale_items`, `local_pos_open_ticket_lines`, `local_sync_queue`.

### Regla: Cambio en pagos en efectivo
- Description: Cuando el metodo de pago afecta caja, el POS debe abrir un teclado tactil con el total precargado, pedir el efectivo recibido, calcular el cambio y bloquear el cobro si el recibido es menor al total.
- Rationale: El cajero necesita cerrar el pago con rapidez y reducir errores al devolver cambio.
- Example(s): Total C$ 80.00, cliente entrega C$ 100.00, el POS muestra cambio C$ 20.00.
- Edge cases: Metodos que no afectan caja no muestran recibido ni cambio; si el cajero cancela el teclado, no se registra venta; si confirma un monto insuficiente, la venta queda pendiente.
- Data impact: `payment_methods.affects_cash_register`, calculo UI de POS.

### Regla: Cobro POS en moneda extranjera
- Description: Si el metodo de pago cobrable usa una moneda diferente a `NIO` y afecta caja, el POS debe buscar la tasa de cambio del dia, pedir el monto recibido en esa moneda, convertirlo a moneda local y calcular el vuelto en moneda local.
- Rationale: La venta y el cierre de caja siguen expresados en moneda local, pero el cajero puede recibir efectivo extranjero sin hacer conversiones manuales.
- Example(s): Total C$ 500.00, cliente entrega USD 20.00 y la tasa del dia es 36.60; el POS calcula C$ 732.00 recibido equivalente y muestra C$ 232.00 de vuelto.
- Edge cases: Si no existe tasa para la moneda y fecha actual, el POS bloquea el cobro y muestra un modal informativo. La tasa se usa solo para convertir el recibido y el vuelto; el comprobante y la venta historica permanecen en moneda local.
- Data impact: `payment_methods.currency_code`, `local_exchange_rates`, calculo UI de POS.

### Regla: Tasa de cambio visible en POS
- Description: La franja del total del POS debe mostrar siempre la tasa de cambio del dia para moneda extranjera operativa, ubicada cerca del total de `Monto`.
- Rationale: El cajero necesita ver la tasa antes de iniciar un cobro extranjero para evitar dudas o conversiones manuales.
- Example(s): Junto al total se muestra `Tasa: 36.60`; si no existe registro se muestra `Tasa: No configurada`.
- Edge cases: El indicador es informativo; el bloqueo real del cobro extranjero sigue ocurriendo al intentar cobrar si la tasa falta.
- Data impact: Lectura de `local_exchange_rates`; no modifica ventas ni caja.

### Regla: Metodos de pago jerarquicos en POS
- Description: El POS muestra metodos de pago como arbol tactil: grupos de navegacion y opciones finales cobrables.
- Rationale: Permite flujos reales como transferencia por banco y cuenta sin saturar la pantalla ni usar listas desplegables.
- Example(s): Cajero toca `Transferencias`, luego `BANPRO`, luego `Cuenta 7888889`; si requiere referencia, el sistema la solicita antes de completar.
- Edge cases: Los grupos de navegacion no cobran; solo las opciones finales ejecutan cobro. Metodos inactivos no aparecen. Datos antiguos con `group_name` siguen funcionando como grupo legado hasta reubicarlos.
- Data impact: `payment_methods.parent_id`, `payment_methods.is_payment_target`, `payment_methods.group_name`, `payment_methods.currency_code`, `payment_methods.display_order`.

### Regla: Venta asociada a mesa
- Description: El POS requiere seleccionar una mesa antes de agregar productos al pedido.
- Rationale: Evita pedidos sin contexto y permite alternar mesas sin mezclar consumos.
- Example(s): Mesa 3 cobra una cuenta; la venta y sus lineas guardan `table_id`.
- Edge cases: Si no hay mesa seleccionada, tocar un producto no agrega lineas al ticket.
- Data impact: `sales.table_id`, `sale_items.table_id`.

### Regla: Cuenta activa por mesa
- Description: Cada mesa seleccionada en POS mantiene una cuenta independiente
  aunque el usuario salga y vuelva a ingresar al POS en el mismo dispositivo.
- Rationale: El mesero debe poder alternar entre mesas abiertas, ver lo que lleva cada una y agregar, quitar o cobrar sin mezclar pedidos.
- Example(s): Mesa 1 tiene un capuccino; Mesa 2 tiene dos almuerzos; al tocar cada mesa se restaura su ticket correspondiente.
- Edge cases: Cobrar o limpiar una mesa solo vacia la cuenta de esa mesa.
- Data impact: `local_pos_open_ticket_lines` conserva pedidos abiertos;
  al cobrar se elimina el borrador y se persiste `sales.table_id`.

### Regla: Estado servido en ticket abierto
- Description: Cada fila visual del ticket abierto puede marcarse como `Servido` o pendiente. Si una fila ya esta servida y se agrega el mismo producto con las mismas opciones, el POS debe crear una nueva fila visual pendiente en lugar de aumentar la fila servida.
- Rationale: El estado servido es una ayuda operativa para el mesero; mezclar productos nuevos dentro de una fila servida puede provocar confusion y que se sirva de mas o de menos.
- Example(s): Mesa 1 tiene `Pollo` servido. Si el cliente pide otro `Pollo` igual, el ticket muestra una segunda fila `Pollo` pendiente; la fila servida original no cambia.
- Edge cases: La separacion por fila es solo visual/operativa. Al cobrar, imprimir comprobante o guardar la venta, las filas comerciales iguales se consolidan como una sola linea sumando cantidades, usando producto, opciones, precio y costo. `Servido` no altera totales, precios ni la venta historica.
- Data impact: `local_pos_open_ticket_lines.is_served` y `local_pos_open_ticket_lines.line_key` conservan el estado operativo del pedido abierto; `sales` y `sale_items` siguen guardando lineas comerciales consolidadas.

### Regla: Visualizacion operativa de mesas en POS
- Description: El POS muestra mesas ocupadas primero y mesas libres despues en una fila tactil con scroll horizontal.
- Rationale: El mesero necesita encontrar rapido las mesas activas sin perder acceso a las libres.
- Example(s): Si Mesa 9 se ocupo antes que Mesa 7, se muestran Mesa 9 y Mesa 7 al inicio; las libres se muestran luego como Mesa 1, Mesa 2, Mesa 3.
- Edge cases: La mesa seleccionada usa color azul; una mesa ocupada no seleccionada usa una etiqueta `Ocupada` con color rojo ahumado; las mesas libres no usan color especial.
- Data impact: Estado POS local `cartLinesByTable` y orden de insercion de las cuentas por mesa.

### Regla: Nombre interno y nombre operativo de mesa
- Description: Cada mesa conserva un nombre interno estable para reportes y un nombre operativo temporal visible en POS.
- Rationale: El mesero necesita usar referencias humanas flexibles sin alterar la trazabilidad del negocio.
- Example(s): `Mesa 1` puede mostrarse como `Juana de arco` durante la atencion, pero los reportes mantienen la referencia interna `Mesa 1`.
- Edge cases: Al cobrar, cancelar o liberar una mesa, el nombre operativo se limpia y vuelve a mostrarse el nombre interno; las mesas virtuales usan nombre operativo y se eliminan al ser cobradas.
- Data impact: `restaurant_tables.name`, `restaurant_tables.display_name`, `local_restaurant_tables.display_name`.

### Regla: Venta asociada a caja abierta
- Description: Al ingresar al POS, el sistema exige que el usuario actual tenga una caja abierta del dia y guarda esa referencia internamente al completar ventas.
- Rationale: Permite cuadrar ventas, efectivo esperado y auditoria de caja sin pedir IDs al cajero.
- Example(s): El cajero abre su caja desde el POS; luego cobra una venta y la venta queda relacionada a esa caja.
- Edge cases: Si no existe caja abierta del usuario, el POS muestra apertura de caja antes de permitir operar. Si la consulta falla al cobrar, conserva el carrito, no reserva numero de comprobante y no guarda venta.
- Data impact: `sales.cash_register_session_id`.

### Regla: Transacciones de caja visible desde POS
- Description: Desde `Mas opciones`, el usuario puede ver solo las ventas completadas de su caja abierta actual.
- Rationale: El cajero necesita revisar lo cobrado durante su operacion sin entrar al modulo completo de ventas ni ver transacciones de otros usuarios o cajas.
- Example(s): Cajero A abre caja, cobra tres ventas y toca `Ver Transacciones`; la pantalla muestra esas tres ventas con hora, metodo de pago y total.
- Edge cases: Si la caja esta cerrada o no existe caja abierta, la accion no esta disponible porque el POS no permite operar sin caja. Ventas de otros cajeros, otras cajas o dias anteriores no aparecen en esta vista.
- Data impact: `sales.cash_register_session_id`, `cash_register_sessions.cashier_id`.

### Regla: Navegacion de catalogo POS
- Description: Una categoria puede tener multiples niveles de categorias hijas y tambien productos directos; el POS mantiene categorias principales visibles y actualiza la grilla central al tocar otra categoria o subcategoria.
- Rationale: Cubre flujos como cafe caliente > cappuccino > 8 oz y tambien sopa con productos directos, sin hacer lento el cambio entre familias.
- Example(s): Cafe caliente muestra Cappuccino; Cappuccino muestra 8 oz; Sopa puede mostrar solo productos.
- Edge cases: Si no existen categorias, el POS muestra todos los productos activos; para volver a otra familia se toca otra categoria principal, sin boton de regreso. Si la seccion de productos esta oculta y el usuario navega por categorias, el POS vuelve a mostrarla automaticamente.
- Data impact: `product_categories.parent_id`, `products.category_id`.

### Regla: Categorias visibles aunque esten vacias
- Description: Toda categoria activa debe mostrarse en el POS aunque aun no tenga productos disponibles debajo.
- Rationale: El administrador puede preparar el menu por familias antes de cargar productos o antes de habilitar disponibilidad diaria.
- Example(s): Se crean `Bebidas Calientes`, `Almuerzos` y `Postres`; las tres aparecen como botones aunque `Postres` todavia no tenga productos.
- Edge cases: Si una categoria activa esta vacia, el panel central muestra estado vacio al seleccionarla; categorias inactivas no aparecen.
- Data impact: `product_categories.is_active`, `products.is_available_in_pos`.

### Regla: Disponibilidad diaria de producto
- Description: Un producto activo puede marcarse como disponible o no disponible en POS.
- Rationale: Permite mantener productos de comidas/bufet en el catalogo sin venderlos todos los dias.
- Example(s): `Almuerzo de pollo` existe y conserva historico, pero se oculta del POS cuando no se preparo ese dia.
- Edge cases: Un producto inactivo nunca aparece en POS; un producto activo pero no disponible no aparece en POS hasta marcarlo disponible.
- Data impact: `products.is_active`, `products.is_available_in_pos`.

### Regla: Modificadores reutilizables para platos
- Description: Los acompanamientos del POS se administran como grupos reutilizables de modificadores, no como opciones repetidas dentro de cada producto.
- Rationale: Permite asignar `Bastimento` y `Guarnicion` a varios productos como `Res`, `Pollo` o `Cerdo`, y cambiar disponibilidad diaria en un solo lugar.
- Example(s): `Carne asada`, `Pollo asado` y `Cerdo asado` usan los grupos `Bastimento` y `Guarnicion`; si se agota `Guiso de pipian`, se marca no disponible y deja de salir en todos los productos vinculados.
- Edge cases: Si un grupo requerido no tiene opciones activas y disponibles, el POS omite ese grupo para no bloquear ventas; productos sin grupos se agregan directo.
- Compatibilidad: Si un producto tiene modificadores reutilizables asignados, el POS usa solo esos grupos y no mezcla grupos legacy embebidos para evitar preguntas duplicadas.
- Data impact: `modifier_groups`, `modifier_options`, `product_modifier_groups`, `products.option_groups` como compatibilidad legacy, `local_modifier_groups`, `local_modifier_options`, `local_products.modifier_group_ids_json`, `sale_items.selected_options_label`.

### Regla: Disponibilidad diaria de modificadores
- Description: Cada opcion modificadora puede estar activa en catalogo y disponible o no disponible en POS.
- Rationale: En buffet los acompanamientos se agotan o cambian durante el dia sin que el producto principal deje de venderse.
- Example(s): Se acaba `Maduro frito`; el administrador lo marca no disponible y agrega `Guiso de papas` al grupo `Guarnicion`.
- Edge cases: Una opcion inactiva no aparece en mantenimiento operativo normal; una opcion activa pero no disponible conserva historico y no aparece en POS.
- Data impact: `modifier_options.is_active`, `modifier_options.is_available_in_pos`, `local_modifier_options`.

### Regla: Variantes del mismo producto en carrito
- Description: El carrito separa lineas por producto y opciones seleccionadas.
- Rationale: Evita mezclar el mismo plato con acompanamientos distintos.
- Example(s): `Carne asada - Acompanamiento: Tortilla` y `Carne asada - Acompanamiento: Tajadas` quedan como lineas separadas.
- Edge cases: Si se agrega el mismo producto con la misma seleccion, incrementa cantidad; si cambia la seleccion, crea otra linea.
- Data impact: `sale_items.selected_options_label`.

### Regla: Historico de precios y costos
- Description: Cada linea de venta guarda precio, costo y categoria al momento de vender.
- Rationale: Los reportes historicos no deben cambiar si cambia el producto.
- Example(s): Hamburguesa vendida a 150 mantiene ese precio aunque luego cambie a 170.
- Edge cases: Producto inactivo sigue existiendo en reportes.
- Data impact: `sale_items.unit_price`, `sale_items.unit_cost`, `sale_items.category_name`.

## Cuentas Separadas

### Regla: Estado operativo de mesa
- Description: Inactivar una mesa la marca como deshabilitada; reactivarla la vuelve disponible salvo que el sistema la conserve ocupada.
- Rationale: Evita que mantenimiento y estado operativo se contradigan en POS.
- Example(s): El administrador inactiva `Mesa terraza`; deja de estar disponible para nuevas ventas y su estado queda `disabled`.
- Edge cases: Una mesa ocupada no debe liberarse manualmente por error desde mantenimiento; al reactivar una mesa deshabilitada vuelve a `available`.
- Data impact: `restaurant_tables.is_active`, `restaurant_tables.status`, `local_sync_queue`.

### Regla: Mesa como contenedor
- Description: Al separar cuentas, la mesa original se mantiene como contenedor operativo de la division.
- Rationale: La mesa fisica sigue ocupada aunque sus consumos esten distribuidos en cuentas hijas.
- Example(s): Mesa 5 se divide en Juan, Maria y Carlos; la mesa conserva la referencia y cada item queda asignado a una cuenta hija.
- Edge cases: No se confirma si quedan productos sin asignar, cuentas sin nombre, cuentas sin productos o productos duplicados entre cuentas; la mesa original no se libera hasta que todas las cuentas hijas esten pagadas o cerradas.
- Data impact: `table_accounts`, `sale_items.table_account_id`.

### Regla: Separacion inicial en POS
- Description: La separacion de cuentas en POS requiere una mesa seleccionada
  y mas de una unidad de producto en el carrito, y se administra en una
  pantalla completa de division.
- Rationale: Cada cuenta separada debe conservar referencia a la mesa original.
- Example(s): Mesa 1 se separa en Ana y Luis; cada producto unitario se asigna a una de esas cuentas.
- Edge cases: Si la mesa tiene una sola unidad de producto, el sistema muestra
  un modal con `OK` desde el boton `Separar cuentas` y no abre la division.
  Dentro de la pantalla de division, eliminar una cuenta devuelve sus productos
  a la orden original; confirmar exige asignacion completa.
- Data impact: `AccountSplitDraft` en memoria hasta confirmar cobro.

### Regla: Cuentas hijas confirmadas
- Description: Al confirmar una division, las cuentas hijas quedan visibles en la fila de mesas para cobrarse una por una.
- Rationale: El cajero necesita seleccionar `Ana`, `Luis` o cualquier nombre operativo igual que selecciona una mesa.
- Example(s): Mesa 1 se divide en `Ana` y `Luis`; ambos aparecen como cuentas hijas ligadas a Mesa 1.
- Edge cases: Las cuentas hijas se muestran junto a la mesa original; una cuenta hija confirmada no se elimina desde afuera; solo puede modificarse desde `Editar division`, y una cuenta pagada ya no puede editarse ni recibir productos.
- Data impact: `table_accounts`, `sales.table_account_id`, `sale_items.table_account_id`.

### Regla: Pago individual por cuenta separada
- Description: Una mesa separada puede cobrar cada cuenta con metodo de pago y referencia independientes.
- Rationale: En una mesa real, una persona puede pagar en efectivo y otra por transferencia o tarjeta.
- Example(s): Ana paga efectivo; Luis paga transferencia con referencia `TRX-002`; el sistema genera dos ventas auditables.
- Edge cases: Si una cuenta hija abierta pide mas productos, se agregan a esa cuenta; si ya esta pagada, se crea una orden nueva en una mesa o cliente virtual. Si se cambia una cuenta a un metodo que no requiere referencia, la referencia se limpia para evitar datos arrastrados.
- Data impact: `sales.payment_method_id`, `sales.payment_reference`, `sales.table_account_id`.

## Caja

### Regla: Caja diaria
- Description: La caja se abre y cierra por cajero y dia desde el POS.
- Rationale: El negocio no maneja turnos.
- Example(s): Al entrar al POS, si el cajero no tiene caja abierta, declara el efectivo inicial. Desde `Mas opciones` cierra caja declarando el conteo fisico a ciegas.
- Edge cases: No se permite abrir una segunda caja para el mismo cajero y dia de negocio si ya existe una abierta; diferentes cajeros pueden tener su propia caja del mismo dia; POS requiere caja abierta antes de operar; al tocar `Cerrar caja`, si existe cualquier mesa con productos pendientes se muestra validacion inmediata y no se abre el conteo fisico; gastos usan la caja abierta si existe; una caja cerrada no queda seleccionada para nuevas transacciones; si la cola de sync falla, la caja local no se revierte en V1.
- Data impact: `cash_register_sessions`, `local_sync_queue`.

### Regla: Caja abierta de dia anterior
- Description: Si el operador actual tiene cualquier caja abierta de un dia anterior, el POS debe bloquear la apertura de una caja nueva y obligar a cerrar primero la caja pendiente.
- Rationale: Una caja abierta de ayer no puede quedar invisible por consultar solo la fecha actual; de lo contrario se rompe el cierre diario y se duplican cajas operativas.
- Example(s): El cajero deja abierta la caja del 2026-06-27. Al entrar al POS el 2026-06-28, el sistema muestra que la caja anterior quedo abierta y solo permite cerrarla antes de abrir la caja del nuevo dia.
- Edge cases: El operador se obtiene desde la sesion autenticada en `CurrentOperatorService`. El repositorio bloquea abrir una caja nueva si existe cualquier caja abierta del mismo cajero, aun cuando la UI no haya detectado el caso.
- Data impact: `cash_register_sessions.status`, `cash_register_sessions.business_date`, `cash_register_sessions.cashier_id`, `local_cash_register_sessions`.

### Regla: Salida del POS
- Description: El usuario puede salir del POS aunque existan mesas con
  productos pendientes.
- Rationale: En produccion puede ser necesario cambiar de usuario, permitir
  ingreso de administrador o ajustar catalogos/precios sin cerrar pedidos
  abiertos.
- Example(s): El mesero deja mesas abiertas, sale del POS y el administrador
  ingresa al sistema para revisar configuracion.
- Edge cases: Salir del POS no cobra, no cierra caja y no libera mesas; las
  mesas abiertas conservan su estado para continuar operacion. Si sale un
  Cajero o Mesero, se cierra su sesion y vuelve al login; si sale un
  Administrador desde POS, vuelve al panel operativo.
- Data impact: `local_pos_open_ticket_lines` conserva carritos abiertos; sin
  impacto directo en ventas hasta cobrar.

### Regla: Efectivo esperado de caja
- Description: El efectivo esperado se calcula como efectivo inicial mas ventas con metodos que afectan caja menos gastos relacionados a esa caja.
- Rationale: El cierre debe permitir comparar el conteo fisico contra lo que el sistema esperaba.
- Example(s): Inicial C$ 100, ventas efectivo C$ 70 y gastos C$ 20 producen esperado C$ 150.
- Edge cases: Ventas con tarjeta o transferencia no aumentan efectivo esperado; ventas anuladas no cuentan.
- Data impact: `cash_register_sessions`, `sales.cash_register_session_id`, `payment_methods.affects_cash_register`, `operating_expenses.cash_register_session_id`.

## Gastos

### Regla: Gasto operativo categorizado
- Description: Todo gasto operativo requiere categoria. Las categorias pueden agruparse por una categoria padre para separar familias como administrativos, combustible o mantenimiento.
- Rationale: Permite calcular ganancia real y reportar salidas.
- Example(s): `Gastos administrativos` agrupa `Papeleria`; `Gastos de combustible` agrupa `Gasolina moto`.
- Edge cases: Las categorias de gasto se eliminan desde mantenimiento; si se elimina un grupo con hijas, las hijas pasan a raiz para no perder opciones registrables. Una categoria sin hijos puede seguir usandose como categoria registrable para compatibilidad con datos existentes. Si existe caja abierta, el gasto queda relacionado a esa caja sin exponer IDs en pantalla; si la cola de sync falla, el gasto local no se revierte en V1.
- Data impact: `expense_categories.parent_id`, `operating_expenses.expense_category_id`, `operating_expenses.cash_register_session_id`, `local_sync_queue`.

### Regla: Registro de gasto desde POS
- Description: El POS permite registrar gastos desde `Mas opciones > Registrar Gasto`, mostrando grupos de categorias y luego los gastos/categorias registrables dentro del grupo. Los campos de monto y descripcion usan teclados tactiles modales.
- Rationale: El gasto operativo sucede durante la caja abierta; registrarlo desde POS reduce saltos de pantalla y conserva la relacion con la caja del usuario.
- Example(s): El cajero abre `Registrar Gasto`, toca `Gastos de combustible`, selecciona `Gasolina moto`, registra monto y descripcion.
- Edge cases: Si no hay categorias activas, se muestra estado vacio. El gasto registrado desde POS queda asociado a la caja abierta del usuario actual.
- Data impact: `local_operating_expenses.cash_register_session_id`, `local_audit_logs`, `local_sync_queue`.

## Reportes

### Regla: Rango personalizado de reportes
- Description: Los reportes pueden calcularse por dia, semana, mes, año o un rango de fechas seleccionado por el usuario.
- Rationale: El propietario puede auditar periodos especiales sin depender solo de cortes calendario.
- Example(s): Seleccionar del 10/06/2026 al 20/06/2026 muestra ventas, gastos, caja y anulaciones dentro de ese rango.
- Edge cases: La fecha inicial es inclusiva; la fecha final seleccionada se consulta como fin exclusivo del dia siguiente para no perder movimientos de ese dia.
- Data impact: `sales.created_at`, `operating_expenses.created_at`, `sale_voids.voided_at`, `cash_register_sessions.business_date`.

### Regla: Reporte dedicado de gastos
- Description: Los gastos registrados se consultan desde Reportes, no desde mantenimiento de categorias de gasto. El reporte de gastos usa el rango seleccionado y permite filtrar por categoria.
- Rationale: La pantalla de gastos queda para gestionar catalogo; la consulta operativa e historica pertenece al modulo de reportes.
- Example(s): Seleccionar `Dia` muestra los gastos de hoy; seleccionar `Rango` del 10/06/2026 al 20/06/2026 y filtrar por `Gasolina moto` muestra solo esos gastos.
- Edge cases: Si no hay gastos en el periodo, el reporte muestra estado vacio. Si una categoria historica fue eliminada, el reporte conserva el gasto y muestra la categoria como desconocida cuando no exista el nombre en catalogo.
- Data impact: `operating_expenses.created_at`, `operating_expenses.expense_category_id`, `expense_categories.parent_id`.

### Regla: Ganancia real por periodo
- Description: La ganancia real se calcula como ganancia bruta de ventas completadas menos gastos operativos del mismo periodo.
- Rationale: El propietario necesita saber cuanto gano realmente despues de salidas operativas.
- Example(s): Ventas generan C$ 1,000 de ganancia bruta y gastos suman C$ 250; ganancia real es C$ 750.
- Edge cases: Ventas anuladas no cuentan; si no hay ventas, todos los totales son cero salvo gastos.
- Data impact: `sales`, `sale_items`, `operating_expenses`.

### Regla: Ranking de productos vendidos
- Description: El ranking ordena productos por cantidad vendida y usa el historico de venta.
- Rationale: Permite identificar productos que se venden mas sin depender de cambios posteriores al catalogo.
- Example(s): Cafe con 20 unidades queda antes que pastel con 8 unidades.
- Edge cases: Si dos productos tienen igual cantidad, se ordena por monto vendido.
- Data impact: `sale_items.product_id`, `sale_items.product_name`, `sale_items.quantity`.

### Regla: Productos menos vendidos
- Description: El ranking de menor venta usa los mismos productos vendidos del periodo en orden inverso.
- Rationale: Permite detectar productos con baja rotacion sin mezclar productos que nunca tuvieron venta registrada.
- Example(s): Si pastel vendio 1 unidad y cafe vendio 20, pastel aparece primero en productos menos vendidos.
- Edge cases: Si no hay ventas en el periodo, se muestra estado vacio.
- Data impact: `sale_items.product_id`, `sale_items.product_name`, `sale_items.quantity`.

## Anulaciones

### Regla: Anulacion auditable
- Description: Una anulacion no elimina la venta; cambia estado y registra motivo y usuario responsable.
- Rationale: El propietario debe auditar anulaciones.
- Example(s): Venta anulada por error de cajero.
- Edge cases: El numero de comprobante no se reutiliza.
- Data impact: `sale_voids.reason`, `sale_voids.voided_by`, `sales.status`, `local_sync_queue`.

### Regla: Reporte de anulaciones
- Description: Las anulaciones se reportan por fecha de anulacion, no por fecha original de la venta.
- Rationale: El propietario necesita auditar lo que se anulo durante el periodo seleccionado.
- Example(s): Una venta del lunes anulada el martes cuenta en las anulaciones del martes.
- Edge cases: Una venta anulada no suma como venta completada ni como ganancia del periodo.
- Data impact: `sale_voids.voided_at`, `sales.status`.

## PDF / Comprobantes

### Regla: Comprobante PDF basico
- Description: Una venta completada puede generar un PDF no fiscal con datos de empresa, numero, fecha, metodo de pago, productos y total.
- Rationale: El cajero o administrador necesita entregar o guardar un comprobante simple desde transacciones del dia.
- Example(s): En ventas, el usuario toca el icono PDF de una venta y descarga/abre el comprobante.
- Edge cases: Si no existen datos de empresa o estan ocultos en settings, el PDF se genera sin encabezado empresarial.
- Data impact: `sales`, `sale_items`, `local_business_settings`, `payment_methods`.

### Regla: PDF basico de reportes
- Description: Un reporte cargado puede exportarse a PDF con rango, metricas principales, caja, productos y anulaciones.
- Rationale: El propietario puede guardar o compartir cortes operativos sin depender de capturas de pantalla.
- Example(s): Reporte mensual muestra ventas, ganancia real, gastos, caja y productos mas vendidos en un PDF.
- Edge cases: Si no hay ventas o anulaciones, el PDF se genera con totales en cero; no sustituye estados financieros oficiales.
- Data impact: no crea registros; usa `ReportSummary` calculado localmente.

## Settings

### Regla: Datos de empresa para PDF
- Description: Los datos del negocio se capturan una vez en settings y se usan al generar comprobantes PDF si el administrador lo habilita.
- Rationale: Evita pedir datos de empresa en cada venta y permite emitir comprobantes con informacion consistente.
- Example(s): El administrador registra nombre comercial, RUC, telefono y direccion; el PDF puede mostrarlos automaticamente.
- Edge cases: Si el administrador desactiva la visibilidad, el PDF no imprime los datos de empresa aunque esten guardados; si la cola de sync falla, settings local no se revierte en V1.
- Data impact: `local_business_settings`, `restaurants`, `local_sync_queue`.

### Regla: Numeracion configurable
- Description: El administrador define prefijo y numero inicial de factura; el sistema controla el siguiente numero.
- Rationale: La numeracion debe ser gestionada por el sistema, no digitada por el cajero.
- Example(s): Prefijo F y numero inicial 100 genera el primer comprobante como F-100 y luego F-101.
- Edge cases: Si el numero inicial sube por encima del contador interno, el sistema reinicia el contador desde ese valor.
- Data impact: `local_business_settings`, `invoice_number_settings`, `sales.invoice_number`.

## Catalogos

### Regla: Mantenimiento sin eliminacion fisica
- Description: Los catalogos operativos se mantienen editando datos visibles e inactivando registros que ya no deben usarse.
- Rationale: Ventas, gastos y reportes necesitan conservar referencias historicas aunque un dato deje de usarse.
- Example(s): Un producto deja de venderse; se marca inactivo y ya no aparece como opcion activa para ventas nuevas.
- Edge cases: Una categoria inactiva puede seguir existiendo en reportes historicos; si la cola de sync falla, el cambio local no se revierte en V1.
- Data impact: `product_categories.is_active`, `products.is_active`, `payment_methods.is_active`, `restaurant_tables.is_active`, `expense_categories.is_active`, `local_sync_queue`.

### Regla: Quitar nivel de categoria
- Description: El administrador puede quitar una subcategoria o nivel creado por error, pero no una categoria raiz.
- Rationale: Permite corregir estructuras innecesarias como `Fresca > 12 Oz > producto 12 Oz` para que el producto quede directamente en `Fresca`.
- Example(s): Al quitar el nivel `12 Oz`, sus productos y subniveles directos pasan al nivel padre y el boton/carpeta `12 Oz` desaparece del POS.
- Edge cases: Requiere confirmacion; no se muestra accion de quitar en categorias raiz; ventas historicas conservan el texto del producto vendido.
- Data impact: `product_categories.parent_id`, `products.category_id`, `local_sync_queue`.

### Regla: Quitar nivel de metodo de pago
- Description: El administrador puede quitar un nivel interno de pago creado por error, pero no un metodo raiz como `Efectivo` o `Transferencias`.
- Rationale: Permite corregir arboles de cobro sin perder bancos, cuentas u opciones finales ya configuradas.
- Example(s): Si `Transferencias > BANPRO > Cuenta 7888889` fue armado con un nivel intermedio innecesario, al quitar `BANPRO` la cuenta pasa directamente a `Transferencias`.
- Edge cases: Requiere confirmacion; no se muestra accion de quitar en metodos raiz; si el nivel quitado tiene hijos directos, esos hijos quedan reubicados en el nivel anterior.
- Data impact: `payment_methods.parent_id`, `local_sync_queue`, `local_audit_logs`.

## Roles Y Permisos

### Regla: Permisos granulares
- Description: Las acciones sensibles y pantallas del sistema deben validarse contra permisos asignados al rol del usuario.
- Rationale: El propietario requiere que gastos, anulaciones, configuracion y reportes no queden disponibles para todos los cajeros.
- Example(s): Un cajero puede registrar ventas, pero no crear categorias de gastos ni ver reportes completos si su rol no lo permite. Si intenta navegar manualmente a una ruta no permitida, el sistema muestra `Acceso restringido`.
- Edge cases: El dashboard solo muestra modulos permitidos; las rutas tambien se protegen para evitar acceso escribiendo URL manual. El rol administrador del sistema conserva acceso completo. La validacion debe hacerse desde `AccessControlService` o `RouteAccessGuard`; si la cola de sync falla, el cambio local no se revierte en V1.
- Data impact: `roles`, `permissions`, `role_permissions`, `profiles`, `local_roles`, `local_permissions`, `local_role_permissions`, `local_user_profiles`, `local_sync_queue`.

## Auditoria

### Regla: Bitacora local de acciones sensibles
- Description: Las acciones sensibles deben poder registrarse en una bitacora local auditable.
- Rationale: El propietario necesita trazabilidad incluso antes de sincronizar con Supabase.
- Example(s): Anulacion de venta, mantenimiento de roles o mantenimiento de usuarios.
- Edge cases: Si no existe usuario autenticado todavia, `actorUserId` puede quedar vacio y completarse cuando Auth este activo; si la cola de sync falla, la auditoria local no se revierte en V1.
- Data impact: `audit_logs`, `local_audit_logs`, `local_sync_queue`.

### Regla: Acciones auditadas en V1 local
- Description: Las anulaciones de ventas y los cambios de catalogos, roles, usuarios, caja, gastos y settings escriben una entrada de auditoria local al completar la accion.
- Rationale: Son acciones sensibles que deben revisarse por dia antes de sincronizar con la nube.
- Example(s): Anular venta registra `sales.void`; guardar producto registra `products.save`; guardar metodo de pago registra `payment_methods.save`; guardar mesa registra `tables.save`; abrir caja registra `cash.open`; guardar settings registra `settings.save`.
- Edge cases: Si la escritura de auditoria falla, la accion principal no se revierte en V1; el repositorio local captura fallas para diagnostico.
- Data impact: `local_audit_logs.action`, `local_audit_logs.entity_type`, `local_audit_logs.entity_id`, `local_audit_logs.details_json`.

## Supabase Readiness

### Regla: Modulos locales listos para migracion
- Description: Todo modulo que guarde datos localmente debe tener equivalencia remota, payload de sincronizacion, auditoria cuando aplique y mapeo de restaurante/usuario definido.
- Rationale: Permite terminar la V1 local sin rehacer flujos cuando se conecte Supabase remoto.
- Example(s): Un producto local debe poder sincronizarse a `products` con restaurante, categoria, codigo, precio, costo, disponibilidad y opciones.
- Edge cases: Si local usa un valor temporal como `usuario-local`, debe estar centralizado y marcado como deuda antes de remoto; si Supabase exige un campo no capturado en UI, debe existir un mapeo deterministico o bloquearse la migracion.
- Related screens/flows: catalogos, POS, caja, gastos, usuarios, sync.
- Data impact: `Documentation/SUPABASE_READINESS_AUDIT.md`, `supabase/migrations`, `local_sync_queue`.

# Requerimiento General Refinado - SmooControl

## 1. Vision del producto

SmooControl sera una aplicacion desarrollada en Flutter/Dart para ayudar a restaurantes pequenos y medianos a registrar sus ventas, controlar productos, administrar mesas y obtener reportes utiles para tomar decisiones del negocio.

La primera version debe enfocarse en capturar ventas de forma confiable, incluso sin internet, y permitir conocer cuanto se vende, que productos se venden mas o menos, y cuales son las ganancias por periodo.

## 2. Objetivo de la version 1.0

La version 1.0 debe permitir:

- Registrar ventas del restaurante.
- Registrar categorias y subcategorias de productos.
- Registrar productos con su costo y precio de venta.
- Aperturar y cerrar el dia de caja de forma basica.
- Registrar gastos operativos del negocio.
- Generar PDF de factura o comprobante desde ventas/transacciones del dia.
- Configurar metodos de pago.
- Anular ventas dejando auditoria completa.
- Configurar datos de empresa para mostrarlos en PDF.
- Configurar numeracion inicial de facturas o comprobantes.
- Separar una mesa en varias cuentas o facturas con nombre.
- Calcular ventas por dia, semana, mes y ano.
- Calcular ganancias por dia, semana, mes y ano.
- Calcular ganancia real descontando gastos operativos.
- Identificar productos mas vendidos.
- Identificar productos menos vendidos.
- Trabajar offline-first.
- Sincronizar ventas, anulaciones y gastos automaticamente con Supabase cuando exista internet.

## 3. Alcance funcional de la version 1.0

### 3.1 Autenticacion

La app debe permitir inicio de sesion con Google.

Requerimientos:

- Usar Google como proveedor de autenticacion.
- Usar Supabase como backend de autenticacion y base de datos.
- Permitir acceso solo a usuarios autenticados.

### 3.2 Usuarios

La app debe permitir registrar y administrar usuarios.

Datos minimos del usuario:

- Id.
- Nombre.
- Correo.
- Rol.
- Estado: activo o inactivo.

### 3.3 Roles y permisos

La app debe manejar roles y permisos para controlar el acceso a las funciones.

Roles iniciales sugeridos:

- Administrador.
- Cajero.
- Mesero.

Permisos iniciales sugeridos:

- Gestionar usuarios.
- Gestionar roles.
- Gestionar mesas.
- Gestionar productos.
- Registrar ventas.
- Aperturar caja.
- Cerrar caja.
- Gestionar categorias de gastos.
- Registrar gastos operativos.
- Generar PDF de factura o comprobante.
- Gestionar metodos de pago.
- Separar cuentas de una mesa.
- Anular ventas.
- Ver reporte de anulaciones.
- Configurar datos de empresa.
- Configurar numeracion de comprobantes.
- Ver reportes.
- Configurar sincronizacion.

Reglas de permisos:

- Los permisos deben ser granulares por accion.
- Solo el administrador o propietario debe poder registrar gastos operativos, salvo que se asigne permiso explicito a otro rol.
- Solo usuarios autorizados pueden anular ventas.
- Solo el administrador o propietario debe poder configurar metodos de pago, datos de empresa y numeracion.
- El cajero debe poder operar ventas, caja diaria y transacciones del dia segun permisos asignados.

### 3.4 Mesas

La app debe permitir registrar mesas del restaurante.

Datos minimos de mesa:

- Id.
- Nombre.
- Estado: activa o inactiva.

Nota: aunque el requerimiento inicial define solo el campo nombre, se recomienda incluir estado para poder desactivar mesas sin eliminar historico.

### 3.5 Productos

Antes de registrar productos, la app debe permitir crear un catalogo de categorias y subcategorias para organizar el flujo de facturacion.

### 3.5.1 Categorias y subcategorias

La app debe permitir registrar categorias de productos.

Ejemplos:

- Cafe Caliente.
- Cafe Frio.
- Bebidas.
- Postres.
- Ensaladas.
- Sopa.
- Sandwich/Panini.
- Desayunos.
- Otros.
- Kiosco.

La app tambien debe permitir registrar subcategorias dentro de una categoria.

Ejemplo:

- Cafe Caliente.
  - Espresso.
  - Americano.
  - Cappuccino.
  - Latte.
  - Flat White.
  - Metodos.

Dentro de una subcategoria pueden existir productos u opciones vendibles.

Ejemplo:

- Cafe Caliente > Espresso.
  - Sencillo.
  - Macchiato.
  - Cortadito.
  - Doble.
  - Sencillo sin vaso.

Tambien debe permitirse que una categoria principal tenga productos directamente, sin obligar a crear subcategorias.

Ejemplo:

- Sopa.
  - Sopa de tortilla.
  - Crema de tomate.
  - Crema de brocoli.
  - Sopa de queso 16oz.
  - Sopa de cebolla.
  - Sopa de queso.

Datos minimos de categoria:

- Id.
- Nombre.
- Categoria padre, si aplica.
- Orden de visualizacion.
- Estado: activa o inactiva.

Reglas:

- Una categoria sin categoria padre se considera categoria principal.
- Una categoria con categoria padre se considera subcategoria.
- La estructura debe soportar al menos dos niveles: categoria y subcategoria.
- La estructura debe permitir crecer a mas niveles si el negocio lo necesita.
- La subcategoria es opcional; un producto puede pertenecer directamente a una categoria principal.
- Una categoria inactiva no debe mostrarse en facturacion.
- Los productos deben asignarse a una categoria o subcategoria.
- En la pantalla de facturacion deben mostrarse primero las categorias principales.
- Al seleccionar una categoria, deben mostrarse sus subcategorias y/o productos relacionados.
- Al seleccionar una subcategoria, deben mostrarse sus productos vendibles.

### 3.5.2 Productos

La app debe permitir registrar productos disponibles para la venta.

Datos minimos de producto:

- Id.
- Codigo.
- Nombre del producto.
- Categoria o subcategoria.
- Costo.
- Precio de venta.
- Enviar a cocina: si/no.
- Estado: activo o inactivo.

Reglas:

- El codigo debe ser unico.
- El costo debe ser mayor o igual a 0.
- El precio de venta debe ser mayor que 0.
- Todo producto debe pertenecer a una categoria o subcategoria activa.
- La ganancia base del producto se calcula como precio de venta menos costo.
- Los productos inactivos no deben aparecer para nuevas ventas, pero deben conservarse para reportes historicos.

### 3.6 Facturacion / POS

La pantalla de facturacion debe permitir seleccionar productos de forma rapida usando categorias y subcategorias.

Comportamiento esperado:

- Mostrar el detalle de la venta actual en la parte superior o en un panel visible.
- Mostrar categorias principales en un panel lateral o seccion fija.
- Mostrar subcategorias y/o productos en una grilla de botones grandes.
- Al tocar una categoria, cargar sus subcategorias y/o sus productos directos.
- Al tocar una subcategoria, cargar sus productos.
- Al tocar un producto, agregarlo al detalle de la venta.
- Permitir modificar cantidad.
- Permitir agregar comentario a la venta o a un producto, si aplica.
- Permitir crear cuentas separadas con nombre cuando la mesa lo requiera.
- Permitir seleccionar a que cuenta se asigna cada producto.
- Permitir separar cuentas desde un boton visible llamado `Separar cuentas` o equivalente.
- Permitir asignar productos a cuentas usando arrastrar y soltar en pantallas grandes.
- Permitir asignar productos a cuentas usando seleccion por toque en pantallas pequenas.
- Permitir ver el total acumulado por cada cuenta de la mesa.
- Permitir confirmar la venta.

Ejemplo de flujo:

1. El usuario selecciona `Cafe Caliente`.
2. La app muestra `Espresso`, `Americano`, `Cappuccino`, `Latte`, etc.
3. El usuario selecciona `Espresso`.
4. La app muestra `Sencillo`, `Macchiato`, `Cortadito`, `Doble`.
5. El usuario selecciona `Sencillo`.
6. La app agrega el producto al detalle de venta.

Ejemplo de flujo sin subcategoria:

1. El usuario selecciona `Sopa`.
2. La app muestra directamente `Sopa de tortilla`, `Crema de tomate`, `Crema de brocoli`, etc.
3. El usuario selecciona `Sopa de tortilla`.
4. La app agrega el producto al detalle de venta.

Regla clave:

- Si un elemento tiene hijos, se comporta como categoria/subcategoria.
- Si un elemento no tiene hijos y tiene precio, se comporta como producto vendible.
- Una categoria puede contener productos directos, subcategorias o ambos.

### 3.7 Cuentas separadas por mesa

La app debe permitir separar una mesa en varias cuentas o facturas con nombre.

Escenario:

- Una mesa tiene varias personas.
- Las personas solicitan cuentas separadas.
- El cajero o mesero crea nombres para cada cuenta.
- Cada producto consumido se asigna a la cuenta correspondiente.
- Al finalizar, cada cuenta puede facturarse por separado.

Ejemplo:

- Mesa 5.
  - Cuenta: Juan.
  - Cuenta: Maria.
  - Cuenta: Carlos.

Datos minimos de cuenta separada:

- Id.
- Mesa.
- Referencia de mesa original.
- Nombre de la cuenta.
- Usuario que la creo.
- Fecha y hora de creacion.
- Estado: abierta, facturada o anulada.

Reglas:

- Una mesa puede tener una o varias cuentas abiertas.
- Si una mesa no tiene cuentas separadas, la venta se registra como cuenta unica de la mesa.
- Toda cuenta separada debe mantener referencia obligatoria a la mesa original.
- El nombre de la cuenta debe ser obligatorio cuando se separa la mesa.
- Un producto agregado a una mesa con cuentas separadas debe asignarse a una cuenta.
- Al confirmar la separacion, la mesa no debe quedar con productos cargados sin asignar.
- Una cuenta puede generar su propia venta, factura o comprobante.
- Cada cuenta facturada debe recibir su propio numero de comprobante.
- Una cuenta facturada no debe permitir agregar nuevos productos.
- Debe permitirse mover productos entre cuentas mientras no esten facturadas.
- Debe permitirse renombrar una cuenta mientras no este facturada.
- La pantalla de POS debe permitir ver la mesa, sus cuentas y el total de cada cuenta.

Flujo sugerido para separar cuentas:

1. El usuario abre una mesa con productos ya agregados.
2. El usuario presiona el boton `Separar cuentas`.
3. La app pregunta en cuantas cuentas se desea separar la mesa.
4. El usuario indica la cantidad de cuentas, por ejemplo `4`.
5. La app crea nombres automaticos: `Cuenta 1`, `Cuenta 2`, `Cuenta 3`, etc.
6. La app abre una pantalla de separacion de cuentas.
7. La pantalla muestra a la izquierda todos los productos cargados a la mesa.
8. La pantalla muestra a la derecha las cuentas creadas.
9. El usuario puede renombrar cada cuenta.
10. En pantallas grandes, el usuario arrastra productos desde el panel izquierdo hacia cada cuenta.
11. En pantallas pequenas, el usuario toca un producto y luego toca la cuenta destino.
12. La app permite mover varios productos a la vez cuando sea posible.
13. La app recalcula el total de cada cuenta automaticamente.
14. La app valida que no queden productos cargados directamente a la mesa.
15. El usuario confirma la separacion.
16. Cada cuenta queda referenciada a la mesa original y lista para facturarse de forma independiente.

Diseño funcional de la pantalla de separacion:

- Panel izquierdo: productos pendientes de asignar.
- Panel derecho: cuentas separadas.
- Cada cuenta debe mostrar nombre, productos asignados, cantidades y total.
- Debe permitirse arrastrar productos entre cuentas.
- En movil, debe permitirse asignar productos tocando producto y luego cuenta destino.
- Debe permitirse seleccionar varios productos y enviarlos a una cuenta cuando la pantalla lo permita.
- Debe mostrarse un contador de productos pendientes de asignar.
- Debe existir accion para deshacer el ultimo movimiento.
- Debe permitirse devolver productos desde una cuenta al panel de pendientes.
- Debe mostrarse advertencia si quedan productos sin asignar.
- No debe permitirse confirmar la separacion si existen productos sin asignar.
- Al confirmar, todos los productos deben quedar dentro de una cuenta separada.
- La mesa debe quedar como contenedor de las cuentas, sin productos cargados directamente.
- Debe existir una accion para cancelar y volver a la mesa sin aplicar cambios.
- Debe permitirse guardar la separacion y continuar agregando productos luego a una cuenta especifica.

### 3.8 Ventas

La app debe permitir registrar ventas.

Datos minimos de una venta:

- Id local.
- Id remoto en Supabase, cuando ya este sincronizada.
- Fecha y hora.
- Usuario que registro la venta.
- Mesa, si aplica.
- Cuenta separada, si aplica.
- Nombre de cuenta/factura, si aplica.
- Total de venta.
- Total de costo.
- Ganancia.
- Metodo de pago.
- Referencia de pago, si aplica.
- Numero de factura o comprobante.
- Estado de venta: completada o anulada.
- Estado de sincronizacion.

Datos minimos del detalle de venta:

- Id.
- Id de venta.
- Producto.
- Cuenta separada, si aplica.
- Categoria del producto al momento de la venta.
- Cantidad.
- Precio unitario.
- Costo unitario.
- Subtotal.
- Ganancia.

Reglas:

- Una venta debe tener al menos un producto.
- La cantidad debe ser mayor que 0.
- El precio usado en la venta debe guardarse en el detalle para mantener historico aunque el producto cambie despues.
- El costo usado en la venta debe guardarse en el detalle para poder calcular ganancias historicas correctamente.
- La categoria del producto usada en la venta debe guardarse para reportes historicos aunque el producto cambie de categoria despues.
- La ganancia de una linea se calcula como: `(precio unitario - costo unitario) * cantidad`.
- La ganancia total de la venta es la suma de las ganancias de sus lineas.
- El total de venta es la suma de los subtotales.
- Toda venta debe tener metodo de pago.
- Si el metodo de pago requiere referencia, el sistema debe solicitarla.
- Una venta anulada no debe eliminarse; debe conservarse para auditoria y reportes.
- Si la venta proviene de una cuenta separada, debe conservar el nombre de la cuenta/factura.

### 3.9 Metodos de pago

La app debe incluir un catalogo de metodos de pago.

Metodos iniciales sugeridos:

- Efectivo.
- Tarjeta.
- Transferencia.
- Otro.

Datos minimos de metodo de pago:

- Id.
- Nombre.
- Requiere referencia: si/no.
- Afecta efectivo en caja: si/no.
- Orden de visualizacion.
- Estado: activo o inactivo.

Reglas:

- Solo los metodos activos deben mostrarse al registrar ventas.
- El metodo `Efectivo` debe afectar el efectivo esperado de caja.
- Los metodos `Tarjeta` y `Transferencia` pueden configurarse para requerir referencia.
- Si un metodo requiere referencia, el usuario no debe poder completar la venta sin ingresarla.
- Una referencia puede ser numero de voucher, comprobante, transaccion bancaria u otro identificador.
- Una venta pagada con tarjeta o transferencia no debe aumentar el efectivo esperado de caja.
- El administrador debe poder crear, editar, activar e inactivar metodos de pago.
- No se debe eliminar un metodo de pago con ventas historicas; debe inactivarse.

### 3.10 Anulaciones de ventas

La app debe permitir anular ventas manteniendo auditoria completa.

Datos minimos de anulacion:

- Id.
- Venta anulada.
- Fecha y hora de anulacion.
- Usuario que anula.
- Motivo de anulacion.
- Total anulado.
- Metodo de pago original.
- Referencia de pago original, si aplica.
- Caja asociada.

Reglas:

- Una venta anulada no debe borrarse.
- Una venta anulada debe cambiar su estado a `anulada`.
- La anulacion debe guardar usuario, fecha, hora y motivo.
- Solo usuarios con permiso pueden anular ventas.
- El administrador o propietario debe poder ver reportes de anulaciones.
- Si la venta anulada fue en efectivo, debe afectar el cierre de caja segun la regla definida para efectivo.
- Si la venta anulada fue tarjeta o transferencia, debe quedar registrada para conciliacion.
- Las anulaciones deben poder consultarse por dia, semana, mes o rango de fechas.
- Las anulaciones deben ser sincronizables y auditables.

### 3.11 Factura o comprobante PDF

La app debe permitir generar un PDF como factura o comprobante basico de una venta.

Ubicacion sugerida:

- Desde el detalle de una venta.
- Desde la pantalla de transacciones del dia.

Datos minimos del PDF:

- Nombre del restaurante, si esta configurado.
- Razon social o nombre comercial, si esta configurado.
- Identificacion fiscal, si esta configurada.
- Direccion, si esta configurada.
- Telefono, si esta configurado.
- Logo, si esta configurado.
- Fecha y hora de la venta.
- Numero o codigo de venta.
- Usuario que registro la venta.
- Mesa, si aplica.
- Nombre de cuenta/factura, si aplica.
- Productos vendidos.
- Cantidad por producto.
- Precio unitario.
- Subtotal por producto.
- Total de la venta.
- Metodo de pago.
- Referencia de pago, si aplica.

Acciones minimas:

- Generar PDF.
- Compartir PDF.
- Descargar o guardar PDF en el dispositivo, si la plataforma lo permite.

Reglas:

- El PDF debe generarse desde los datos historicos de la venta, no desde los datos actuales del producto.
- Si la venta esta pendiente de sincronizacion, el PDF debe poder generarse usando la informacion local.
- Los datos de empresa deben mostrarse en el PDF solo si el administrador los configura para mostrarse.
- En version 1.0 el PDF sera un comprobante basico; no implica facturacion fiscal oficial salvo que se defina como alcance adicional.

### 3.12 Configuracion de empresa y numeracion

La app debe incluir una pantalla de configuracion para datos de empresa y numeracion de comprobantes.

Datos minimos de empresa:

- Nombre comercial.
- Razon social, si aplica.
- Identificacion fiscal, si aplica.
- Direccion.
- Telefono.
- Correo.
- Logo, si aplica.
- Mostrar datos de empresa en PDF: si/no.

Datos minimos de numeracion:

- Prefijo de comprobante, si aplica.
- Numero inicial.
- Siguiente numero a emitir.

Reglas:

- El administrador debe poder definir desde Settings el inicio de la numeracion.
- Cada venta completada debe recibir un numero unico de factura o comprobante.
- El numero debe conservarse aunque la venta se anule.
- Una venta anulada no debe liberar ni reutilizar su numero.
- El PDF debe usar el numero historico asignado a la venta.

### 3.13 Caja diaria

La app debe permitir que los cajeros aperturen y cierren el dia de trabajo de forma basica.

Objetivo:

- Registrar el efectivo inicial entregado al cajero para dar cambio.
- Registrar el conteo fisico de efectivo al cierre.
- Comparar el efectivo esperado contra el efectivo contado.
- Dejar evidencia del usuario que aperturo y cerro caja.

Datos minimos de apertura de caja:

- Id.
- Usuario cajero.
- Fecha y hora de apertura.
- Monto inicial para cambio.
- Estado: abierta o cerrada.

Datos minimos de cierre de caja:

- Fecha y hora de cierre.
- Usuario que realiza el cierre.
- Total de ventas registradas.
- Total vendido en efectivo, si se registra metodo de pago.
- Total vendido por tarjeta.
- Total vendido por transferencia.
- Total vendido por otros metodos.
- Total de anulaciones.
- Total de gastos operativos pagados desde caja.
- Monto inicial para cambio.
- Efectivo esperado.
- Efectivo contado fisicamente.
- Diferencia: sobrante o faltante.
- Comentario de cierre, si aplica.

Reglas:

- Un cajero no debe registrar ventas si no tiene una caja abierta, salvo que el administrador permita una excepcion.
- La caja se maneja por dia, no por turnos.
- Solo debe existir una caja abierta por cajero y por dia.
- La apertura requiere ingresar el monto inicial de efectivo para cambio.
- El cierre requiere ingresar el conteo fisico del efectivo.
- El efectivo esperado se calcula considerando el monto inicial, las ventas en efectivo, anulaciones en efectivo y los gastos operativos pagados desde caja.
- La diferencia se calcula como: `efectivo contado - efectivo esperado`.
- Si la diferencia es positiva, se considera sobrante.
- Si la diferencia es negativa, se considera faltante.
- Una caja cerrada no debe permitir nuevas ventas asociadas a esa caja.
- Las ventas deben asociarse a la caja abierta del usuario.
- Los gastos pagados desde caja deben asociarse a la caja abierta correspondiente.
- Las anulaciones deben asociarse a la caja correspondiente cuando afecten ventas del dia.
- El cierre debe mostrar totales separados por metodo de pago.
- El cierre de caja debe poder consultarse posteriormente en reportes.

Nota: para la version 1.0, el cierre de caja sera basico y por dia. No requiere turnos ni arqueo avanzado por denominaciones.

### 3.14 Gastos operativos

La app debe permitir registrar gastos operativos del restaurante para conocer la ganancia real del negocio.

Problema que resuelve:

- Durante el dia se toma dinero de caja para compras, servicios basicos o pagos al personal.
- Si esos gastos no se registran, el reporte de ganancia queda incompleto.
- La app debe mostrar cuanto se gano realmente despues de descontar estos gastos.

### 3.14.1 Categorias de gastos

La app debe incluir un catalogo simple para administrar categorias de gastos operativos.

Categorias iniciales sugeridas:

- Gastos varios.
- Gastos de nomina.
- Gastos de inventario.
- Servicios basicos.
- Mantenimiento.
- Transporte.
- Otros.

Datos minimos de categoria de gasto:

- Id.
- Nombre.
- Descripcion, si aplica.
- Orden de visualizacion.
- Estado: activa o inactiva.

Reglas:

- Todo gasto operativo debe pertenecer a una categoria de gasto.
- Solo las categorias activas deben mostrarse al registrar gastos.
- Una categoria inactiva no debe eliminar gastos historicos.
- El administrador debe poder crear, editar, activar e inactivar categorias de gasto.
- No se debe permitir eliminar una categoria si ya tiene gastos asociados; debe inactivarse.
- Las categorias de gasto deben usarse como filtro en reportes.

### 3.14.2 Registro de gastos

Datos minimos de un gasto operativo:

- Id.
- Fecha y hora.
- Categoria de gasto.
- Descripcion.
- Monto.
- Usuario que registra el gasto.
- Caja asociada, si el dinero salio de caja.
- Metodo de pago, si aplica.
- Comentario, si aplica.
- Estado de sincronizacion.

Reglas:

- El monto del gasto debe ser mayor que 0.
- Todo gasto debe tener una categoria.
- Si el gasto se paga con efectivo de caja, debe asociarse a una caja abierta.
- Los gastos pagados desde caja reducen el efectivo esperado al cierre.
- Los gastos deben poder registrarse offline y sincronizarse despues.
- Los gastos deben conservarse para reportes historicos aunque se cambie la categoria despues.
- La ganancia real se calcula como: `ganancia bruta - gastos operativos`.
- La ganancia bruta se calcula desde las ventas usando precio menos costo de productos vendidos.
- La ganancia real debe poder consultarse por dia, semana, mes y ano.

Ejemplos:

- Compra de leche, vasos o materia prima durante el dia.
- Pago de internet.
- Pago de energia electrica.
- Pago al personal.
- Compra de articulos de limpieza.

### 3.15 Reportes

La app debe permitir consultar reportes de ventas y ganancias.

Reportes minimos de la version 1.0:

- Transacciones del dia.
- Anulaciones por dia.
- Anulaciones por semana.
- Anulaciones por mes.
- Anulaciones por rango de fechas.
- Ventas por metodo de pago.
- Ventas por dia.
- Ventas por semana.
- Ventas por mes.
- Ventas por ano.
- Ganancias por dia.
- Ganancias por semana.
- Ganancias por mes.
- Ganancias por ano.
- Ganancia real por dia.
- Ganancia real por semana.
- Ganancia real por mes.
- Ganancia real por ano.
- Gastos operativos por dia.
- Gastos operativos por semana.
- Gastos operativos por mes.
- Gastos operativos por ano.
- Gastos operativos por categoria.
- Cierres de caja por dia.
- Productos mas vendidos por cantidad.
- Productos menos vendidos por cantidad.
- Productos que generan mas ganancia.
- Productos que generan menos ganancia.
- Ventas por categoria.
- Ganancias por categoria.

Filtros minimos:

- Rango de fechas.
- Categoria.
- Categoria de gasto, si aplica.
- Metodo de pago, si aplica.
- Usuario, si aplica.
- Producto, si aplica.

Metricas minimas:

- Total vendido.
- Total vendido por metodo de pago.
- Total anulado.
- Total de costo.
- Ganancia bruta.
- Total de gastos operativos.
- Ganancia real.
- Cantidad de ventas.
- Cantidad de productos vendidos.
- Diferencia de caja, si aplica.

## 4. Offline-first

La aplicacion debe funcionar aunque el dispositivo no tenga internet.

Requerimientos:

- Las ventas deben guardarse primero en una base local.
- Las anulaciones deben guardarse primero en una base local.
- Los gastos operativos deben guardarse primero en una base local.
- La app no debe bloquear el registro de ventas por falta de conexion.
- La app no debe bloquear el registro de anulaciones por falta de conexion si la venta existe localmente.
- La app no debe bloquear el registro de gastos por falta de conexion.
- Cada venta debe tener un estado de sincronizacion.
- Cada anulacion debe tener un estado de sincronizacion.
- Cada gasto operativo debe tener un estado de sincronizacion.
- Al recuperar internet, la app debe intentar sincronizar ventas, anulaciones y gastos pendientes.

Estados sugeridos de sincronizacion:

- Pendiente.
- Sincronizando.
- Sincronizada.
- Error.

Reglas:

- Una venta sincronizada no debe duplicarse en Supabase.
- Una anulacion sincronizada no debe duplicarse en Supabase.
- Un gasto sincronizado no debe duplicarse en Supabase.
- Si falla la sincronizacion, la venta, anulacion o gasto debe quedar disponible para reintento.
- La app debe conservar el historico local necesario para operar y mostrar reportes basicos.
- Los catalogos necesarios para operar offline deben estar disponibles localmente: productos, categorias, mesas, metodos de pago y categorias de gastos.

## 5. Sincronizacion automatica

La app debe incluir un proceso automatico de sincronizacion de ventas, anulaciones y gastos operativos.

Configuracion desde Settings:

- Sincronizar cada 5 minutos.
- Sincronizar cada 20 minutos.
- Sincronizar cada 30 minutos.

Reglas:

- El proceso debe iniciar automaticamente si detecta internet y existen ventas, anulaciones o gastos pendientes.
- El proceso debe respetar el intervalo configurado por el usuario.
- El proceso debe evitar enviar la misma venta, anulacion o gasto mas de una vez.
- El usuario debe poder ver si existen ventas, anulaciones o gastos pendientes de sincronizar.
- El usuario debe poder ejecutar una sincronizacion manual desde Settings.

## 6. Backend y base de datos

La app debe usar Supabase para:

- Autenticacion.
- Base de datos remota.
- Sincronizacion de datos.

Tablas remotas sugeridas:

- users.
- roles.
- permissions.
- role_permissions.
- company_settings.
- invoice_number_settings.
- product_categories.
- payment_methods.
- tables.
- table_accounts.
- products.
- sales.
- sale_items.
- sale_voids.
- cash_register_sessions.
- expense_categories.
- operating_expenses.
- sync_logs.
- settings.

La estructura final puede ajustarse durante el diseno tecnico, manteniendo el objetivo de reportes y sincronizacion offline-first.

## 7. Requerimientos no funcionales

### 7.1 Plataforma

La app sera desarrollada en Flutter/Dart.

Plataformas objetivo iniciales:

- Android.

Plataformas futuras posibles:

- iOS.
- Web.
- Desktop.

### 7.2 Arquitectura

El proyecto debe seguir las reglas definidas en `rules.md`:

- Estructura feature-first.
- Clean Architecture por feature.
- BLoC para manejo de estado.
- Repositorios con interfaces en dominio.
- Implementaciones en capa data.
- Textos en archivos de localizacion.
- Analisis limpio con `flutter analyze`.
- Pruebas para dominio, BLoC y flujos criticos.

### 7.3 Localizacion

La aplicacion debe estar preparada desde el inicio para multiples idiomas.

Idiomas minimos:

- Espanol.
- Ingles.

### 7.4 Seguridad

Requerimientos:

- Solo usuarios autenticados pueden usar la app.
- Los permisos deben controlar el acceso a pantallas y acciones.
- Los datos deben asociarse al usuario o restaurante correspondiente.
- Supabase debe aplicar reglas de seguridad segun corresponda.

## 8. Modulos sugeridos para version 1.0

- Auth.
- Usuarios.
- Roles y permisos.
- Categorias.
- Mesas.
- Cuentas separadas.
- Productos.
- Ventas.
- Metodos de pago.
- Anulaciones.
- Caja.
- Categorias de gastos.
- Gastos operativos.
- Reportes.
- Settings.
- Sincronizacion.

## 9. Criterios de aceptacion generales

La version 1.0 se considera aceptada cuando:

- Un usuario puede iniciar sesion con Google.
- Un administrador puede registrar usuarios, roles y permisos.
- Un usuario autorizado puede registrar mesas.
- Un usuario autorizado puede registrar categorias y subcategorias.
- Un usuario autorizado puede registrar productos.
- Los productos pueden asociarse a una categoria o subcategoria.
- La pantalla de facturacion permite navegar por categorias, subcategorias y productos.
- Un usuario autorizado puede separar una mesa en varias cuentas con nombre.
- Un usuario autorizado puede asignar productos a cada cuenta separada.
- Cada cuenta separada puede facturarse de forma independiente.
- Cada cuenta separada facturada recibe su propio numero de comprobante.
- Un administrador puede configurar metodos de pago.
- Un metodo de pago puede configurarse para requerir referencia.
- Un usuario autorizado puede registrar ventas.
- Toda venta queda asociada a un metodo de pago.
- Las ventas con metodo de pago que requiere referencia no pueden completarse sin referencia.
- Cada venta completada recibe numero unico de factura o comprobante.
- Un administrador puede configurar el numero inicial de comprobantes desde Settings.
- Un administrador puede configurar los datos de empresa que apareceran en el PDF.
- Un usuario autorizado puede generar PDF de factura o comprobante desde una venta.
- Un usuario autorizado puede generar PDF desde la pantalla de transacciones del dia.
- Un usuario autorizado puede anular ventas indicando motivo.
- Toda anulacion queda registrada con usuario, fecha, hora, motivo y venta asociada.
- El administrador o propietario puede consultar reporte de anulaciones por dia, semana, mes o rango de fechas.
- Un cajero puede aperturar caja ingresando el monto inicial para cambio.
- Un cajero puede cerrar caja ingresando el conteo fisico.
- La caja se maneja por dia y no por turnos.
- El cierre de caja muestra totales separados por metodo de pago.
- El sistema calcula diferencia entre efectivo esperado y efectivo contado.
- Un administrador puede crear, editar, activar e inactivar categorias de gastos.
- Un usuario autorizado puede registrar gastos operativos.
- Todo gasto operativo queda asociado a una categoria de gasto.
- Los gastos pagados desde caja reducen el efectivo esperado al cierre.
- Las ventas pueden registrarse sin internet.
- Los gastos pueden registrarse sin internet.
- Las ventas y gastos pendientes se sincronizan al recuperar internet.
- El intervalo de sincronizacion puede configurarse desde Settings.
- Se pueden ver reportes de ventas por dia, semana, mes y ano.
- Se pueden ver reportes de ventas por metodo de pago.
- Se pueden ver reportes de ganancias por dia, semana, mes y ano.
- Se pueden ver reportes de gastos operativos por periodo y categoria.
- Se puede ver ganancia real descontando gastos operativos.
- Se pueden identificar productos mas vendidos y menos vendidos.
- Se pueden identificar productos con mayor y menor ganancia.
- Se pueden consultar ventas y ganancias por categoria.

## 10. Pendientes por definir

Antes o durante el diseno tecnico se deben confirmar estos puntos:

- Si la version 1.0 manejara multiples restaurantes o solo uno.
- Si una venta siempre debe estar asociada a una mesa o puede ser venta directa.
- Si las cuentas separadas deben permitir dividir un mismo producto entre varias personas.
- Si las subcategorias tendran un maximo de niveles o si se permitira jerarquia ilimitada.
- Si algunos productos necesitaran variantes, tamanos o modificadores ademas de categorias.
- Si se permitiran pagos mixtos en una misma venta.
- Si el cierre de caja requerira desglose por denominaciones de billetes y monedas en una version futura.
- Si los gastos operativos requeriran comprobante, foto o numero de recibo.
- Si los pagos al personal se manejaran como gasto simple o como modulo de nomina en una version futura.
- Si se manejaran impuestos, descuentos o propinas.
- Si el comprobante PDF debe cumplir requisitos fiscales oficiales.
- Si se necesitara impresion fisica de factura o ticket.
- Si se necesitara pantalla de cocina para productos marcados como enviar a cocina.
- Si los reportes se calcularan desde datos locales, Supabase o ambos.
- Si la sincronizacion debe ejecutarse en segundo plano con la app cerrada o solo con la app abierta.

## 11. Prioridad de desarrollo sugerida

1. Base del proyecto Flutter con arquitectura y localizacion.
2. Configuracion de Supabase y autenticacion Google.
3. Modelo local y remoto para productos, mesas y ventas.
4. Registro de categorias y subcategorias.
5. Registro de productos.
6. Registro de mesas.
7. Pantalla de facturacion con navegacion por catalogo.
8. Cuentas separadas por mesa.
9. Catalogo de metodos de pago.
10. Configuracion de empresa y numeracion.
11. Generacion de PDF para factura o comprobante.
12. Anulaciones auditables.
13. Apertura y cierre basico de caja por dia.
14. Catalogo de categorias de gastos.
15. Registro de gastos operativos.
16. Registro de ventas offline-first.
17. Sincronizacion automatica y manual.
18. Reportes de ventas, anulaciones, ganancias, gastos y caja.
19. Usuarios, roles y permisos.
20. Ajustes finales, pruebas y validacion.

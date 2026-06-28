este documento es para ir escribiendo las mejoras de forma generales, Codex debera de analizarlas, revisar el desarrollo y analizar como encaja la mejora en el sistema y proponer la mejor solucion para ser implementada, sin romper lo desarrollado.

**27-06-2026**
**Pantalla  division de cuentas**

1. toda el contenido de la pantalla debe ser responsivo y pensado para una tableta de 10.36 pulgadas.
2. en la card principal , la de la factura o mesa original ahi hay 3 botones confirmar, cancelar y mas, esos 3 botones deben ser de un color diferente y que convine con la paleta de colores y el boton de mas actualmente no tiene ni icono ni letras, asi que hay ponerle algun texto o signo de mas.
3. se debe mejorar el flujo de separacion de cuentas, de modo que el usuario pueda seleccionar mas de un item de la mesa original y poderlos pasar a las cuentas hijas , y se tiene que ver que el usuario va seleccionando los registros para ayuda visual.
4. El flujo en la separacion de cuentas debe ser mas flexible, actualmente solo se puede pasar de la mesa original hacia las cuentas hijas, pero debe existir la posibilidad de pasar items tanto de la mesa original como entre las hijas o de las hijas a las original.
5. cuando se escribe algo en el campo de Nombre de CUENTA se pone de un  color casi transpaten la etiqueta que dice  Nombre de CUENTA, y hace que se vea muy poco, asi que debes aplicarle color de modo que se pueda apreciar bien.


**28-06-2026**
**POS**

realizar lo siguiente:

1. revisar que pasa actualmente si se deja una caja abierta y al dia siguiente el usuario se logea o abre nuevamente el pos, Debemos revisarlo, por que actualmente lo que sucede es que esta pidiendo apertura nuevamente y eso esta pecimo, si una caja se deja abierta al dia siguiente debe mostrar mensaje de que la caja quedo abierta y debe obligar a cerrar ese dia caso contrario no puede aperturar el dia. Eso debe ser una regla de negocio la cual debes implementar y documentar.

2. EN el pos agregar una nueva columna en la parte donde se agrega el detalle de la orden la nueva columna debe ser el PRECIO del producto agregado.

3. El campo total que suma la columna de Monto, debes alinearla a la columna de MONTO, la alineacion debe ser a la derecha.

4. el boton de eliminar fila debe ser una columna mas ,asi que hay que ponerle nombre a la columna, el nombre debe ser "Remover". y debe ser alineado al centro. Y debe existir una separacion entre la columna de Monto y la columna de Remover, una separacion sana para que no quede muy pegada a como esta actualmente.

5. EN la fila donde esta el campo que suma la columna de monto, a la izquierda se debe agregar un boton que diga "Ocultar Productos" , "Mostrar Productos" la idea con esta opcion es que si la orden esta bastante cargada y el mesero necesita mas bisibilidad para apreciar mejor el detalle, pueda ocultar la seccion o fila donde estan los productos y poder ver mejor, y si desea restaurar entonces vuelva a precionar Mostrar Productos. 
6. a la cabezera de la lista de detalle hay que ponerle color de background segun la paleta de colores ya definida.

7. en la lista de productos agregados a una orden hay que agregar un estado que indique si ya fue servido o no. Para eso debes agregar o extender la tabla por que ese campo debe ser persistido, la columna se debe llamar "Servido" y debe ser de tipo booleano tipo checkbox o radio butoon pero que sea elegante super premium, o tambien puede ser un togle hay vos deterniminas que puede ser mejor, la ubicacion de la  nueva columna agregala estrategicamente.

8. Si te fijas en las columnas del detalle no estan alineadas las columna, debes alinearlas todas , me refiero a la alineacion entre la cebezera y el contenido de las filas de detalles.
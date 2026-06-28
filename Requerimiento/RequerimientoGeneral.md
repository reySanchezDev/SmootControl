Este documento narra un requerimiento general para el desarrollo de una app en flutter dart para control de restaurantes.

Esta app tendra una primera version 

Que debe contemplar la version 1.0

1. Logearse con Google
2. grabar usuarios
3. manejerar roles y permisos
4. grabar mesas, sus campos deben ser minimos solo: Nombre
5. grabar productos ejemplo Hamburguesa, deben grabarse solo los campos minimos como : codigo, producto, costo, precio,enviar a cosina.
6. ver repoertes de ventas 

Debemos usar supabase para la basa de datos

la app debe funcionar offline first y debe tener un proceso que se encargue de estar sincronizando las ventas, mediantes un proceso automatoco el cual desde setting podra configurarse el tiempo de envio de las ventas el usuario podra configarlo para cada 5 o 20 0 30 minutos, el proceso de(job) debeb ser capaz de auto iniciarse en el caso de detectar internet y que tenga ventas sin sincronizar.

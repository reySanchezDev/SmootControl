# Checklist De Salida A Produccion

## Objetivo

Dejar SmooControl listo para operar en produccion con administracion online en
Supabase y POS offline-first en la tableta.

## Antes De Instalar El APK Final

- Confirmar que el APK release mantiene el mismo `applicationId`.
- Confirmar que se usa la misma firma release para futuras actualizaciones.
- Confirmar que las migraciones locales Drift son no destructivas.
- Confirmar que el proyecto Supabase de SmooControl tiene aplicadas las
  migraciones requeridas.
- Confirmar que el APK fue compilado con URL y anon key del proyecto Supabase
  correcto.
- Confirmar que el APK release contiene permiso de internet:
  `uses-permission: name='android.permission.INTERNET'`.
- Confirmar con `aapt dump permissions release\SmooControl-produccion.apk`
  antes de entregar el APK a la tableta.
- Revisar el incidente documentado en
  `Documentation/ANDROID_RELEASE_INTERNET_INCIDENT.md` si Android muestra
  `Failed to fetch` o no logra validar el administrador remoto mientras Web si
  funciona.

## Validacion Obligatoria Del APK Release

Ejecutar despues de construir el APK:

```powershell
$aapt = Get-ChildItem -Path "$env:LOCALAPPDATA\Android\Sdk\build-tools" `
  -Recurse -Filter aapt.exe |
  Sort-Object FullName -Descending |
  Select-Object -First 1

& $aapt.FullName dump permissions release\SmooControl-produccion.apk
& $aapt.FullName dump badging release\SmooControl-produccion.apk |
  Select-String -Pattern "package:"
```

Debe confirmarse:

- `android.permission.INTERNET` existe en el APK.
- `versionCode` aumento respecto al APK anterior.
- `applicationId` sigue siendo `com.smoocontrol.pos`.
- La pantalla de login/inicializacion muestra la marca visible del build
  esperado.

## Datos Minimos En Supabase

- Restaurante y configuracion general.
- Configuracion de numeracion de facturas.
- Roles, permisos y asignaciones.
- Usuarios administradores y usuarios POS con PIN.
- Categorias, subcategorias y productos activos.
- Grupos y opciones de modificadores.
- Disponibilidad inicial de modificadores.
- Mesas operativas.
- Metodos de pago.
- Tasa de cambio del dia.
- Categorias de gasto necesarias para el POS.

## Prueba En Tableta Limpia

1. Instalar el APK release.
2. Iniciar sesion con un usuario autorizado.
3. Ejecutar **Mas opciones > Sincronizar datos** desde el POS.
4. Confirmar que el dialogo indica que el POS esta listo para operar.
5. Abrir caja.
6. Crear una venta con productos y modificadores.
7. Cobrar en efectivo.
8. Verificar que la mesa se libera.
9. Verificar que la venta aparece en **Ver Transacciones**.
10. Confirmar que la venta sube a Supabase.
11. Confirmar que reportes administrativos muestran la venta sincronizada.

## Prueba Offline Obligatoria

1. Abrir caja con internet.
2. Desconectar internet de la tableta.
3. Crear y cobrar una venta.
4. Verificar que la mesa se libera.
5. Verificar que la venta aparece localmente en **Ver Transacciones**.
6. Reconectar internet.
7. Ejecutar sincronizacion si no sube automaticamente.
8. Confirmar que la venta aparece en Supabase.

## Prueba De Rescate Desde Remoto

1. Usar una instalacion limpia o base local vacia.
2. Iniciar sesion/restaurar contexto.
3. Ejecutar **Sincronizar datos**.
4. Confirmar que bajan usuarios POS, roles, permisos, configuracion, catalogo,
   mesas, tasas y metodos de pago.
5. Abrir caja y completar una venta de prueba.

## Reglas Para Actualizar APK

- No desinstalar la app si hay operaciones pendientes de sincronizar.
- Antes de actualizar, entrar a **Sincronizacion** y confirmar que no hay
  pendientes con error.
- Instalar el APK nuevo encima del anterior.
- No cambiar `applicationId`.
- No cambiar la firma release.
- No borrar la base local durante una actualizacion.

## Regla De Perdida De Dispositivo

Si se pierde o borra una tableta, Supabase permite reconstruir datos centrales:
configuracion, usuarios POS, roles, permisos, catalogos, modificadores, mesas,
metodos de pago, tasas y categorias de gasto.

No se recuperan ventas, gastos o movimientos de caja hechos offline que nunca
lograron sincronizar antes de perder o borrar la tableta.

## Criterio De Go-Live

La version puede salir a produccion cuando:

- el POS vende con internet;
- el POS vende sin internet;
- las ventas offline se conservan localmente;
- al volver internet, las ventas suben a Supabase;
- **Sincronizar datos** restaura la informacion minima para vender;
- reportes administrativos leen ventas sincronizadas desde Supabase;
- una actualizacion APK se instala encima sin perder datos.

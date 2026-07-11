# Checklist Release Candidate V1

## Objetivo

Validar un APK candidato antes de usarlo en capacitacion avanzada o produccion.
Este checklist asume que V1 mantiene POS y Admin en el mismo APK.

## Preflight Antes Del Build

Ejecutar:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\production_preflight.ps1
```

Debe cumplirse:

- `flutter analyze` sin issues.
- `flutter test` completo exitoso.
- `git status --short` revisado.
- Credenciales `SMOO_SUPABASE_URL`, `SMOO_SUPABASE_PUBLISHABLE_KEY` y
  `SMOO_RESTAURANT_ID` presentes en `Requerimiento/CredencialesSupabase.md`.
- `pubspec.yaml` tiene `versionCode` mayor que el ultimo APK entregado.

## Build Release

Construir solo con:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_android_release.ps1
```

No usar para APK entregable:

```powershell
flutter build apk --release
```

Ese comando directo no inyecta Supabase/restaurante y puede generar un APK que
abre, pero no permite inicializar dispositivo ni entrar como admin remoto.
Seguir siempre `Documentation/APK_RELEASE_BUILD_PROCEDURE.md`.

Salida esperada:

```text
release/SmooControl-produccion.apk
release/SmooControl-produccion.buildinfo.txt
```

## Validacion Del APK

```powershell
$aapt = Get-ChildItem -Path "$env:LOCALAPPDATA\Android\Sdk\build-tools" `
  -Recurse -Filter aapt.exe |
  Sort-Object FullName -Descending |
  Select-Object -First 1

& $aapt.FullName dump permissions release\SmooControl-produccion.apk
& $aapt.FullName dump badging release\SmooControl-produccion.apk |
  Select-String -Pattern "package:"
Get-Content release\SmooControl-produccion.buildinfo.txt
```

Debe confirmarse:

- existe `android.permission.INTERNET`;
- package/applicationId es `com.smoocontrol.pos`;
- `versionCode` aumento respecto al APK instalado;
- `versionName` coincide con `pubspec.yaml`;
- se esta usando la misma firma release.
- `buildinfo` confirma `InjectedDartDefines=SMOO_SUPABASE_URL,SMOO_SUPABASE_PUBLISHABLE_KEY,SMOO_RESTAURANT_ID`;
- `buildinfo` confirma `InternetPermission=PRESENTE`.
- `buildinfo` confirma `SqliteNativeLibrary=PRESENTE`.
- el APK contiene `libsqlite3.so`; si falta, no entregar porque Drift/SQLite
  puede fallar en Android.

## Prueba Manual En Tablet

### Instalacion Limpia

1. Instalar APK release en una tablet limpia o base local vacia.
2. Confirmar que aparece inicializacion de dispositivo.
3. Inicializar contra Supabase.
4. Iniciar sesion POS con usuario local/PIN restaurado.
5. Abrir caja.
6. Confirmar que hay categorias, productos, mesas, metodos de pago, tasa de
   cambio y tipos de venta.

### Venta Online

1. Con internet activo, agregar producto a una mesa.
2. Cobrar con Cordoba.
3. Confirmar que la mesa se libera.
4. Confirmar que la venta aparece en `Ver Transacciones`.
5. Confirmar que la venta aparece en Supabase/Admin Ventas.
6. Confirmar que el numero de factura remoto queda continuo.

### Venta Offline

1. Abrir caja con internet.
2. Desactivar internet.
3. Agregar producto y cobrar.
4. Cerrar y abrir la app.
5. Confirmar que la venta sigue en `Ver Transacciones` como pendiente/error.
6. Activar internet.
7. Ejecutar sincronizacion manual si no sube sola.
8. Confirmar venta en Supabase/Admin Ventas.

### Empaque Y Tipo De Venta

1. Crear o elegir producto con regla de empaque para `Para llevar`.
2. Cobrar `Para llevar` con empaque suficiente y confirmar descuento.
3. Repetir sin empaque suficiente y confirmar que la venta se bloquea.
4. Cambiar a `Comer aqui` y cobrar.
5. Confirmar que no se quema consecutivo por el intento fallido.

### Anulacion

1. Cobrar venta con producto que controla inventario.
2. Anular la venta desde Admin Ventas.
3. Confirmar estado anulada.
4. Confirmar reintegro de inventario/empaque cuando aplique.
5. Confirmar sincronizacion remota de la anulacion.

### Cambio Admin Y Sync POS

1. Desde Admin cambiar precio, producto, metodo de pago o mesa.
2. Desde POS ejecutar `Sincronizar datos`.
3. Confirmar que POS refleja el cambio.
4. Confirmar que valores local-only se conservan:
   - nombre temporal de mesa;
   - disponibilidad diaria de modificadores.

### Actualizacion Encima

1. En APK anterior, crear venta pendiente de sincronizar.
2. No desinstalar.
3. Instalar APK nuevo encima.
4. Abrir app y confirmar que caja, venta pendiente y cola sync sobreviven.
5. Sincronizar y confirmar que la venta sube una sola vez.

## Si Hay Ventas Pendientes

- No desinstalar la app.
- Entrar a `Sincronizacion` o `Ver Transacciones`.
- Revisar pendiente/error.
- Ejecutar sincronizacion manual.
- Si persiste error, tomar captura del error y conservar la tablet sin borrar
  datos hasta revisar la cola local.

## Si Falla Sincronizacion

- Confirmar internet.
- Confirmar que el dispositivo fue inicializado contra Supabase.
- Confirmar que existen credenciales de sync de dispositivo.
- Revisar ultimo error visible en la fila de cola sync.
- Reintentar despues de dos minutos si quedo `syncing`.
- No cerrar piloto ni limpiar datos hasta rescatar pendientes.

## Criterio De Listo Para Produccion

La version queda aprobada solo si:

- no hay P0 abiertos;
- P1 corregidos o aceptados explicitamente;
- `flutter analyze` y `flutter test` pasan;
- APK release pasa validacion `aapt`;
- instalacion limpia funciona;
- actualizacion encima no pierde datos;
- venta online y offline sincronizan correctamente;
- empaque, inventario, caja y anulacion se comportan segun regla de negocio.

# Incidente: APK Release Sin Permiso De Internet

## Resumen

El 1 de julio de 2026 se detecto que el APK release de SmooControl no podia
inicializar la tableta contra Supabase aunque el flujo Web si funcionaba. La
causa raiz fue que `android.permission.INTERNET` existia solo en los manifiestos
`debug` y `profile`, pero no en `android/app/src/main/AndroidManifest.xml`.

En Android, el APK release se construye desde el manifiesto `main`; por eso el
APK instalado en la tableta no tenia permiso real para abrir conexiones HTTPS.

## Sintomas

- Web release podia iniciar contra Supabase despues de resolver bloqueos de red.
- APK release mostraba error al validar administrador remoto.
- La pantalla de inicializacion llego a mostrar:
  `ClientException: Failed to fetch`
- El usuario, clave, perfil, rol y permiso remoto eran correctos en Supabase.
- Probar otra red no resolvia el problema en Android.

## Causa Raiz

`android/app/src/debug/AndroidManifest.xml` y
`android/app/src/profile/AndroidManifest.xml` tenian:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

pero `android/app/src/main/AndroidManifest.xml` no lo tenia.

Eso permitia que escenarios de desarrollo o Web confundieran el diagnostico,
pero el APK release quedaba sin permiso de internet.

## Correccion Aplicada

Se agrego el permiso en:

`android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    ...
</manifest>
```

El APK corregido fue verificado con `aapt`:

```powershell
$aapt = Get-ChildItem -Path "$env:LOCALAPPDATA\Android\Sdk\build-tools" `
  -Recurse -Filter aapt.exe |
  Sort-Object FullName -Descending |
  Select-Object -First 1

& $aapt.FullName dump permissions release\SmooControl-produccion.apk
```

Debe aparecer:

```text
uses-permission: name='android.permission.INTERNET'
```

## Regla Preventiva

Antes de entregar cualquier APK release para pruebas o produccion se debe
verificar:

1. `flutter analyze --no-pub` sin errores.
2. Tests criticos de autenticacion/sincronizacion pasan.
3. `aapt dump permissions` confirma `android.permission.INTERNET`.
4. `aapt dump badging` confirma `versionCode` nuevo.
5. La app instalada muestra la marca visible de build esperada.
6. La tableta inicializa contra Supabase usando datos moviles o una red sin
   bloqueo SSL/proxy.

## Leccion Aprendida

No basta con probar Web ni con revisar que Supabase responda desde la maquina de
desarrollo. Para Android release se debe inspeccionar el APK final, porque los
permisos pueden diferir entre `debug`, `profile` y `main`.

Este caso debe tratarse como bloqueo de go-live si vuelve a aparecer.

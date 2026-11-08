# FE-E7 — Inicio Web Backoffice sin aprovisionamiento POS

**Fecha:** 2026-11-08. **Estado:** cambio codificado en GitHub, **pendiente de ejecutar, compilar y revisar visualmente**.

## Evidencia visual del usuario

En `http://127.0.0.1:8092/` se mostró `Inicializar dispositivo`, solicitando correo administrador, clave remota y `Nombre del POS`. Esa pantalla es ajena a la experiencia Backoffice y no debe ser requisito para iniciar la administración.

## Causa comprobada en el código

- `AuthBloc._onSessionRequested` consulta `DeviceInitializationService.getStartupMode` cuando no hay sesión local.
- Con Supabase configurado y restaurante configurado, si el navegador todavía no tiene usuario local con PIN, `getStartupMode()` devuelve `remoteInitialization`.
- `AuthGate` convierte `AuthDeviceInitializationRequired` en `DeviceInitializationPage`. Por eso un navegador nuevo obliga a aprovisionar un POS, incluso para administrar remotamente.

## Corrección aislada

Se introduce modo explícito `SMOO_APP_MODE=backoffice`, sin cambiar el modo predeterminado `standard` usado para POS.

- En modo Backoffice, `AuthBloc` inicia sin sesión local y muestra login remoto; no consulta restauración POS ni solicita nombre de terminal.
- `LoginPage` presenta únicamente credenciales de administrador remoto y envía `AuthRemoteAdminSignInRequested`. El servicio Supabase sigue validando usuario, rol y permisos.
- `AuthGate` y `AppRouteExperience` rechazan sesiones POS y acceso a rutas POS en ese modo.
- El aprovisionamiento POS permanece intacto para `SMOO_APP_MODE=standard`, y el modo de marcador `time_clock` permanece intacto.

## Validación Codex

### Ejecución Codex 2026-11-08

- Rama sincronizada: `fix/backoffice-web-auth-startup` en `828623f21730772d884693ccc1555d71acff3a80`; 17 stashes preservados y worktrees ajenos intactos.
- Se detuvo únicamente el servidor anterior de `127.0.0.1:8092` y se levantó Flutter Web en modo desarrollo con `SMOO_APP_MODE=backoffice` y configuración sintética local inyectada en memoria. No se usó el script de release.
- Supabase local: API `127.0.0.1:54321`, PostgreSQL `127.0.0.1:54324`, 87 migraciones. No se ejecutaron CRUD ni escrituras de prueba.
- Recursos Web `/`, `/flutter_bootstrap.js`, `/main.dart.js`, `/drift_worker.js` y `/sqlite3.wasm`: HTTP 200. El HTML no contiene el mensaje de Supabase no configurado ni textos de aprovisionamiento POS.
- Pruebas: AuthBloc 2/2, inicialización de dispositivo 5/5, rutas 3/3, workspace 4/4 y sidebar 3/3. Se conserva el comportamiento `standard` de inicialización POS y se rechazan rutas cruzadas POS/Backoffice en las pruebas.
- No hay navegador controlable disponible en esta sesión: no se certifican visualmente el formulario inicial, login remoto real, carga de Productos ni cierre de sesión. El propietario debe abrir `http://127.0.0.1:8092/` y autenticar con el administrador sintético del laboratorio.
- `flutter analyze --no-pub` se ejecutó con límite controlado: quedó en `Analyzing SmooControl-backoffice-web-auth-startup...` durante 15 segundos, sin diagnósticos ni código de salida; el árbol propio del analysis server fue detenido selectivamente. No se declara aprobado.

1. Sincronizar `fix/backoffice-web-auth-startup`, confirmar los 17 stashes y archivos locales preservados.
2. Confirmar que `http://127.0.0.1:8092/` sirve el SHA anterior y detener **solo** ese servidor si es necesario para recompilar; no tocar ningún otro preview.
3. Verificar que Supabase local sigue en `127.0.0.1:54321/54324`, 87 migraciones y URL/clave/restaurante sintéticos locales.
4. Recompilar exclusivamente Web con `--dart-define=SMOO_APP_MODE=backoffice`, sin utilizar `tool/build_web_release.ps1` ni credenciales compartidas/productivas. Comprobar que el JavaScript resultante corresponde al nuevo SHA.
5. Abrir navegador con origen nuevo o perfil de prueba temporal; comprobar que el primer acceso ya **no** pide inicializar POS, PIN local ni `Nombre del POS`.
6. Login remoto con Auth sintético, Backoffice Executive Ivory y `Productos`; comprobar permisos y cierre de sesión. No guardar tokens/contraseñas en Git/logs.
7. Prueba negativa: sesión POS no debe entrar en Backoffice ni por deep link a POS. Prueba de regresión: modo `standard` **sí** conserva la inicialización del POS nuevo.
8. Ejecutar `dart format`, pruebas de auth/navegación/Backoffice y `flutter analyze` si concluye; registrar si analysis server sigue bloqueado.
9. Documentar evidencias y logs no sensibles; no simular QA visual final del usuario.
10. Sin modificaciones de SQL, Docker ajeno, Tentrix, `main` ni producción; no fusionar ni desplegar.

**Importante:** el cambio no está activo en el servidor 8092 hasta que Codex sirva el nuevo build con `SMOO_APP_MODE=backoffice`.  

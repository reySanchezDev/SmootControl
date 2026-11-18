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

### Diagnóstico del perfil remoto y corrección del laboratorio

- La cuenta Auth sintética admin está confirmada, activa y no bloqueada. `auth.users.id` coincide con `profiles.id`; el `role_id` apunta al rol `admin` y `is_active=true`.
- La causa exacta fue de configuración del preview: 8092 se inició con el restaurante fixture `Kivo Otro Restaurante`, mientras el admin sintético pertenece a `Kivo Laboratorio`. Por eso `_profileFor` filtraba por un restaurante distinto y devolvía cero filas aunque el JWT fuera válido.
- Con JWT del usuario y rol `authenticated`, la consulta equivalente a `_profileFor` por `restaurant_id + id` devuelve una fila; el fallback por `restaurant_id + email` también devuelve una fila. No se usó `service_role` para esas consultas.
- `current_restaurant_id()` respondió HTTP 200 y coincide con el restaurante del perfil. La política `profiles_self_or_same_restaurant` está presente; no se relajó RLS. Las migraciones 086 y 087 permanecen aplicadas.
- Se reinició únicamente el Web 8092 con `SMOO_APP_MODE=backoffice`, Supabase local y el restaurante sintético del administrador. No se modificaron perfiles, migraciones, producción ni otros servicios.
- Flujo Auth local: contraseña válida -> JWT HTTP 200 -> `/auth/v1/user` HTTP 200 -> `_profileFor` por ID/correo -> perfil admin visible bajo RLS. La validación visual completa en Flutter queda pendiente por falta de navegador controlable.

### Corrección de credenciales y texto Backoffice

- Supabase/Auth fueron inspeccionados únicamente en Docker local. La cuenta sintética admin existe, está confirmada, activa, no bloqueada, no es usuario POS y su perfil está asociado al restaurante sintético correcto.
- La causa operativa del rechazo era una contraseña sintética no válida/desconocida para la cuenta local. Se restableció exclusivamente esa cuenta mediante el endpoint administrativo local de Supabase; no se crearon duplicados ni se tocaron perfiles ajenos.
- El flujo local `POST /auth/v1/token?grant_type=password` respondió HTTP 200. También respondieron correctamente `/auth/v1/user` y la consulta RLS del perfil. No se registraron cuerpos, contraseñas ni tokens.
- Se corrigió `LoginPage` para que, solo en `SMOO_APP_MODE=backoffice`, el mensaje indique correo y contraseña remota. El texto y el flujo POS/PIN permanecen en `standard`.
- `dart format` se aplicó a `login_page.dart`. Pruebas: AuthBloc 2/2, inicialización de dispositivo 5/5 y navegación 3/3.
- El preview fue reiniciado únicamente en `127.0.0.1:8092` con `SMOO_APP_MODE=backoffice`; `/` responde HTTP 200 y los assets Web/Drift previamente verificados siguen disponibles.
- El archivo local de recuperación de la cuenta se encuentra fuera del repositorio, bajo `%LOCALAPPDATA%\SmooControl\kivo-lab-admin-*.txt`, con permisos restringidos al usuario actual. La contraseña no se incluyó en GitHub, logs ni chat.
- No hay navegador controlable en esta sesión: la autenticación completa mediante la UI, la pantalla observada y la carga de Productos no quedan certificadas visualmente.

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

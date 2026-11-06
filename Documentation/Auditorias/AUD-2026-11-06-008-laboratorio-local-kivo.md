# Auditoría: laboratorio local reproducible de Kivo

Fecha: 2026-11-06  
Repositorio: `reySanchezDev/SmootControl`  
Base auditada: `origin/main` — `def0e3af450d49411dfa617b03e50bc6f21e3147`  
Rama de este informe: `audit/kivo-local-lab`

## Resumen ejecutivo

Kivo puede reproducirse localmente usando la pila oficial de Supabase CLI,
PostgreSQL/Auth incluidos y los servicios Flutter existentes. La ejecución no
se realizó en esta auditoría: Docker Engine no estaba disponible y no se
ejecutó ninguna migración, `supabase start`, `db reset`, `db push` ni conexión a
producción.

El bloqueo inmediato es operativo: Docker Desktop y las distribuciones WSL2
relacionadas estaban detenidas. El segundo requisito pendiente es preparar
fixtures sintéticos: `supabase/seed.sql` configura permisos, roles y catálogos
base, pero no crea un restaurante, usuario Auth, perfil, productos, terminales
ni escenarios de ventas.

## Estado del entorno

| Componente | Evidencia observada | Evaluación |
|---|---|---|
| Docker CLI | 29.5.2, contexto `desktop-linux` | Instalado |
| Docker Engine | Error al conectar con `dockerDesktopLinuxEngine` | No disponible |
| Docker Compose | v5.1.3 | Instalado; requiere Engine |
| WSL2 | WSL 2 disponible; Ubuntu y `docker-desktop` detenidos | Requiere iniciar Docker Desktop |
| Supabase CLI | 2.90.0; hay actualización 3.0.0 disponible | Compatible para evaluar esta configuración |
| Flutter/Dart | Flutter 3.41.7; Dart 3.11.5 | Instalados |
| PostgreSQL client | `psql` no encontrado | No es bloqueante si se usa CLI/Studio; útil como herramienta opcional |
| Puertos TCP | No se observaron sockets en escucha en la consulta realizada | No se modificó ningún puerto |

Docker no permitió enumerar contenedores, volúmenes o redes porque el daemon no
estaba disponible. Esto no demuestra que no existan recursos; solo que no fue
posible inspeccionarlos sin iniciar Docker Desktop. No se eliminaron ni
modificaron recursos.

## Configuración Supabase encontrada

`supabase/config.toml` declara:

- proyecto local `smoo_control`;
- PostgreSQL en `54324`, shadow DB en `54325`, versión mayor 17;
- Studio en `54326`;
- seed habilitado con `./seed.sql`;
- Auth habilitado;
- `site_url` y redirects locales apuntando a `localhost:8080` y
  `127.0.0.1:8080`;
- Google OAuth referenciado mediante `GOOGLE_CLIENT_ID` y
  `GOOGLE_CLIENT_SECRET`, sin valores en el repositorio.

La aplicación inyecta en compilación `SMOO_SUPABASE_URL`,
`SMOO_SUPABASE_PUBLISHABLE_KEY` y `SMOO_RESTAURANT_ID`. Los servicios usan la
URL para REST, Auth y RPC. El script actual `tool/build_web_release.ps1`
requiere una URL `https://`, por lo que bloquea directamente una URL local
`http://127.0.0.1:<puerto>`; esto debe resolverse en una futura adaptación
aislada del flujo de laboratorio, sin relajar las validaciones de producción.

## Migraciones y compatibilidad de arranque limpio

Se encontraron 83 migraciones numeradas consecutivamente del `001` al `083`,
sin huecos ni duplicados. El conjunto cubre, entre otros:

- esquema operativo PostgreSQL, restaurantes, usuarios y permisos;
- Auth, perfiles y RLS;
- productos, recetas, unidades, inventario y empaques;
- ventas, tipos de venta, caja y gastos;
- personal, asistencia, vacaciones y planilla;
- auditoría, reportes, sincronización y terminales POS;
- RPCs `SECURITY DEFINER`, grants, policies e índices.

La revisión textual identificó uso de `pgcrypto` y de la extensión/esquema
`extensions`, además de referencias a `auth.users`. La pila oficial local de
Supabase es la opción correcta porque proporciona PostgreSQL, Auth y sus
esquemas auxiliares. No se detectaron dependencias declaradas a `pg_net`,
`vault`, `storage`, `realtime`, `dblink`, `postgres_fdw` o `cron`.

Hay sentencias `DELETE`/`TRUNCATE` dentro de funciones y rutinas de limpieza;
no se ejecutaron. Antes de un primer reset local debe revisarse su contexto y
separar claramente funciones de mantenimiento de sentencias ejecutadas durante
la migración. La migración que referencia `auth.users` debe probarse con Auth
local activo, no contra una base PostgreSQL desnuda.

## Seed actual y brecha de fixtures

`supabase/seed.sql` es idempotente y crea permisos, roles globales,
`role_permissions`, métodos de pago y categorías de gastos. No crea los datos
necesarios para un escenario completo:

- restaurante y configuración de negocio;
- usuario Auth local, perfil y rol administrativo asignado;
- unidades, categorías, productos y materias primas;
- tipos de venta y reglas de empaques;
- terminales/dispositivos POS y caja inicial;
- ventas, consumos, movimientos, sincronizaciones y reportes.

Por tanto, un `supabase start` seguido únicamente de ese seed no certificará el
login ni los flujos POS/Backoffice. Hace falta un fixture local separado,
versionado y explícitamente sintético; no se debe completar copiando datos de
producción.

## Dependencias de ejecución

```text
Supabase local PostgreSQL + Auth
        ├── REST / RPC / RLS ── Backoffice Web administrativo
        └── REST / RPC / sync ── POS Flutter
                                 └── Drift local/offline
```

- **PostgreSQL**: almacena el modelo, políticas, funciones y datos sintéticos.
- **Auth**: emite la sesión administrativa y debe existir antes de probar RLS.
- **RPC/RLS**: determinan permisos, sincronización e informes; no basta con
  probar consultas directas de PostgreSQL.
- **POS Flutter/Drift**: conserva la base local y las operaciones offline; su
  ruta de laboratorio debe usar un archivo Drift separado.
- **Backoffice Web**: debe apuntar al endpoint local y a un `restaurantId`
  sintético, en un puerto separado del preview actual.
- **Sincronización**: debe probarse con dos terminales sintéticas y claves de
  idempotencia independientes, sin reutilizar identificadores de producción.

## Procedimiento reproducible propuesto

Este procedimiento queda propuesto, no ejecutado:

1. Iniciar Docker Desktop con WSL2 y verificar `docker info`, contexto y
   disponibilidad de Compose.
2. Desde un worktree exclusivo de laboratorio ejecutar `supabase start` y
   registrar las URLs/puertos que devuelva `supabase status`.
3. Crear un entorno local de variables fuera de Git con una URL local, la clave
   publicable generada por el stack local y un UUID de restaurante sintético.
   Nunca reutilizar `SMOO_CREDENTIALS_PATH` de producción ni sus valores.
4. Revisar las 83 migraciones y ejecutar, solo después de aprobación,
   `supabase db reset` en ese proyecto local. No usar `db push` ni comandos
   `--remote`.
5. Cargar fixtures sintéticos en orden: restaurante/configuración, usuario Auth
   y perfil, roles/permisos, catálogos, productos y empaques, terminales, caja,
   ventas y escenarios de sincronización. Usar UUIDs, fechas y nombres de
   laboratorio fijos.
6. Ejecutar POS con un archivo Drift de laboratorio y dos terminales sintéticas;
   ejercitar venta offline, consumo de empaque, caja, reintento e idempotencia.
7. Ejecutar Backoffice Web con defines locales y un puerto de laboratorio
   distinto de `8080`/`8081`; validar login, RLS, reportes y navegación.
8. Verificar que los errores de Auth, RLS, RPC y sync se observan como fallos,
   sin escribir datos reales. Registrar resultados y limpiar solo el laboratorio
   cuando el propietario lo autorice.

Para Web hay una incompatibilidad concreta que resolver antes de automatizar el
paso 7: `build_web_release.ps1` solo acepta HTTPS, mientras que Supabase local
normalmente entrega HTTP. La alternativa segura es un wrapper o parámetro
exclusivo de laboratorio que acepte la URL local y mantenga la validación HTTPS
para releases; no debe editarse durante esta auditoría.

## Riesgos y requisitos pendientes

1. Docker Desktop/Engine debe estar iniciado; hasta entonces no hay validación
   de compatibilidad efectiva ni inventario de recursos Docker.
2. Debe definirse el fixture sintético y su contrato de IDs. El seed existente
   no es una base funcional completa.
3. Debe definirse una configuración de redirects Auth local separada de la de
   producción.
4. Debe separarse el almacenamiento Drift y los puertos del laboratorio de los
   previews actuales.
5. Debe revisarse el contexto de rutinas de mantenimiento con `DELETE`/
   `TRUNCATE` antes del primer reset local.
6. `psql` no está instalado; puede instalarse como herramienta de diagnóstico,
   aunque no es imprescindible para el flujo oficial.
7. El repositorio fija en `AGENTS.md` la revisión 0.1.5 de los estándares. La
   solicitud menciona 0.1.7, pero no se encontró evidencia local de esa revisión;
   no se declara adoptada ni se modifica la política en este cambio.

## Conclusión

La arquitectura oficial de Supabase CLI es viable para reproducir Kivo sin
crear una arquitectura Docker paralela. El laboratorio aún no está listo para
arrancar: falta disponibilidad del Engine y un conjunto de datos sintéticos
completo, y el script Web requiere una ruta local específica. No se clonó
producción, no se descargaron datos reales, no se ejecutaron migraciones y no
se tocaron los servicios ni puertos existentes.

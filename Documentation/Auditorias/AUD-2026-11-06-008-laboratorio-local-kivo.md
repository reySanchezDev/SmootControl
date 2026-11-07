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

## Ejecución de puesta en marcha — resultado verificable

En una segunda revisión se inició Docker Desktop. El Engine quedó disponible
con cliente/servidor Docker `29.5.2`. El inventario previo a Supabase mostró:

- `tentrix_minio` y `tentrix_postgres`, pertenecientes a otro proyecto;
- volúmenes `tentrix_minio_data` y `tentrix_postgres_data`;
- redes estándar y `tentrix_default`;
- ningún contenedor Supabase;
- ningún conflicto observado en los puertos configurados de Supabase.

Se creó exclusivamente la red `smoo-kivo-lab` para el laboratorio y se invocó
la CLI oficial con `supabase start --network-id smoo-kivo-lab`. La CLI comenzó a
descargar la pila, pero terminó con:

```text
unable to get image 'public.ecr.aws/supabase/storage-api:v1.48.28':
request returned 500 Internal Server Error for API route
```

La CLI retiró sus recursos temporales incompletos (`Pruned containers: []`,
`Pruned network: []`); no eliminó ni modificó `tentrix_*`. La prueba de descarga
de `hello-world` tampoco alcanzó una respuesta concluyente y quedó bloqueada en
el cliente Docker, por lo que no se puede atribuir el fallo a una migración o a
una imagen concreta con certeza.

Resultado de migraciones: **0/83 aplicadas**. No se creó una base Supabase
operativa, no se ejecutó el seed y no se realizaron consultas de verificación.
El laboratorio no debe considerarse listo.

### Bloqueo pendiente

Revisar Docker Desktop/WSL2 y la conectividad al registro `public.ecr.aws`
(proxy, DNS, autenticación o estado del backend), y repetir primero una prueba
de descarga aislada. Después de obtener todas las imágenes, deberá repetirse
`supabase start` y recién entonces validar las 83 migraciones y el seed. No es
necesario modificar código, migraciones ni producción para resolver este
bloqueo.

## Seguimiento de conectividad y descargas

Se repitió el diagnóstico con la rama sincronizada y el mismo worktree. Windows
resolvió `public.ecr.aws`, `registry-1.docker.io` y `auth.docker.io`; las
respuestas HTTPS fueron las esperadas (`401` de los endpoints de registry y
`405` en el token consultado por `HEAD`). No había variables de proxy de
Windows ni proxy WinHTTP configurado.

`docker info` confirmó Docker `29.5.2` y un proxy interno de Docker Desktop. El
reinicio oficial mediante `docker desktop restart` corrigió la falla inicial:

- `docker pull hello-world`: **éxito**, digest
  `sha256:c567b231f65614688711a75f31518a064258a51d442117a3e771a3a8fdba78ef`;
- `docker pull public.ecr.aws/supabase/storage-api:v1.48.28`: **éxito**, digest
  `sha256:38850bce7c3056ef76acdc4c6357aa474b3124b22d383ed86843b765a1efe242`.

Al intentar la pila completa, la mayoría de imágenes auxiliares descargó, pero
PostgreSQL y Studio quedaron en transferencia durante varios minutos. El log de
Docker Desktop registró una capa de CloudFront de 337,581,343 bytes en
8m01s y conexiones ECR con aproximadamente 30s por respuesta. Esto evidencia
conectividad funcional pero una transferencia inestable o extremadamente lenta
de capas grandes; no se obtuvo un error de migración ni de PostgreSQL.

Se reintentó el núcleo oficial excluyendo temporalmente `realtime`, `vector`,
`edge-runtime`, `imgproxy` y `logflare`. La CLI siguió esperando las imágenes
`public.ecr.aws/supabase/postgres:17.6.1.106` y Studio. El pull directo de
PostgreSQL tampoco terminó durante la ventana de diagnóstico y fue cancelado de
forma controlada. No se usó `system prune`, no se borraron imágenes, volúmenes,
contenedores ni redes.

Resultado actualizado: **0/83 migraciones**, Supabase no iniciado, seed no
ejecutado y PostgreSQL/Auth/REST/Studio aún no verificables. La causa residual
es la lentitud/estancamiento de la transferencia de capas grandes desde el
registro/CDN a través del proxy interno de Docker Desktop; el reinicio resolvió
el HTTP 500 inicial, pero no completó la descarga de la pila.

### Cierre de la comprobación de descarga

La rama `audit/kivo-local-lab` se verificó nuevamente en el commit
`0b0fdcb2a7eca7d08075d69168141de1b20f344f`, sin cambios locales y conservando
los 17 stashes. El espacio libre observado en `C:` fue de aproximadamente
6.44 GB. No se capturó un error explícito `ENOSPC`, pero este margen es
insuficiente para considerar segura otra descarga completa de la pila.

Las opciones de Supabase CLI 2.90.0 confirmaron `--network-id` y
`--exclude`; `supabase db --help` confirmó los comandos locales y remotos, sin
ejecutar operaciones remotas.

Se reintentó `public.ecr.aws/supabase/postgres:17.6.1.106` con supervisión y se
canceló después de permanecer sin avance observable. La imagen no se consideró
descargada. El intento de pila mínima con exclusiones compatibles también quedó
detenido esperando PostgreSQL y Studio. No se iniciaron contenedores Supabase,
por lo que las migraciones siguen en **0/83**, el seed no se ejecutó y no hay
resultados locales de Auth, REST/RPC o PostgreSQL que certificar.

Como comprobación independiente del PR #9 se preparó un worktree separado,
`SmooControl-packaging-e2e-lab`, desde
`origin/feature/packaging-e2e-rule-consumption`, sin modificar su rama. Se
identificaron como pruebas pertinentes las de repositorio y servicio de
inventario; no existen pruebas con nombre específico de Empaques en esa rama.
`flutter pub get` completó, pero `flutter analyze` no produjo salida final
dentro de la ventana de ejecución y fue cancelado de forma controlada; por ello
no se declara éxito ni regresión en las pruebas Flutter del PR.

No se aplicaron cambios de proxy, firewall, TLS, imágenes, volúmenes,
contenedores ni redes ajenas. La corrección comprobada fue el reinicio oficial
de Docker Desktop, que eliminó el HTTP 500 inicial para las descargas pequeñas
pero no resolvió la transferencia de las capas grandes.

### Puesta en marcha posterior

Se verificaron las unidades locales: `C:` quedó con aproximadamente 8.95 GB
libres al inicio de esta pasada y `D:` no tenía espacio disponible. Docker
Desktop usa `C:\Users\reyre\AppData\Local\Docker\wsl\disk\docker_data.vhdx`,
un VHDX dinámico con capacidad virtual de 1 TB y tamaño físico aproximado de
10.87 GB. Dentro del entorno Linux de Docker, el volumen de sistema informó
aproximadamente 947 GB disponibles. Los volúmenes de Tentrix continuaron
intactos: PostgreSQL ocupaba aproximadamente 64.9 MB y MinIO 104 KB.

No se trasladó el disco Docker: `D:` no es una ubicación viable y no existe
otra unidad local con espacio adecuado verificado. No se sobrescribió ningún
VHDX ni se modificaron contenedores o volúmenes de Tentrix.

El reintento supervisado de `public.ecr.aws/supabase/postgres:17.6.1.106`
terminó correctamente con digest
`sha256:21ab971149317ea9cd12a8126fe4ebb34def08c8972956b0958cba0924409dab`.
El consumo de imágenes pasó a aproximadamente 8.57 GB y quedaron 8.29 GB
libres en `C:`.

Se inició el laboratorio con la CLI 2.90.0 usando las exclusiones compatibles
`realtime,storage-api,imgproxy,mailpit,studio,edge-runtime,logflare,vector,supavisor`.
Las migraciones **001–083 (83/83)** se aplicaron y el seed terminó. La consulta
local verificó 83 registros de migración, 55 tablas públicas, 56 políticas RLS
y 99 funciones públicas. Las filas sintéticas/base del seed incluyeron 3 roles,
9 métodos de pago y 8 categorías de gastos.

PostgreSQL quedó saludable en el contenedor local; REST respondió HTTP 200 en
`/rest/v1/` y Auth respondió HTTP 200 en `/auth/v1/health`. El catálogo de RPC
quedó presente, sin ejecutar RPC mutantes ni escrituras de negocio. Studio se
excluyó deliberadamente.

La red `smoo-kivo-lab-loopback` se creó con la opción oficial
`com.docker.network.bridge.host_binding_ipv4=127.0.0.1`, pero la CLI 2.90.0
reutilizó bindings explícitos `0.0.0.0` para Kong y PostgreSQL. La salida de
Docker confirmó `0.0.0.0:54321` y `0.0.0.0:54324`; por tanto el laboratorio
funciona, pero no se certifica todavía el aislamiento de red requerido. No se
habilitó ni deshabilitó el firewall global ni se aplicaron cambios de seguridad.
La intervención pendiente es habilitar una política de firewall local que
bloquee esos dos puertos desde redes externas, o usar una configuración de
Docker Desktop aprobada por el propietario; debe hacerse sin afectar Tentrix.

### Auditoría de aislamiento y fixtures pendientes

La configuración de `smoo-kivo-lab-loopback` contiene correctamente
`com.docker.network.bridge.host_binding_ipv4=127.0.0.1`. Sin embargo, Docker
Desktop 29.5.2 y Supabase CLI 2.90.0 crearon los bindings de Kong y PostgreSQL
con `HostIp=""`; Docker documenta que esa forma publica en todas las
interfaces. La CLI no expone en `supabase start` una opción de host-IP por
servicio y cambiar una opción global de Docker afectaría otros proyectos.
Referencias: https://docs.docker.com/engine/network/port-publishing/ y
https://supabase.com/docs/guides/local-development.

Se comprobó el comportamiento real: `127.0.0.1:54321` y `127.0.0.1:54324`
responden, pero también aceptan conexiones TCP hacia direcciones IPv4 no
loopback del host. `docker inspect`, `docker ps` y `netstat` muestran
`0.0.0.0:54321` y `0.0.0.0:54324`, incluyendo escucha IPv6 `::`. Los perfiles
de Windows Defender Firewall están deshabilitados. No se creó una regla que no
tendría efecto y no se habilitó el firewall global; la verificación desde otra
máquina física queda pendiente, aunque la exposición local no loopback ya
demuestra que el aislamiento no está garantizado.

La corrección segura pendiente requiere una de estas intervenciones aisladas:
recrear únicamente los contenedores del laboratorio con publish explícito
`127.0.0.1:54321:8000` y `127.0.0.1:54324:5432`, o habilitar una política de
Windows Defender Firewall limitada a esos puertos y perfiles activos. No se
debe modificar la configuración global de Docker ni Tentrix sin una decisión
explícita. Los datos del laboratorio están en volúmenes Supabase y no se
ejecutó reset.

Se preparó la propuesta de fixtures, sin cargarla:

1. Restaurante sintético con UUID generado por la base y un administrador Auth
   creado exclusivamente en el laboratorio; el perfil y rol se relacionan por
   las claves generadas por el sistema.
2. Catálogos mínimos: dos categorías, productos vendibles y materias primas,
   unidades, reglas de receta y dos empaques con movimientos de inventario.
3. Dos terminales sintéticas registradas por el flujo de aprovisionamiento,
   nunca con IDs escritos manualmente por el usuario.
4. Escenarios de venta: venta directa, venta con empaque, anulación/reintento
   e idempotencia entre terminales, usando fechas y UUIDs generados en el
   fixture.
5. Casos de RLS: administrador permitido, usuario de otro restaurante
   rechazado y terminal sin permiso de escritura.

La propuesta respeta ENG-008 y UX-041: los identificadores internos, claves de
relación y números operativos deben ser generados por la base o por los
servicios del laboratorio; los formularios no reciben IDs manuales. No se
realizaron escrituras de fixtures en esta fase.

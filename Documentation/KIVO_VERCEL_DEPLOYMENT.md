# Kivo by Quantix — publicación Web (Vercel)

## Alcance y seguridad

Producto comercial **Kivo**. Proyecto fuente Flutter: `SmootControl`/SmooControl.
No renombrar `applicationId` Android (`com.smoocontrol.pos`), tablas, almacenamiento,
IDs, keys, permisos, rutas, servicios ni backend durante el rebranding. El dominio
preferido del Backoffice es `kivo.quantix.software`; `quantix.software` y
`www.quantix.software` deben seguir vinculados al proyecto corporativo original.

**Nunca** usar el proyecto Vercel de la web corporativa para desplegar Kivo.
No cambiar el DNS raíz, `www`, ni usar `--force` al asociar dominios.

## Proceso recomendado

1. Desde un worktree limpio de `release/kivo-web-branding`, comprobar `flutter analyze`
   y pruebas focalizadas de login, rutas, POS y Backoffice. Verificar si el icono o
   material gráfico requiere una revisión de marca adicional antes de la publicación.
2. Inyectar los tres valores públicos/configurables de Supabase desde el archivo
   local ignorado usando `SMOO_CREDENTIALS_PATH`, sin copiarlo al repositorio:
   `SMOO_SUPABASE_URL`, `SMOO_SUPABASE_PUBLISHABLE_KEY`,
   `SMOO_RESTAURANT_ID`. **Jamás** inyectar una clave service-role/secret.
3. Ejecutar `powershell -ExecutionPolicy Bypass -File .\tool\prepare_kivo_vercel.ps1`
   para generar `build/web` por el script oficial, copiar `drift_worker.js` y
   `sqlite3.wasm`, y preparar el sitio estático en `release/kivo-vercel`.
4. Autenticarse en Vercel si fuera necesario (`vercel login`). Vincular SOLO
   `release/kivo-vercel` a un **proyecto nuevo Kivo**, separado del proyecto
   corporativo (`vercel link --cwd release/kivo-vercel`).
5. Ejecutar `vercel deploy --cwd release/kivo-vercel` para obtener un preview
   temporal. Validar en navegador remoto: login admin desde almacenamiento vacío,
   acceso a Backoffice, sesión, rutas de recarga, CORS/HTTPS, guardas y lectura de
   datos autorizados, sin escribir ni alterar registros reales.
6. Tras comprobar el preview y su proyecto, ejecutar
   `vercel deploy --prod --cwd release/kivo-vercel`. Registrar URL y deployment ID.
7. En el proyecto **Kivo** de Vercel, agregar `kivo.quantix.software` en
   Settings > Domains. Inspeccionar las instrucciones DNS actuales y crear
   exclusivamente el registro requerido para **kivo**, en el DNS autorizado.
   No asumir ni inventar destino CNAME: usar el valor indicado por Vercel.
8. Comprobar HTTPS, certificado, estado Ready y que `/`, `flutter_bootstrap.js`,
   `main.dart.js`, `drift_worker.js` y `sqlite3.wasm` sirvan los tipos correctos
   (no devolver HTML para JS/Wasm). Probar apertura con enlace directo y recarga.
9. Confirmar que `www.quantix.software` sigue respondiendo igual que antes.

## Rollback

Mantener registrado el deployment previo de Kivo. Si aparece un defecto, promover
el último deployment sano del **proyecto Kivo exclusivamente**; no tocar el
deployment ni los dominios de Quantix corporativo. El versionado Git y los
builds de Android son independientes.

## Nota de naming

Kivo es nombre elegido por el propietario. El uso público/comercial debe ir
acompañado de una comprobación de marcas y riesgos de confusión por país.
Este documento no acredita exclusividad del signo.

# Runbook — Backoffice web en dominio propio

**Estado:** PLANTILLA OPERATIVA. No ejecutar DNS, despliegue o cambios de credenciales sin autorización y parámetros reales.

## A. Datos pendientes que debe confirmar el propietario

| Parámetro | Valor |
|---|---|
| Dominio comprado / FQDN exacto | PENDIENTE |
| Registrador del dominio | PENDIENTE |
| Proveedor que administra DNS | PENDIENTE |
| Hosting o plataforma elegida | PENDIENTE |
| Cuenta/proyecto de staging | PENDIENTE |
| Cuenta/proyecto de producción | PENDIENTE |
| Ubicación/region de hosting | PENDIENTE |
| FQDN staging | PENDIENTE |
| FQDN Backoffice final | PENDIENTE |
| DNS preexistente: A/AAAA/CNAME/MX/TXT/CAA | PENDIENTE |
| Entorno backend y URL auth | PENDIENTE |
| Orígenes/CORS y redirect URLs permitidas | PENDIENTE |
| Responsable de TLS, renovación y backups | PENDIENTE |
| Política de subdominios/apex/www | PENDIENTE |

No asumir que el dominio final deba ser `backoffice.<dominio>`; proponerlo como opción, validar coexistencia con web corporativa y correo.

## B. Arquitectura de publicación

1. Seleccionar hosting de **archivos estáticos + routing SPA**, HTTPS automático y política de cabeceras/cache configurables.
2. Determinar si existen rutas de navegador reales; documentar fallback a `index.html` para rutas del Backoffice.
3. Confirmar que los archivos del release Flutter incluyen assets y recursos Drift; prohibir despliegues parciales.
4. Separar configuraciones y recursos de staging frente a producción (backend, tenant de prueba y credenciales).
5. Verificar ausencia de claves secretas privilegiadas, tokens y datos de cliente en bundle y logs.
6. Definir política de rollback de artefacto y configuración independiente de DNS.

## C. Construcción controlada

**Referencia existente:** `tool/build_web_release.ps1`.

- Preparar toolchain Flutter/Dart compatible con repo y dependencias bloqueadas.
- Configurar exclusivamente `SMOO_SUPABASE_URL`, `SMOO_SUPABASE_PUBLISHABLE_KEY`, `SMOO_RESTAURANT_ID` con valores de ambiente autorizado.
- Validar el alcance multi-restaurante; no adoptar un `SMOO_RESTAURANT_ID` fijo para clientes múltiples sin revisar el modelo de tenancy.
- Correr script y conservar log **sin secretos**.
- Inspeccionar `build/web`: bootstrap, JS/WASM, `sqlite3.wasm`, `drift_worker.js`, manifest/assets y fuentes.
- Confirmar HTTP 200, tipos MIME correctos, consola limpia y web worker operativo.
- No publicar `Requerimiento/CredencialesSupabase.md`, archivos de configuración privada ni sourcemaps que contengan datos sensibles.

## D. Staging / preproducción (obligatoria)

1. Crear sitio staging aislado con URL HTTPS, sin redirigir tráfico real.
2. Configurar registros DNS **exactos proporcionados por hosting**.
3. Aprovisionar certificado TLS válido; verificar renovación.
4. Configurar servidor: HTTPS, redirección HTTP→HTTPS, política de seguridad, routing SPA, caché para HTML/bootstrap/archivos versionados y tipos MIME WASM.
5. Configurar orígenes permitidos y redirecciones del proveedor de identidad; nunca desactivar CORS/controles para corregir errores.
6. Validar autenticación, logout, recarga de página, links, pestañas, reportes, listados, worker Drift y conectividad del backend.
7. Validar permisos desde endpoints y aislamiento de restaurante/tenant en staging.
8. Probar dispositivos y resoluciones relevantes. Capturar evidencias para la matriz de aceptación.
9. Validar rendimiento, errores de consola, accesibilidad y respaldo/restauración.
10. Registrar versión, commit SHA, fecha de build y URL staging.

## E. Decisión GO/NO-GO

La publicación queda **BLOQUEADA** si hay hallazgos críticos de auth, datos cruzados, pérdida de datos, firma/versión errónea, falla de worker, certificado TLS inválido, fallos de login, o falta de recuperación del release anterior.

Requisitos para GO: checklist completado, propietario aprueba, backup disponible, release reproducible, rollback ensayado, DNS y certificado validados.

## F. Publicación en dominio final

1. Congelar el commit/tag y artefacto probado de staging; registrar checksums.
2. Documentar estado DNS existente antes de tocarlo; respetar MX/SPF/DKIM/DMARC.
3. Reducir TTL **solo cuando sea necesario y autorizado**.
4. Publicar artefacto en hosting productivo sin sustituir credenciales de staging inadvertidamente.
5. Conectar dominio con los registros oficiales del proveedor y activar TLS.
6. Confirmar URL canónica, redirecciones, login, sesión, permisos, consola, navegación SPA, assets Drift y backend.
7. Monitorizar fallas cliente/API y disponibilidad; no incorporar pruebas destructivas sobre datos reales.
8. Registrar acta de despliegue y entregar enlace definitivo con responsable.

## G. Reversión

**Disparadores:** pérdida de acceso, fuga de datos, error de autorización/tenant, problemas graves de persistencia, errores de workers, incompatibilidad POS, degradación crítica.

1. Declarar incidente y congelar cambios.
2. Restaurar release anterior mediante mecanismo del hosting; no reconstruir una versión distinta durante el incidente.
3. Revertir DNS solo si el incidente es de DNS/hosting y existen registros anteriores verificados.
4. Revertir configuración de auth/orígenes de forma controlada si fue modificada.
5. Verificar login, navegación, TLS, API, recursos y ausencia de corrupción. **No restaurar ni borrar bases productivas como operación rutinaria de rollback de frontend.**
6. Registrar causa raíz, tiempos, responsables, impacto y plan correctivo.

## H. Operación posterior

- Monitoreo de uptime, errores, latencia, seguridad y caducidad del certificado.
- Gestión de versiones, compatibilidad con APK POS, soporte y ventanas de mantenimiento.
- Verificación de renovaciones de dominio, backups y acceso administrativo.
- Procedimiento de actualización del Backoffice sin interferir con la venta offline.

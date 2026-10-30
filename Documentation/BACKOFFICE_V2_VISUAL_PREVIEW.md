# Vista previa visual del Backoffice V2

## Alcance
Ruta aislada: `/backoffice-v2-preview`. Disponible únicamente tras autenticación y validación de permiso `configuracion.gestionar` (o rol administrador según RouteAccessGuard). Aplica también `AdminOnlineGuard`.

La ruta utiliza datos ficticios, nunca enlaza páginas administrativas reales, y no escribe ni consulta tablas del restaurante. No altera el POS ni reemplaza la navegación principal. El control visual de pestañas permite alternar módulos ilustrativos y preservar la búsqueda de cada pestaña abierta.

## Desplegar en local sin reemplazar web actual
En `develop/backoffice-v2`, ejecutar análisis y pruebas. Utilizar el script oficial `tool/build_web_release.ps1` para construir `build/web`; el servidor existente de puerto 8080, si está apuntando a ese mismo directorio, **no debe tratarse como aislado**. Antes de construir V2, hacer una copia segura del build actual fuera de `build/web` y detener o reorientar el servidor anterior si hace falta. La mejor opción es tener dos árboles de trabajo Git separados (worktrees) con builds independientes, uno para `main` y otro para V2, y servir cada `build/web` en 8080 y 8081 respectivamente.

En el worktree V2 ejecutar:
```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_web_release.ps1
Start-Process python -ArgumentList '-m http.server 8081 --bind 127.0.0.1' -WorkingDirectory '.\build\web' -WindowStyle Hidden
```
Verificar `http://127.0.0.1:8081/`, iniciar sesión como un usuario autorizado y abrir `http://127.0.0.1:8081/#/backoffice-v2-preview` según el comportamiento real de enrutado Flutter Web. Si el navegador no resuelve la ruta por hash, navegar a la ruta con `Navigator.pushNamed(context, AppRoutes.backofficePreview)` desde un entorno de test autorizado y reportar el bloqueo; no debilitar autenticación ni permisos.

## Límites y pendientes
- La página representa un catálogo de interacción, no la integración con módulos reales.
- Permisos de listado: los destinos ilustrativos no equivalen a acceso concedido a sus rutas operativas.
- No se han agregado persistencia de pestañas entre recargas, restauración de borradores ni confirmación automática de cambios no guardados.
- No hay cambio de diseño en POS ni cambios a Supabase.
- Confirmar el acceso por enlace profundo y la renderización en navegador antes de avanzar a la migración de pantallas.

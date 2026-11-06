# CONTEXTO_PROYECTO — SmooControl / Kivo

> Documento de continuidad para nuevas conversaciones y agentes. Actualizado: 2026-11-05 (America/Managua).
> No incluir credenciales, tokens, datos de clientes ni secretos: este repositorio es público.
> Este documento **no sustituye** el código, `Documentation/`, los tests ni la comprobación del entorno real.

## Identidad y alcance
- **SmooControl**: nombre del repositorio y base técnica.
- **Kivo**: nombre comercial aprobado para la solución; el cambio de marca visual no implica renombrar identificadores técnicos.
- Mantener `com.smoocontrol.pos`, rutas, autenticación y base de datos salvo una decisión explícita y un plan probado de migración.
- Destino de Backoffice Web: https://kivo.quantix.software (proyecto Vercel `kivo`).
- POS: operación táctil Android, local/offline, persistencia Drift/SQLite y sincronización diferida.
- Backoffice Web: administración remota conectada a Supabase. **No** inicializar ni descargar la base POS en el navegador. La adaptación a PC táctil es posterior.

## Arquitectura y referencias
- Flutter/Dart, organización por features y capas, BLoC, diseño centralizado y localización ES/EN.
- Referencias normativas: [README.md](README.md), [arquitectura](Documentation/ARCHITECTURE.md), [índice documental](Documentation/README.md), [rules.md](rules.md).
- Paleta actual `Ivory Premium` según `Documentation/ARCHITECTURE.md`; coherente con la preferencia UX «Executive Ivory».
- La documentación histórica puede estar desactualizada. Comprobar ramas, código, migraciones y pruebas antes de afirmar que una función está implementada.

## Decisiones de UX registradas
- Backoffice pensado como aplicación web de escritorio profesional, no como una pantalla móvil estirada.
- Centralizar ThemeData/ColorScheme, tipografía, botones y espaciados; evitar colores hardcodeados en cada pantalla.
- Navegación con pestañas de trabajo; preservar estado al cambiar de pestaña, con controles claros para cerrarlas.
- Sidebar contraíble, con control visible en el borde, sin solapar contenido; verificar resoluciones de escritorio.
- Listados legibles, compactos, con filtros y acciones explícitas. Encabezados fijos cuando el área de datos hace scroll.
- **Regla UX explícita:** no ocultar acciones ordinarias detrás de «... Más» como patrón por defecto. Asegurar que la persona identifique claramente qué puede hacer y a qué registro afecta cada acción.
- Para acciones sobre registros, evaluar selección + botonera contextual visible, estados habilitado/deshabilitado y confirmaciones apropiadas; no eliminar capacidades existentes.
- Aplicar criterios de usabilidad de forma consistente entre Productos y los demás módulos administrativos.

## Producción y controles
- Última publicación reportada por conversación (no es un chequeo actual de Vercel):
  - deployment `dpl_8gLvhQxeFfWkf46KjrqqJx7NJJY2`
  - target `production`, estado reportado `READY`
  - https://kivo.quantix.software
- **Pendiente de comprobar en operación real:** login administrativo completo.
- Proteger los flujos existentes de ventas, caja y sincronización. Verificar por separado la aplicación efectiva de migraciones Supabase.
- Compilaciones entregables Android solo con los scripts aprobados descritos en el README, no con un build genérico sin configuración.

## Favicon Kivo — diseño aprobado (2026-11-05)
- **Aprobación expresa recibida:** usar únicamente el gorro de chef minimalista de línea blanca, fondo café oscuro y acento dorado. No usar monogramas K ni iconografía gastronómica adicional.
- **Alcance autorizado:** actualizar exclusivamente el favicon y lugares que referencian el icono del sitio; no tocar flujos, estilos, título, configuración funcional ni otros elementos.
- Referencia aprobada del usuario: imagen final de gorro de chef blanco sobre fondo café y acento naranja/dorado en esta conversación. La imagen original generada se conserva en el chat; no asumir que GitHub contiene el raster original.
- **Implementado en rama `main` de GitHub:** `web/icons/kivo-chef.svg`, referencia `rel=icon` en `web/index.html`, icono de acceso directo y dos usos en `web/manifest.json` (normal y maskable). Los archivos PNG preexistentes de Flutter permanecen intactos y no se usan en esas referencias.
- **Limitación pendiente:** los dispositivos iOS pueden no aceptar SVG para `apple-touch-icon`; preparar/subir PNG de 180 o 192 antes de declarar compatibilidad total. Comprobar favicon real a 16×16.
- **Producción pendiente:** el deployment Vercel verificado `dpl_8gLvhQxeFfWkf46KjrqqJx7NJJY2` tiene `source=cli`; los commits en GitHub por sí solos **no prueban** que el sitio publicado se haya actualizado. Requiere reconstruir/publicar los archivos Flutter Web actualizados y validar en `https://kivo.quantix.software`.
- No se autoriza cambiar otra cosa durante esta tarea.


## Auditorías técnicas permanentes (2026-11-06)
- Índice maestro: [Documentation/Auditorias/README.md](Documentation/Auditorias/README.md).
- Primera auditoría: [AUD-2026-11-06-001 — maestro unificado de artículos](Documentation/Auditorias/AUD-2026-11-06-001-maestro-articulos.md).
- Segunda auditoría: [AUD-2026-11-06-002 — dependencias y plan reversible](Documentation/Auditorias/AUD-2026-11-06-002-dependencias-y-migracion-articulos.md). Rama revisada: `develop/backoffice-stabilization-integration`, árbol `7ce5163e0c6e698397dca0f57689966a4b714649`.
- Resultado: dirección funcional favorable a consolidar artículos físicos y servicios en un maestro; empaques actuales tienen kardex, reglas, stock y sync propios. Modificadores y tipos de venta no deben confundirse con productos físicos.
- Estado: solo documentación; **sin cambios de aplicación, migraciones ni datos**. Identificadas dependencias POS/Drift/RPC/sync/recetas y estrategia reversible; la verificación integral de referencias, esquema y datos reales continúa pendiente. No autorizar migración.
- Política: registrar futuras auditorías con ID, evidencia, rama, alcance, límites y decisiones. Reutilizar auditorías anteriores y revisar deltas entre commits, no repetir inspecciones sin causa.


## Decisión de limpieza del piloto — 2026-11-06
- El restaurante utiliza Kivo en una fase piloto y el usuario **autorizó conceptualmente conservar los catálogos y limpiar únicamente las operaciones**, NO ejecutar la limpieza ahora.
- **Preservar:** productos, categorías, precios, costos configurados, recetas/componentes, empaques, reglas de empaque, modificadores, tipos de venta y configuración de identidad/seguridad (restaurante, usuarios, roles, permisos, dispositivos, según análisis de dependencias).
- **Candidatos a limpieza:** ventas y líneas, anulaciones, cobros, sesiones de caja, gastos operativos de prueba, movimientos y documentos operativos, logs de sincronización y colas pendientes, sujeto a auditoría de FKs y ciclos de vida. No borrar registros fiscales/legales que deban conservarse.
- **Existencias:** aún sin decisión final; propuesta de conteo físico y ajuste a saldo inicial confiable, sin borrar definición de artículo ni costo. No equiparar limpieza de movimientos con eliminación automática de saldo.
- **Punto crítico:** coordinar el reinicio de Supabase y todos los POS offline para impedir reenvío de operaciones viejas. Crear respaldo restaurable, identificar todos los dispositivos, verificar colas, migraciones, referencias y reconstrucción de saldos; usar utilidades modulares existentes sólo tras auditarlas.
- **Estado:** decisión funcional documentada; NO se ejecutaron comandos SQL, resets, cambios de código ni despliegues. Próxima fase: especificación y simulación de limpieza solo de operaciones, con lista de preservación y rollback antes de solicitar autorización de ejecución.


## Corrección de alcance — nueva versión estable tras piloto (2026-11-06)
- **Decisión explícita posterior del usuario; prevalece sobre la nota anterior:** el inventario y las existencias del piloto están desactualizados y NO interesa conservarlos, reconciliarlos, contarlos ni hacer ajustes para recuperarlos. El piloto fue para probar el sistema y familiarizar al personal.
- **Conservar únicamente maestros de negocio útiles:** productos y categorías, precios configurados, recetas, empaques, modificadores, tipos de venta y sus reglas; preservar configuraciones técnicas/identidades que sean imprescindibles para seguridad y continuidad, validando sus dependencias.
- **Descartar operativa piloto:** saldos de inventario, movimientos de inventario, ventas de prueba, anulaciones, cobros, caja y demás registros operativos de prueba sujetos a evaluación de retención obligatoria y dependencias técnicas. El inventario de la nueva versión arrancará limpio; definir el proceso de carga inicial cuando llegue el inicio real, sin invertir esfuerzo ahora en conciliar stock viejo.
- **Meta prioritaria:** nueva versión comercial estable, segura y bien estructurada con catálogo maestro de artículos, empaques y modificadores correctamente modelados, POS offline robusto, sincronización idempotente y contratos SQL seguros.
- **Orden:** diseñar/implementar y probar nueva arquitectura; luego reinicio controlado de operaciones con coordinación de los POS para impedir que reenvíen datos antiguos. Respaldos técnicos preventivos permitidos, sin comprometer a recuperar inventario viejo.
- **Estado:** solo decisión/documentación. No hay autorización para borrar datos, migrar esquema ni publicar cambios.

## Cómo continuar en un chat nuevo
1. Leer este archivo y los documentos de arquitectura/reglas citados.
2. Consultar la rama activa y los commits más recientes; no asumir que `main` contiene todo el desarrollo V2.
3. Preguntar por el objetivo actual **solo si no está dado en el chat** y retomar primero cualquier tarea bloqueada por aprobación.
4. Contrastar el estado narrado con código, CI y producción; etiquetar cualquier dato no verificado.
5. Tras una decisión importante o un hito técnico verificado, actualizar este documento para conservar la continuidad.

## Historial mínimo de continuidad
- 2026-11-05: Kivo adoptado como nombre comercial; se reportó Backoffice Web publicado en Vercel.
- 2026-11-05: se acordó **mostrar y aprobar el favicon antes de cualquier cambio al sitio**.
- 2026-11-05: se crea este archivo de continuidad para reducir pérdida de contexto entre chats.

## Límites
- Un documento en GitHub conserva **decisiones técnicas registradas**, no recupera automáticamente todos los mensajes ni archivos de conversaciones anteriores.
- Nunca afirmar que una rama fue integrada, que un login funciona o que una publicación está validada sin evidencia actual.

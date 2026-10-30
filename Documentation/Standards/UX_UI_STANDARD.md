# UX/UI — Estándar universal Quantix

**Versión:** 0.1.0. **Estado:** reglas recopiladas del propietario, con interpretaciones puntuales pendientes de ratificación.
**Principio:** software comprensible para usuarios no técnicos, productividad, coherencia visual y funcional, sin duplicar información.

## A. Vistas de registros

| ID | Regla |
|---|---|
| UX-001 | Evitar títulos/textos repetidos: si la pestaña identifica la página, no repetir su título en contenido. |
| UX-002 | Paginación coherente: distinguir tamaño de página (p. ej. 25 filas), página actual, rango visible y total. El tamaño no cambia al navegar; evitar controles redundantes. |
| UX-003 | Todas las columnas de **datos** deben permitir ordenación ascendente/descendente por tipo; Acciones no se ordena. |
| UX-004 | Encabezados diferenciados visualmente, fijos en desplazamiento vertical y exactamente alineados con sus celdas. |
| UX-005 | Texto alineado a la izquierda; importes, cantidades y porcentajes a la derecha; estados, fechas/horas y acciones al centro. Encabezado y dato coinciden; formatos financieros consistentes. |
| UX-006 | Botonera de acciones principales arriba a la derecha. |
| UX-007 | Etiquetas contextualizadas y breves: dentro de Productos, `Nuevo`, no `Nuevo producto`. |
| UX-008 | Iconos claros, premium y consistentes; añadir texto visible cuando el icono no comunica su función a usuarios no técnicos. |
| UX-009 | Filtros agrupados arriba, precisos y basados en el dominio real. |
| UX-010 | Selectores de listas extensas (p. ej. categorías) con búsqueda y navegación fáciles. |
| UX-011 | Buscador con espacio suficiente que abarque columnas de datos pertinentes y realmente disponibles; normalizar formatos cuando proceda. |

## B. Creación y edición

| ID | Regla |
|---|---|
| UX-012 | Botonera de acciones arriba. |
| UX-013 | Campos agrupados por contexto y secuencia lógica de trabajo. |
| UX-014 | Enter avanza el foco de forma predecible sin guardar por accidente, respetando entradas multilínea y accesibilidad. |
| UX-015 | Confirmación clara del resultado de edición/guardado, distinta de solicitar autorización previa. |
| UX-016 | Formularios amplios y adaptados al dispositivo; no diálogos minúsculos con desplazamiento excesivo. |

## C. Navegación y estructura

| ID | Regla |
|---|---|
| UX-017 | Multipestaña con varias páginas abiertas y estado de trabajo conservado. |
| UX-018 | La pestaña Inicio es cerrable; nunca forzarla anclada. |
| UX-019 | Inicio, si existe, muestra métricas auténticas, concisas y autorizadas por rol y por controles de acceso a los datos. |
| UX-020 | Sidebar contraíble y accesible. |
| UX-021 | Menú ordenado por dependencia funcional: primero catálogos/datos maestros, después operaciones/movimientos derivados. |
| UX-022 | Agrupación estratégica por módulos; informes dentro de Reportes. |
| UX-023 | Iconografía profesional y reconocible; salida de sesión inequívoca. |
| UX-024 | No repetir marca/encabezado del sistema en sidebar y workspace sin propósito. |
| UX-025 | Detectar cambios pendientes y confirmar antes de cerrar/abandonar/descartar; cambiar de pestaña sin cerrar no exige confirmación. Guardados fallidos conservan datos. |

## D. Mensajes y diálogos

| ID | Regla |
|---|---|
| UX-026 | Mensajes importantes en ventana personalizada del sistema, no alertas improvisadas. |
| UX-027 | Botones adecuados a la acción: Aceptar, Confirmar, Cancelar, Seguir editando, Descartar, Eliminar. |
| UX-028 | No usar `OK` si existe etiqueta más clara. |
| UX-029 | Mensajes breves y comprensibles, sin lenguaje técnico innecesario. |
| UX-030 | Diferenciar riesgos y operaciones destructivas; no interrumpir innecesariamente. |
| UX-031 | Diálogo centralizado reutilizable, con tipos explícitos y comportamiento coherente. |

## E. Campos, legibilidad y consistencia

| ID | Regla |
|---|---|
| UX-032 | Campos obligatorios marcados previamente junto a etiqueta; requisitos condicionales actualizados, validación por campo y foco al primer inválido, además de la validación de servidor. |
| UX-033 | Desplegables legibles, dimensionados y con búsqueda si la lista es extensa. |
| UX-034 | Prohibido ocultar contenido relevante por truncamiento (`Nombre...`); ampliar, ajustar líneas o permitir navegación adecuada. Excepciones explícitamente aprobadas. |
| UX-035 | Responsividad funcional y legible en móvil, tableta, escritorio y escalado de texto; sin overflow ni controles inaccesibles. |
| UX-036 | Contraseñas, PIN y secretos enmascarados inicialmente, con revelado controlado; tampoco exponerlos en registros, URLs o mensajes. |
| UX-037 | Misma acción, mismo patrón visual y funcional mediante tokens/componentes compartidos; evitar duplicaciones. |

## Criterios pendientes de precisar
- **UX-015:** distinguir confirmación previa obligatoria de aviso tras éxito; no agregar ventanas extra sin ratificación.
- **UX-011:** «todas las columnas» se refiere a datos disponibles, no acciones ni consultas que el sistema no realiza; documentar alcance por módulo.
- **UX-034:** excepciones de truncamiento requieren lectura completa accesible y aprobación explícita.
- El orden concreto de módulos de restaurante pertenece a las reglas del producto, no a la norma universal.

Ninguna regla justifica inventar campos, capacidades o datos.

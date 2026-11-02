# Contratos de componentes UX/UI

Estos contratos describen comportamientos exigidos sin imponer un framework ni duplicar implementaciones.

## Tablas y listados
- Encabezado siempre fijo, alineado y claramente separado de los registros.
- Ordenación ascendente/descendente de columnas de datos; acciones sin ordenación.
- Alineación semántica: texto izquierda, finanzas/números derecha, estados y acciones centro.
- Columnas y registros accesibles incluso en pantallas estrechas; no truncar datos relevantes.
- Paginación con tamaño de página constante, rango y total exactos; filtros actualizan rango y página.
- **UX-038 — Pie de paginación compartido:** a la izquierda «Registros por página» y selector; a la derecha rango visible/total, página actual/total y Anterior/Siguiente. Conservar posiciones, orden, etiquetas, espaciados y estilos entre todas las páginas equivalentes. En móvil los grupos pueden apilarse sin alterar su orden lógico ni ocultar información.
- **UX-038 — Plantilla de página compartida:** títulos (cuando correspondan), acción primaria en esquina superior derecha y filtros/búsqueda en una posición estable; mismas zonas, márgenes y jerarquía entre módulos equivalentes. No crear encabezados o footers exclusivos por pantalla si existe componente compartido.
- **UX-040 — Acciones siempre identificables:** cualquier comando disponible expone icono opcional **y etiqueta textual visible y precisa**, sin usar «Más», puntos suspensivos, «Opciones» o iconos aislados como contenedores de operaciones. La disponibilidad respeta selección, estado y permisos. No ocultar acciones detrás de menús genéricos ni del hover exclusivamente. En pantallas estrechas, reordenar o apilar controles visibles, sin truncarlos. Para flujos de muchas operaciones, presentar agrupaciones claramente tituladas, conservando todas las etiquetas y el orden consistente.
- Preservar filtros, desplazamiento y estado cuando se alternan pestañas abiertas.

## Filtros y búsqueda
- Atributos reales del dominio, no filtros inventados o equivalencias incorrectas.
- Búsqueda en columnas pertinentes que realmente estén cargadas.
- Listas grandes y categorías jerárquicas con búsqueda utilizable.
- Evitar filtros redundantes y limpiar todos los filtros de forma coherente.

## Formularios
- Acciones arriba; campos agrupados lógicamente.
- Enter/foco acorde al tipo de control; requeridos marcados, errores contextualizados.
- Protección de cambios pendientes al cerrar/abandonar, sin bloquear alternar pestañas.

## Diálogos
- Variantes compartidas: informativo, error, éxito, advertencia, confirmación y destructivo.
- Botones claros, accesibilidad y decisión retornada inequívocamente.

## Diseño
- Tokens centrales: colores, fuentes, tamaños, espacios, densidad, iconos y estados.
- Consistencia y responsividad verificable sin overflow.
- **UX-039 — Contraste efectivo:** definir pares semánticos `foreground/background` por tema; no usar colores de texto fijos independientes del fondo ni opacidad decorativa sobre información esencial. En imágenes, transparencias y gradientes medir el contraste donde el texto realmente se dibuja (la zona más desfavorable). Cumplir WCAG 2.2 AA: 4.5:1 texto normal, 3:1 texto grande y, según aplique, 3:1 para límites/indicadores de controles y gráficos significativos. Estados hover, focus, selected, disabled (tratamiento y excepciones WCAG), light/dark y temas temporales deben verificarse sin perder legibilidad.

## Pruebas
- 0, 1 y muchas filas; cabecera fija, ordenación, paginación y filtros combinados.
- **UX-038:** comparar Productos y Categorías con igual viewport y comprobar misma alineación del pie, encabezado, acción principal y filtros; validar apilamiento sin desbordes en móvil.
- Formularios modificados, cierre, fallo de guardado y alternancia entre pestañas.
- Teclado, lectura asistida, distintas resoluciones y escalado de texto.
- **UX-039:** comprobar todas las cadenas visibles en ES/EN, CTA, hero, subtítulos, botones y pies en resoluciones y temas diferentes. Usar una medición de contraste reproducible sobre colores CSS reales (también con overlays), además de revisión visual y regresión tras cambios de paleta.
- **UX-040:** inspeccionar tablas y formularios con 0/1/2/3+ acciones, estado activo/inactivo, permisos diferentes, teclado y tamaños de viewport; comprobar que ninguna acción disponible quede oculta tras un control genérico y que las etiquetas sigan visibles.

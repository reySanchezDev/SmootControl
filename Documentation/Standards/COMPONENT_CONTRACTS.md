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

## Pruebas
- 0, 1 y muchas filas; cabecera fija, ordenación, paginación y filtros combinados.
- **UX-038:** comparar Productos y Categorías con igual viewport y comprobar misma alineación del pie, encabezado, acción principal y filtros; validar apilamiento sin desbordes en móvil.
- Formularios modificados, cierre, fallo de guardado y alternancia entre pestañas.
- Teclado, lectura asistida, distintas resoluciones y escalado de texto.

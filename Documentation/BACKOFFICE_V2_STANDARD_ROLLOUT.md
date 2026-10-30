# Backoffice V2 — Adopción de Quantix Engineering Standards

**Rama:** `develop/backoffice-v2`  
**Norma de referencia:** `reySanchezDev/QuantixEngineeringStandar`, v0.1.0, revisión
`a026ededa9f3c98f3ab493cc76b695af71e23df3`.  
**Estado:** implementación transversal parcial; pendiente de validación ejecutada con Flutter y QA visual de todos los módulos. No equivale a certificación UX completa.

## Trabajo integrado en la rama

### Base compartida — impacto transversal

- `AGENTS.md` con referencia fija y copia accesible de normas en `Documentation/Standards/`.
- `BackofficeWorkspace`: menú compacto responsivo, múltiples pestañas, Inicio cerrable, marca no duplicada, cierre de sesión único en shell.
- `BackofficeSidebar`: etiquetas multilínea legibles, expansión/contracción, artista de borde extraído para respetar <=300 líneas.
- `BackofficeWorkspaceDrawer`: módulos agrupados en dispositivos estrechos.
- `BackofficeWorkspaceScope` + `AppPageScaffold`: evitar encabezado duplicado de páginas dentro del workspace y preservar acciones arriba a la derecha.
- `BackofficeDataTable`: alineación por tipo configurable; encabezados fijos y celdas de altura variable para mostrar información completa.
- `AppInput`: marcador requerido, error contextual, foco y avance con teclado; secreto enmascarado según parámetro existente.
- `AppButton` y `AppEmptyState`: evitar reducción excesiva del texto y truncamiento.
- `AppMessageDialog`: mensaje y confirmación personalizados, reutilizables, con acciones destructivas diferenciadas.

### Navegación real

- Catálogos arriba: Productos, Categorías, Recetas, Unidades, Modificadores, Métodos de pago, Mesas, Empaques.
- Resumen (Inicio cerrable), Operaciones, Personal, Reportes y Administración.
- Visibilidad basada en los permisos existentes de `RouteAccess`, guardas existentes al abrir la página; sin nuevas autorizaciones implícitas.
- No se han inventado módulos ni métricas.

### Productos — adaptación de referencia

- Título duplicado eliminado; acción `Nuevo` arriba a la derecha y accesible aun con catálogo vacío.
- Búsqueda ampliada, selector de categorías con búsqueda, filtros de dominio, ordenación de columnas de datos, paginación comprensible.
- Importes alineados a la derecha; datos con ajuste de línea, etiquetas semánticas y colores del tema.
- Formulario de tamaño adaptable, acciones superiores, requeridos marcados, foco al primer campo inválido.
- Detección de cambios sin guardar, confirmación para descartarlos y confirmación previa de edición.
- Aviso de guardado tras el éxito del BLoC, usando diálogo compartido; textos clave localizados ES/EN.
- Archivos Dart manuales afectados divididos para quedar por debajo de 300 líneas.

## Segunda pasada — propagación por módulos (30/10/2026)

La primera pasada sólo había renovado Productos. La inspección visual detectó
que Categorías y Recetas seguían usando listas antiguas. En esta segunda
pasada se agregó `BackofficeCollectionView<T>`, con búsquedas, ordenación
semántica por columna, paginación uniforme, encabezados fijos, alineación y
tarjetas móviles; sin duplicar tablas por módulo.

**Módulos adaptados en código**:
- Categorías: tabla con nombre, tipo, padre, posición, estado y acciones;
  conserva árbol jerárquico en móvil.
- Recetas: tabla con búsqueda, paginación y edición, sin inventar alta directa.
- Unidades: búsqueda, factor, costo no aplicable, estado, edición y
  confirmación de inactivación.
- Mesas: tabla con estados y operaciones claras.
- Métodos de pago: tabla con moneda, grupo y operaciones; conserva reglas de
  negocio y vista jerárquica compacta.
- Modificadores: grupos y opciones editables; vista expandible móvil.
- Gastos: tabla de categorías, cobertura, jerarquía y acciones.
- Inventario: existencias de productos y empaques con unidades, costos y fecha.
- Movimientos: tabla con documentos, fecha, tipo, líneas y neto.
- Empaques: estructura superior adaptada al scaffold; **sus tres listas
  internas aún requieren migración a tablas**.
- Todos los módulos que usan `AppPageScaffold`: acciones superiores ahora
  admiten múltiples líneas para impedir overflow.

**No certificar cumplimiento total:** Ventas, Caja, Personal, Marcadas,
Vacaciones, Planilla, Reportes y Administración (roles, usuarios, ajustes,
auditoría), así como formularios internos y diálogos del resto de módulos,
todavía necesitan auditoría visual y adaptación individual al estándar.

La comprobación UX-034 y los tests no sustituyen QA visual; las capturas
anteriores corresponden a una compilación local **anterior** a esta pasada.
No actualizar servidores locales mediante el repositorio remoto de manera
automática; sincronizar y reconstruir después de CI exitoso y aprobación QA.

## Verificación automatizada preparada

- `tool/verify_backoffice_v2_ux.ps1` comprueba límite de 300 líneas en Dart modificado, regenera l10n, ejecuta `flutter analyze`, pruebas de diseño y `flutter build web --release`.
- Workflow de GitHub Actions `.github/workflows/backoffice-v2-ux-quality.yml`, disparado en PR contra `main` o manualmente.
- Pruebas añadidas para confirmaciones, campos requeridos, Inicio cerrable y Drawer móvil.

**Importante:** la comprobación real se ejecuta mediante GitHub Actions. Los avisos introducidos por estos cambios deben corregirse. El validador conserva una lista explícita de cuatro hallazgos preexistentes fuera del alcance UX (autenticación, gastos, ventas, mantenimiento); estos no equivalen a una aprobación de análisis global con cero avisos. Los errores de compilación y nuevos avisos sí bloquean CI. El navegador y QA manual requieren validación aparte.

## Brechas aún abiertas — NO CERTIFICADAS

1. Revisar individualmente los formularios de Categorías, Recetas, Inventario, Movimientos, Ventas, Caja, Gastos, Personal, Marcadas, Vacaciones, Planilla, Reportes y Administración. El uso del scaffold común no garantiza cumplimiento completo de UX-001..037.
2. Migrar mensajes críticos de los demás módulos al diálogo compartido y conectar detección de formularios modificados a sus cierres.
3. Convertir la página Inicio en un resumen de métricas **reales** con fuentes y autorizaciones verificables; hoy es principalmente navegación a módulos. Nunca inventar cifras.
4. Validar de punta a punta pantallas móviles y escritorio, escalado de texto, teclado, navegación, múltiples idiomas, accesibilidad, filtros, formularios y permisos.
5. Inspeccionar reglas de más de 300 líneas en archivos preexistentes no modificados y resolver de manera gradual, sin refactorización masiva ciega.
6. Ejecutar QA de módulos con datos reales de prueba y verificar resultados de análisis/compilación antes de merge.

## Procedimiento de validación local

```powershell
git switch develop/backoffice-v2
git pull --ff-only
pwsh ./tool/verify_backoffice_v2_ux.ps1
```

Después, realizar recorrido de negocio con perfiles de acceso distintos y vistas
390×844, 768×1024, 1366×768, 1920×1080, más zoom de texto.
Registrar errores con módulo, captura, pasos, resultado esperado y real.

**Política:** no realizar merge a `main` ni despliegue de producción sin QA aprobado. Conservar modificaciones locales ajenas del usuario.

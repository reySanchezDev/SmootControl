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

## Verificación automatizada preparada

- `tool/verify_backoffice_v2_ux.ps1` comprueba límite de 300 líneas en Dart modificado, regenera l10n, ejecuta `flutter analyze`, pruebas de diseño y `flutter build web --release`.
- Workflow de GitHub Actions `.github/workflows/backoffice-v2-ux-quality.yml`, disparado en PR contra `main` o manualmente.
- Pruebas añadidas para confirmaciones, campos requeridos, Inicio cerrable y Drawer móvil.

**Importante:** ninguna de estas verificaciones se considera aprobada hasta disponer de salida real de Flutter/CI. El entorno que realizó los cambios no tiene el SDK Dart/Flutter y no ejecutó pruebas ni navegador.

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

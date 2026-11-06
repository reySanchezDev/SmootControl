# Orden de ejecución Codex — Reorganización de Empaques end-to-end

**Fecha:** 2026-11-06. **Rama de trabajo ya creada:** `feature/packaging-e2e-rule-consumption` desde `develop/backoffice-stabilization-integration`. **No tocar main ni Supabase productivo.** **Estado actual:** primer cambio en motor local + tests añadidos por ChatGPT; **no ejecutados**. Continuar desde el HEAD de la rama (no revertir ni duplicar trabajo sin revisar).

## Instrucción operativa para Codex
Trabajá end-to-end con prioridad de integridad y diseño de Kivo, siguiendo `AGENTS.md` del proyecto, `CONTEXTO_PROYECTO.md`, la [AUD-007](../Auditorias/AUD-2026-11-06-007-integracion-reorganizacion-empaques.md), [FE-E0](../Auditorias/FasesEmpaques/FE-E0-2026-11-06.md), arquitectura [omnichannel V1](../Diseno/KIVO_ARQUITECTURA_FUNCIONAL_OMNICANAL_V1.md) y las reglas universales `QuantixEngineeringStandar` **v0.1.6 (ENG-008/UX-041)**. Lee los archivos exactos de esas reglas; si no están accesibles de forma versionada, detener modificaciones que puedan infringirlas hasta obtenerlos.

**Prioridad de validación:** primero ejecutar `dart format`, `flutter analyze`, `flutter test` relevantes, verificar si la regla lógica nueva activa `dine_in` existentes y enumerar ese impacto. NO afirmar cobertura total por ejecutar solo pruebas aisladas. Separar código UI, motor, schema y sync en commits revisables. No ocultar acciones genéricas; Executive Ivory; UX aprobado.

### Módulo objetivo de UI
Eliminar el acoplamiento funcional de la pantalla `/packaging` sin borrar la ruta de inmediato:
- **Configuración → Modalidades de servicio:** `sales_types` (nombre, código comercial estable si se usa, activo, orden, default legacy); código interno/UUID invisible y generado por sistema. Preparar futura jerarquía terminal N:M, no implementarla aquí sin gates G-NUM/G-CON.
- **Centro de Artículos → Empaques:** listado de `packaging_items` como proyección del maestro, sin fusionar ni migrar tablas; costo, tracks_stock, estado y compras/stock. IDs históricos inmutables.
- **Ficha Producto → Empaque y consumo:** reglas `product_packaging_rules` del producto, seleccionando modalidad, empaque, cantidad por unidad. Permitir administración transversal cuando convenga, no dos fuentes de verdad.
- Mantener `/packaging` como alias protegido/redirect y feature flag hasta pasar smoke de rutas y permisos; no dejar los tres catálogos en una página engañosa.
- No mostrar IDs internos; códigos comerciales visibles solo si hay motivo y comportamiento de edición claro. **No confundir `code` con UUID.**

### Seguridad y datos críticos
- Separar permisos: `tipos_venta.gestionar` no puede dar escritura sobre empaques/reglas ni viceversa. Rutas/acciones/backend deben coincidir.
- Revisar RLS y FKs por restaurante, impedir vínculos cross-tenant; política de actualización concurrente.
- `sales_types.is_default` SQL índice único: hacer cambio atómico, sin romper POS legacy.
- No cambiar IDs de `sales_types`, `packaging_items`, `product_packaging_rules`, `sales`, movimientos, colas o fechas.
- Evitar que pull filtrado por terminal marque catálogos globales como inactivos.
- Preservar `sale.salesTypeId`, `sale.salesTypeName`, payload `packagingMovements`, idempotencia por venta + empaque, anulación basada en movimiento original, compra/stock y fallback offline.

### Motor de consumo y alcance obligatorio
**Cambios preliminares ya presentes:** `local_packaging_movements_part.dart` llama `_isSalesTypeActive`; `local_packaging_support_part.dart` no comprueba `code == to_go`; tests editados en `sales_repository_test.dart`. Revisión obligatoria: confirmar funcionalidad y que reglas antiguas de `dine_in` antes ignoradas no provoquen consumo inesperado en rollout; si hay riesgo, feature flag o migración de política explícita por modalidad con valores legacy, snapshot y tests. No mezclar cambios operativos silenciosos con traslado visual.

- Probar `to_go`, `dine_in` sin regla, `dine_in` con regla explícita, `delivery`, `pickup`, tipos inactivos, combos, múltiples productos iguales, stock insuficiente, `tracks_stock=false`, edición de regla tras venta y anulación, offline/reintento, diferencias remoto/local.
- Establecer contrato de **consumo por pedido** para bolsa única vs consumo **por artículo** (actual). No improvisar usando una regla por producto: diseñar tabla/contrato y pruebas; si requiere esquema, staging y aprobación por gate. No activar políticas `permitir negativo/advertir` con un simple switch hasta diseñar autoridad online/offline de stock. Desplegar reglas por artículo primero solo si semántica comercial correcta.
- Consumo se confirma dentro de transacción con venta y movimientos; nunca aplicar dos veces. Idempotencia y rollback completos.

### Validaciones y simulaciones
1. Terminar **E0**: inventario read-only del esquema aplicado en Supabase y cantidades/reglas (sin secretos); usar clon aislado para operaciones de prueba. Si no existe entorno/clon autorizado, registrar bloqueo real en vez de tocar producción.
2. **E1–E3**: prototipo sobre pantallas reales (SMO-008), rutas, formularios y permisos. Preservar UI/UX conocida y soporte workspace.
3. **E4**: motor de empaques por reglas explícitas, compatibilidad legacy y pruebas E2E.
4. **E5** (terminales) requiere G-NUM y G-CON aprobados; NO desplegar simulación de varias cajas como real.
5. **E6**: retirar UI legacy solo con feature flag, QA, datos idénticos e integridad comprobada.
6. Ejecutar tests Flutter relevantes y SQL integración en staging, test de RLS cross-tenant, reintentos/void, lista/diálogos/selección de tabla, permisos y golden widget. Guardar resultados literales (comandos, exit codes, versiones) y capturas de antes/después.
7. Revisar estilo, límite 300 líneas, `dart format`, `flutter analyze`, build web, pruebas POS/Backoffice, QA de código y seguridad.
8. **No desplegar ni limpiar datos** sin aval específico después de simulaciones. Preparar PR con resumen exacto y pendiente de QA visual del usuario.

### Criterio de salida
Registros y IDs inalterados; venta+empaque mantiene cantidades esperadas; no doble consumo ni diferencias de caja/inventario; redirecciones y roles funcionan; dropdowns muestran nombres, nunca IDs; no regresiones POS; **todos los tests reales reportados con salida verificable**. Documentar en `Documentation/Auditorias/FasesEmpaques/` estado de cada gate, incluyendo explícitamente lo que NO se pudo ejecutar.

## Restricciones de esta entrega
Esta orden no autoriza aplicar migraciones a Supabase productivo. Si el siguiente paso exige ese permiso, detener exclusivamente ese paso y entregar código/SQL ensayados y reporte, no suspender trabajo independiente.

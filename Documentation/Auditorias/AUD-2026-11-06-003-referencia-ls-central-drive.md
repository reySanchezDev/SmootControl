# AUD-2026-11-06-003 — Referencia arquitectónica LS Central (Drive)

Fecha: 2026-11-06. Estado: revisión documental terminada; verificación SQL de comportamientos pendientes. Sin cambios de aplicación ni base de datos.

## Fuente y límites
Documentación de la carpeta Google Drive `1d_cSzRiUVN3hWtIxB7g1eJqE56XNIEku`, 9 archivos Markdown elaborados a partir de la BD POS de prueba. **Son observaciones de un esquema físico, no certificación del comportamiento runtime, ni documentación normativa del fabricante**. No se consultó directamente SQL Server desde esta auditoría.

Documentos clave:
- [Mapa](https://drive.google.com/file/d/1OYutPSodj4llbZ0NQ5wEbr1JGXwNIBni/view)
- [Items y clasificación](https://drive.google.com/file/d/1W8jozX3IF9PaDzpqUlhhWUtqxnV4QtFY/view)
- [BOM y recetas](https://drive.google.com/file/d/19paIquq__MmuYw943RHT8q7y-MeFC8rv/view)
- [Menús, modificadores y cocina](https://drive.google.com/file/d/1sRt58ZXm1M6QU-SgoVrKPTAEFdTIWeB5/view)
- [Flujo integral](https://drive.google.com/file/d/1ctRdjC9YLcr-f8xZx1BdDokQ_oH0nsso/view)
- [Modelo simplificado propuesto](https://drive.google.com/file/d/1ijWkABZZFPeAXW0d8UJkH1wTcT6jrWg1/view)

## Hallazgos relevantes para Kivo
1. Artículo `Item` como identidad central de vendibles, ingredientes, materiales, intermedios; clasificaciones, unidades, costos y reglas específicas en entidades relacionadas.
2. Receta `BOM Component` padre/hijo; extensión con versión, merma y campos `LSC Exclusion`, `LSC Price on Exclusion`, `LSC Excluded from Portion Wght`. **Hipótesis a confirmar**: cómo afectan realmente costo/stock/receta ante exclusión.
3. Modificadores `LSC Item Option Type`, `LSC Item Option Value`, `LSC Product Additional Item`, `LSC Deal Modifier Item`, `LSC WKS Style Modifier`. Cocina: `LSC KOT Line Modifier_Message`. No asumir un único flujo de parametrización.
4. Asociación de material vinculable a artículo y tipo de venta en `LSC Linked Item` (campos `Item No_`, `Linked Item No_`, `Sales Type`, `No_ of Items`, `Void With Parent`); **candidato** para estudiar reglas de empaque, sin afirmar equivalencia automática.
5. POS menu es presentación/acción (por ejemplo, `PLU_K`) y no debe confundirse con entidad producto o receta.
6. Líneas de venta contienen relación padre/hijo y atributos históricos. Kivo debe persistir snapshot efectivo de precio, receta y modificadores por línea.
7. Mapa reporta aprox. 3553 tablas, 73560 columnas, 10401 índices y 0 FKs declaradas. **No imitar** complejidad ni ausencia de restricciones.

## Decisiones de diseño propuestas, no autorizadas
- Centro de Artículos único, con UX progresiva por capacidades; empaques, materias primas, productos y servicios comparten identidad de artículo.
- Modificadores como agrupaciones/selections con efecto opcional: instrucción, agregar, excluir, sustituir. Sólo asociar artículos donde exista consumo/costo.
- Recetas versionadas, tipos de venta como configuración operativa independiente; reglas de empaque por contexto.
- Snapshot de operaciones y movimientos idempotentes auditables; RLS y FKs por restaurante.

## Qué debe investigar Codex en SQL de prueba — solo lectura
A. Seleccionar ejemplos **anonimizados** de artículo con BOM, componente de empaque, exclusión y opción/modificador; deducir referencias con clave y muestra de conteos, nunca sacar clientes ni tickets completos.
B. Resolver `LSC Linked Item` contra `Item` y `Sales Type`: cardinalidad y ejemplos genéricos, si se utiliza para empaques reales.
C. Mapear la cadena `Item Option Type` → `Item Option Value` → `Product Additional Item` / `Deal Modifier Item` / `KOT Line Modifier_Message`, marcando dónde la relación es inferida.
D. Comprobar si exclusión/sustitución se expresa como campo, línea, ajuste de BOM, modificador de cocina o solo en lógica de aplicación (en SQL puede no ser deducible).
E. Contrastar qué campos representan configuración vs. resultados de transacciones. No leer datos personales.
F. Reportar trazas reales verificables (nombres de tablas/columnas, join, conteos), hipótesis no verificadas y matriz de comportamientos para Kivo.

## Restricciones
Solo SELECT de metadatos/configuración y agregados anonimizados; no DDL, DML, EXEC de procesos de negocio, cambios de permisos, copias de datos personales ni exposición de secretos. Guardar en Drive bajo la misma carpeta y referenciar desde próximas auditorías. No introducir scripts de LS Central al repositorio de Kivo ni copiar componentes propietarios.

**Siguiente paso:** estudio por ejemplos del esquema SQL de prueba por Codex. Después contrastar con AUD-001 y AUD-002 para definir diseño final de Kivo, sin implementación todavía.

# Propuesta estructural: clase de artículo y control de existencias

**Fecha:** 2026-11-18  
**Estado:** propuesta para aprobación; no implementada.  
**Origen:** [Auditoría de tipo, clase y stock](ARTICULOS-TIPO-CLASE-STOCK-2026-11-18.md).  
**Referencia funcional:** [Business Central y LS Central](REFERENCIA-BUSINESS-CENTRAL-LS-CENTRAL-ARTICULOS-2026-11-18.md).

## 1. Objetivo

Un único maestro de artículos para Productos, Inventario, Compras, Recetas, Empaques y POS. Evitar que el usuario configure tres propiedades parcialmente redundantes y que los módulos interpreten de manera diferente si un artículo controla saldo.

La auditoría encontró cuatro productos con tipo inventory y tracks_inventory=false. La migración 124 deriva el indicador del tipo en el escritor, pero no demuestra por sí sola que las filas previas o todos los escritores estén reconciliados.

## 2. Modelo funcional propuesto

| Concepto | Función | Captura |
|---|---|---|
| Clase | Producto, Materia prima, Empaque, Servicio | Selector único |
| Controla existencias | Mantener saldo propio | Sí/No para clases físicas |
| Tipo técnico | inventory, non_inventory, service | Derivado por servidor; no editable independientemente |
| Categoría | Agrupación comercial/operativa | Catálogo existente |
| Clasificaciones | Etiquetas funcionales adicionales | Opcionales, independientes de clase |
| Unidad base | Referencia de cantidades y costos | Unidad existente |

Mantener inicialmente los tres campos físicos por compatibilidad. tracks_inventory será la autoridad funcional del saldo; item_type una representación derivada y consistente. No crear nuevos maestros ni eliminar columnas sin auditar consumidores.

## 3. Reglas de derivación

| Clase | Controla existencias | item_type |
|---|---|---|
| Producto, Materia prima o Empaque | Sí | inventory |
| Producto, Materia prima o Empaque | No | non_inventory |
| Servicio | No obligatorio | service |

La última fila significa que el servicio **nunca** controla existencias: el valor falso es obligatorio y el control se oculta o deshabilita. No debe existir una opción Servicio duplicada en otro selector.

PostgreSQL valida la combinación en el escritor autorizado y, tras reconciliar datos, mediante restricciones de integridad. No aceptar dos valores contradictorios enviados por clientes. Durante transición, adaptar clientes antiguos que envían item_type mediante un contrato inequívoco; rechazar conflictos explícitos. Mantener permisos, RLS, tenant, atomicidad y revisión de snapshot.

## 4. Matriz funcional propuesta

| Clase | Stock | Compra | Venta directa | Uso |
|---|---|---|---|---|
| Producto | Opcional | Según configuración | Sí, si habilitado | Venta directa o receta |
| Materia prima | Opcional; Sí por defecto al crear | Según configuración | No en contrato actual | Ingrediente |
| Empaque | Opcional; Sí por defecto al crear | Según configuración | No en contrato actual | Regla de consumo |
| Servicio | Nunca | Posible | Posible | Prestación no física |

Los valores por defecto son propuestas para nuevos registros; nunca modifican históricos. La venta directa de materias primas y empaques, y la visibilidad POS de servicios, requieren decisión y revisión del contrato vigente: la migración 121 restringe dichas capacidades. El precio/costo y las autorizaciones comerciales son dimensiones separadas del control de saldo.

## 5. Ejemplos

| Artículo | Clase | Stock propio | Receta |
|---|---|---|---|
| Coca-Cola en lata | Producto | Sí | No |
| Hamburguesa preparada al momento | Producto | No | Sí |
| Hamburguesa preparada por lotes | Producto | Sí | Según proceso de producción |
| Carne molida | Materia prima | Sí | No |
| Sal | Materia prima | Opcional | No |
| Vaso 16 oz | Empaque | Sí, si se controla cantidad | No |
| Servilleta | Empaque | Opcional | No |
| Entrega | Servicio | No | No |

El vaso código 4 aparece sin stock en la auditoría y con stock habilitado en la captura posterior del propietario; confirmar estado persistido actual, no modificar por inferencia.

## 6. Flujo transaccional

- Inventario lista artículos activos que controlan existencias, incluidos los que no tienen fila de saldo (mostrar cero).
- Compras: permitir artículos comprables. Registrar el movimiento de entrada solo si controlan existencias; los demás mantienen su tratamiento de costo/gasto sin crear saldo ficticio.
- Ajustes y conteos: solo artículos inventariables.
- Venta directa inventariable: descontar artículo vendido. Producto preparado bajo pedido sin saldo propio: consumir componentes inventariables de receta vigente.
- Producción anticipada: consumir ingredientes al producir y registrar entrada del producto terminado; al vender descontar terminado. No descontar ingredientes otra vez. Este modo requiere un contrato de producción definido antes de habilitarlo.
- Empaques: evaluar reglas por artículo, tipo de venta y alcance (línea/pedido), aplicar cantidades a componentes inventariables; evitar duplicar consumo si también aparece en receta. Los no inventariables pueden participar en cálculo de costo sin movimiento de saldo.
- Anulación: revertir movimientos originales registrados, con identidad e idempotencia; no recalcular desde receta o configuración actual.
- POS offline: snapshot versionado, mismo comportamiento de stock que servidor, validación al sincronizar y tratamiento explícito de divergencias; conservar reglas de stock negativo ya aprobadas, sin ampliar por defecto.

La venta de hamburguesa para llevar puede consumir pan, carne y queso por receta, y caja/bolsa por tipo de venta. No debe inventar saldo de la hamburguesa si se prepara bajo pedido. El costo de componentes no inventariables se considera según política de costeo, no por movimientos inexistentes.

## 7. UX

Reutilizar ArticlesPage y su ficha en la misma pestaña (UX-048). No crear otra pantalla.

Información general: nombre, clase, unidad base, categoría; código comercial según política vigente de numeración, sin exponer UUID. Inventario: Controla existencias, con ayuda breve y comportamiento condicionado a clase. Costos y precios: campos pertinentes. Operación: venta, compra, receta, cocina y POS según capacidades; no repetir Tipo. Mostrar implicaciones al modificar stock. Secciones compactas y grilla responsiva, sin formulario vertical interminable.

## 8. Transiciones de datos y seguridad

- Auditar consumidores SQL y Flutter, maestros, compras, movimientos, recetas, reglas, ventas/anulaciones, POS offline, sincronización y reportes. Identificar especialmente 121, 124, 125–127 y 107; revisar implementación activa, no solo nombres de archivos.
- Clasificar las cuatro filas Producto/inventory/no-track como casos pendientes; verificar saldo, historial, reglas y decisión del propietario. No elegir automáticamente entre tipo e indicador.
- Materia prima non_inventory/no-track: combinación técnicamente coherente con propuesta; confirmar intención operativa sin convertir automáticamente.
- No permitir desactivar control con saldo distinto de cero o movimientos/colas pendientes. Exigir proceso de cierre/reconciliación; conservar historial. Evaluar además cambios de clase y referencias históricas, manteniendo la restricción actual de identidad hasta definir una transición.
- Activación de control: saldo inicial cero o ajuste autorizado y auditable, nunca saldo inventado.
- Reconciliar datos en laboratorio y generar informe de diferencias; solo entonces validar restricciones y adaptación de clientes. No resetear Docker, no aplicar 088, no tocar remoto ni main.

## 9. Criterios de aceptación

Crear y editar cada clase y ambas opciones de stock aplicables; verificar derivación, relectura y F5. Rechazar servicio con stock, payload contradictorio y escrituras cross-tenant/sin permiso. Comprobar compras, ajustes, ventas con/sin stock propio, receta, empaque inventariable/no inventariable, anulación exacta e idempotencia, producción si se aprueba, sincronización offline y reglas de saldo negativo existentes. Verificar cambios de estado con saldo y colas pendientes. Pruebas sobre Docker local con JWT real y Flutter Web RELEASE; QA visual del propietario. No declarar aprobado solo por CI o HTTP 200.

## 10. Decisiones pendientes

1. Aprobar Clase + Controla existencias como único modelo visible.
2. Confirmar restricciones de venta directa y servicios en POS.
3. Confirmar intención de las filas históricas inconsistentes y del vaso código 4.
4. Definir política de costeo y producción anticipada frente a preparación al vender.

Esta propuesta no autoriza cambios de esquema, datos, UI ni despliegue.

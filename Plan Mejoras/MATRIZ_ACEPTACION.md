# Matriz de aceptación — SmooControl Backoffice + POS

**Estado inicial:** ninguna prueba de esta matriz se declara aprobada sin evidencia. Completar casillas, SHA, captura/log (saneado), responsable y fecha durante la ejecución.

## A. Control de ejecución

- Rama / PR:
- Commit candidato:
- Versión Flutter / Dart:
- Build web:
- APK POS release:
- APK Time Clock:
- Ambiente staging y FQDN:
- Responsable QA:
- Responsable autorización:

## B. Experiencias y navegación

- [ ] Se identifican **todas** las rutas y subpantallas: POS / Backoffice / Time Clock / compartidas.
- [ ] Inicio de sesión POS abre POS, nunca Backoffice por tamaño de pantalla.
- [ ] Usuario admin abre Backoffice incluso a 390px.
- [ ] Usuario POS no obtiene una ruta de Backoffice por deep link, navegador o acceso directo.
- [ ] Usuario admin no obtiene operaciones POS sin autorización específica.
- [ ] Permisos por rol siguen aplicando en navegación y servidor.
- [ ] Rutas desconocidas o prohibidas muestran resultado explícito y seguro.
- [ ] Sesión remota expirada y logout vuelven a autenticación sin contenido privilegiado.
- [ ] Time Clock continúa funcionando con su modo de compilación original.

## C. UX completa — inventario funcional

Para cada pantalla principal y subpantalla de Backoffice adjuntar evidencia desktop y al menos un ancho compacto; marcar N/A justificado:

- [ ] Dashboard
- [ ] Productos
- [ ] Categorías
- [ ] Recetas
- [ ] Unidades de medida
- [ ] Modificadores
- [ ] Métodos de pago
- [ ] Mesas
- [ ] Empaques
- [ ] Inventario y ajustes
- [ ] Movimientos y detalle
- [ ] Ventas y detalle
- [ ] Caja
- [ ] Gastos
- [ ] Personal y submódulos
- [ ] Marcadas administrativas
- [ ] Vacaciones
- [ ] Planilla
- [ ] Reportes y detalles/PDF
- [ ] Configuración
- [ ] Tasas de cambio
- [ ] Roles y permisos
- [ ] Auditoría
- [ ] Usuarios

Por módulo: [ ] filtros claros; [ ] acciones visibles y etiquetadas; [ ] selección contextual adecuada; [ ] scroll y sticky headers; [ ] diálogo escritorio apropiado; [ ] mobile usable; [ ] foco/teclado y mensajes coherentes.

## D. POS y persistencia — regresión

- [ ] POS teléfono 390×844
- [ ] POS tableta 768×1024 / tamaño real objetivo
- [ ] Venta de prueba aislada (sin datos productivos)
- [ ] Apertura/cierre de caja de prueba
- [ ] Mesas y productos
- [ ] Pagos y totales equivalentes a línea base
- [ ] Persistencia local y recuperación tras reinicio
- [ ] Trabajo offline según capacidades actualmente soportadas
- [ ] Reintento de cola y reconciliación al reconectar
- [ ] No cambios inesperados de reglas fiscales, stock o reportes

## E. Seguridad y tenants

- [ ] No hay secretos administrativos en bundle web
- [ ] Backend verifica autorización, no solo frontend
- [ ] Tenant/restaurante aislado para consultas y mutaciones
- [ ] CORS y redirects limitados a orígenes válidos
- [ ] TLS válido y HTTP redirigido
- [ ] No se filtran tokens/datos personales en logs
- [ ] Cuenta de menor privilegio utilizada en smoke

## F. Build, dominio e infraestructura

- [ ] `flutter analyze` sin nuevos hallazgos
- [ ] Pruebas focalizadas aprobadas
- [ ] Suite integral final pertinente aprobada
- [ ] GitHub Actions final aprobado
- [ ] Build web reproducible desde commit fijo
- [ ] Bootstrap, assets y worker Drift operativos
- [ ] Reglas SPA/404 y recargas directas funcionando
- [ ] HTTPS en staging y dominio final
- [ ] DNS compatible con correo y otros servicios actuales
- [ ] APK POS release con firma de publicación correcta
- [ ] Android Time Clock sin regresión
- [ ] Copia de release anterior disponible
- [ ] Reversión probada en staging

## G. GO / NO-GO

**Críticos abiertos:**
**Riesgos aceptados explícitamente:**
**SHA aprobado:**
**Dominio aprobado:**
**Fecha de aprobación:**
**Responsable:**
**Decisión:** NO-GO hasta completar gates.

Se prohíbe declarar producto listo para comercializar por la sola aprobación visual o un workflow CI exitoso.

# Política de QA proporcional al riesgo — SmooControl

**Vigente desde:** 2026-11-03. **Alcance:** SmooControl POS, Backoffice Web y Time Clock. Esta política reduce ejecuciones redundantes durante desarrollo; no reduce las puertas de calidad de publicación.

## Regla operativa

| Tipo de modificación | Validación incremental mínima |
| --- | --- |
| Formato, documentación, imports, lint equivalente | `dart format` en archivos tocados y `flutter analyze` cuando afecte código; no ejecutar toda la suite ni construir Web |
| UX aislada (estilos, disposición, labels) | Pruebas de widget/foco y renderización del componente; revisión de tamaño relevante |
| Error reproducible | Ejecutar exclusivamente la prueba que falla, preferentemente con `-r expanded`; registrar diagnóstico antes de cambiar producción; repetir hasta verde |
| Lógica compartida, servicios, autorización, inventario, pagos, sincronización | Tests afectados y dependencias directas; ampliar a regresión relacionada según impacto |
| Integración de varios módulos o cierre de lote significativo | Tests de integración de los módulos modificados; build solo si puede existir incompatibilidad de compilación/plataforma |
| Final de fase, release, merge a `main`, despliegue | `flutter analyze`, suite de regresión completa, builds oficiales (Web/Android según producto), verificación visual y checklist GO/NO-GO |

## Reglas para Codex y revisión

1. **No repetir** automáticamente todas las pruebas, build Web o GitHub Actions tras cada cambio puramente visual o de lint.
2. **Agrupar** varias pantallas relacionadas en una rama de integración y solicitar una validación de lote.
3. **Ante una falla**, no repetir la suite completa: recuperar nombre, línea de la aserción, excepción, pila y estado. Corregir la causa concreta y ejecutar primero el test afectado.
4. Las pruebas existentes que pasaron en un SHA anterior **no prueban** cambios posteriores; registrar siempre el último SHA comprobado y qué fue cubierto.
5. Diferenciar evidencia de `flutter analyze`, tests de widgets, build oficial, verificación visual manual y certificación end-to-end. Ninguna reemplaza automáticamente a las demás.
6. Cambios en datos, autenticación, permisos, transacciones, saldos, persistencia o infraestructura crítica pueden exigir ampliar el alcance **antes** del fin de fase.
7. Mantener POS/Backoffice/Time Clock aislados; no intervenir `main`, bases de producción, servidores ni despliegues sin autorización expresa.
8. Preservar archivos locales generados de l10n y stashes; no versionar cambios no autorizados.
9. Cuando el ambiente no tiene navegador real, registrar **QA visual pendiente** en lugar de afirmar que se verificó visualmente.
10. Reservar **regresión completa + build + revisión visual integral** para los hitos de cierre F3 y release, o excepciones justificadas.

## Aplicación inmediata: Time Clock

**Resultado conocido:** prueba `initialization reload transitions to standalone marker` falla; los otros tres tests de Time Clock pasan. No hay evidencia suficiente para atribuir la falla a `FutureBuilder`, sincronización del test o lógica del marcador.

**Única ejecución necesaria ahora:**

```powershell
flutter test test/features/attendance/presentation/pages/time_clock_gate_test.dart --plain-name "initialization reload transitions to standalone marker" -r expanded
```

Registrar cuál expectativa falla (invocaciones `loads`, indicador de progreso, destino o ausencia del botón), excepción exacta y pila. Si falla el componente, corregirlo con un cambio mínimo y repetir esa prueba. Si falla la prueba de sincronización, ajustar únicamente el test con justificación. No ejecutar POS completo ni reconstruir Web para esta investigación.

**Excepción:** si el arreglo toca enrutamiento, autenticación u otro componente compartido, añadir pruebas de navegación de Time Clock y relacionadas; la regresión integral espera al cierre de fase.

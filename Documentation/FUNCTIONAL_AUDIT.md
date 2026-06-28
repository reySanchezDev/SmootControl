# Auditoria Funcional

## 2026-06-23 - Exposicion De Campos Tecnicos

### Hallazgo

La primera version de pantallas operativas expuso campos que pertenecen al
sistema o a la base de datos, no al usuario final:

- IDs internos.
- Ordenamiento tecnico.
- Montos capturados como centavos.
- Usuario/cajero escrito manualmente.
- Sesion de caja escrita manualmente.

### Regla Funcional Confirmada

- El usuario no debe digitar IDs internos.
- El usuario no debe digitar orden tecnico.
- Las categorias principales no tienen categoria padre.
- Las subcategorias si deben seleccionar una categoria principal por nombre.
- Los IDs y el orden interno se generan desde el sistema.
- Los montos se deben capturar como moneda visible, aunque internamente se
  guarden en centavos.

### Corregido

#### Catalogo

Estado: Completado.

- El modal de alta ya no muestra `ID de categoria padre`.
- El modal de alta ya no muestra `Orden`.
- Se agrego selector de tipo:
  - Categoria.
  - Subcategoria.
- Al crear subcategoria, se selecciona la categoria padre por nombre.
- El ID se genera automaticamente.
- El orden se calcula automaticamente por grupo de hermanos.

Pruebas:

- `flutter test test\features\catalog\presentation\widgets\create_category_dialog_test.dart`
- `flutter test`
- Build release Web.
- Verificacion visual CDP de `/catalog`.
- Verificacion visual CDP del modal de nueva categoria.

### Deuda Funcional Detectada

#### Productos

Estado: Completado en UI inicial.

- Ya no pide `ID de categoria`; selecciona categoria/subcategoria por nombre.
- Ya no pide precio/costo "en centavos"; captura moneda visible.
- La lista muestra moneda visible.

#### Gastos Operativos

Estado: Completado en UI inicial y asociacion interna.

- Ya no pide `ID de categoria`; selecciona categoria de gasto por nombre.
- Ya no pide `ID de caja`.
- Ya no pide `Registrado por`.
- Ya no pide monto en centavos; captura moneda visible.
- Si existe caja abierta del dia, el gasto se asocia internamente a esa caja.
- El responsable sale del usuario autenticado local en `CurrentOperatorService`;
  `usuario-local` queda solo como respaldo tecnico/legacy.

#### Caja Diaria

Estado: Completado en UI inicial y persistencia local.

- Ya no pide `ID de cajero`.
- Ya no pide `ID de caja` para cerrar.
- El cierre usa la sesion abierta en memoria.
- La pantalla recupera la caja abierta desde persistencia local al entrar.
- El repositorio evita abrir una segunda caja para la misma fecha de negocio.
- El resumen no muestra el ID tecnico de sesion.
- Los montos se muestran como moneda visible.
- La apertura/cierre usa el usuario autenticado local desde
  `CurrentOperatorService`.

#### POS Y Ventas

Estado: Completado en UI inicial y reglas de caja.

- Los montos en carrito, productos y ventas se muestran como moneda visible.
- La UI usa formato de moneda consistente con `MoneyFormatter`.
- El POS exige caja diaria abierta para cobrar.
- La venta guarda internamente la caja abierta sin pedir ID al usuario.

### Riesgo

Si estas deudas no se corrigen antes de seguir agregando pantallas, el sistema
puede quedar funcionalmente correcto por dentro pero incomodo y propenso a error
para cajeros, meseros y administradores.

### Siguiente Accion Recomendada

Revisar permisos por pantalla para que el rol autenticado limite acciones
sensibles antes de conectar Auth remoto.

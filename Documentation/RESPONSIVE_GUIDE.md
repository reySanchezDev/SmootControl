# Guia Responsiva - SmooControl

## Breakpoints

| Tipo | Ancho |
| --- | --- |
| Movil | `< 600` |
| Tablet | `600 - 1023` |
| Web/Desktop | `>= 1024` |

## Reglas

- No debe existir overflow visual.
- No usar tamanos de fuente basados en viewport width.
- Usar `Flexible`, `Expanded`, `maxLines` y `TextOverflow.ellipsis` solo para
  datos largos no criticos. Los botones de accion nunca deben truncar texto; se
  debe ajustar el texto, el ancho o usar escalado controlado.
- Las cajas de texto no deben venir precargadas con valores que el usuario tenga
  que borrar. Los valores sugeridos van como placeholder/hint; solo se precargan
  datos reales existentes que el usuario este editando.
- POS movil debe operar por toque.
- POS tablet/web puede usar paneles y drag and drop.
- Formularios deben mantener orden logico.
- Grillas deben tener constraints estables.

## Viewports De QA

- Movil: `360x800`.
- Tablet: `768x1024`.
- Web: `1366x768`.

## Validaciones Implementadas

- POS movil `360x800`: render sin overflow y productos no disponibles ocultos.
- POS tablet `768x1024`: render sin overflow con panel de cuenta mas ancho que
  en escritorio para mantener controles usables.
- POS web `1366x768`: render de catalogo y cuenta sin excepciones de layout.
- Grilla POS: en pantallas angostas usa tiles mas altos para evitar cortes de texto,
  iconos o precios.

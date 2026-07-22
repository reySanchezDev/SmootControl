# Marcadas De Entrada/Salida Y Horas Extra

## Objetivo

Implementar un modulo de marcadas para que el personal registre entrada y
salida desde un APK de marcador separado, sin PIN en V1. Las marcadas se
sincronizan a Supabase, el admin puede corregirlas y las horas extra pasan por
autorizacion antes de entrar a planilla.

## Checklist De Etapas

- [x] Migracion Supabase aplicada.
- [x] Tablas locales y sync de marcadas.
- [x] Pantalla marcador con empleados activos.
- [x] Pantalla admin de marcadas.
- [x] Bandeja de horas extra por autorizar.
- [x] Reporte de marcadas.
- [x] APK marcador separado.
- [x] Pruebas y build release.

## Reglas V1

- La marcada no usa PIN ni biometria.
- El control antifraude operativo se apoya en las camaras del restaurante.
- Una jornada normal es de 8 horas.
- Las horas por encima de 8 generan candidato de hora extra.
- Solo las horas extra autorizadas se insertan en planilla.
- El APK marcador no depende de caja abierta ni login POS.
- Admin lee y escribe remoto directo.
- El marcador guarda local primero y sincroniza por cola.

## Seguimiento

| Etapa | Estado | Nota |
|---|---|---|
| Documentacion | Completado | Plan creado para dar seguimiento. |
| Migracion | Completado | 066 aplicada en Supabase remoto. |
| Local/sync | Completado | Drift local, cola sync y RPC idempotente. |
| UI marcador | Completado | Grid por foto/iniciales sin login POS. |
| UI admin | Completado | Marcadas y autorizacion de horas extra. |
| Reportes | Completado | Reporte de marcadas por periodo. |
| APK | Completado | POS y marcador generados en release. |

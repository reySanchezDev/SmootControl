# Casos de prueba E2E

| ID | Caso | Resultado actual |
|---|---|---|
| E2E-01 | Crear item sin código comercial | Aprobado en SQL local; código técnico `ART-n` |
| E2E-02 | Código comercial automático único por tenant | Aprobado en SQL local |
| E2E-03 | Editar item sin cambiar ID ni código | Aprobado en SQL local |
| E2E-04 | Categoría válida y aislamiento tenant | Aprobado en la función de escritura local |
| E2E-05 | Pull canónico al POS | Aprobado a nivel RPC; no integrado en cliente |
| E2E-06 | Item nuevo visible en POS | Bloqueado por H-001 |
| E2E-07 | Venta de item nuevo | Bloqueado por H-002/H-003 |
| E2E-08 | Descarga de inventario | No certificado |
| E2E-09 | Ajuste/entrada/consumo de inventario | No certificado para `items` |
| E2E-10 | Anulación y reversión | No certificado |
| E2E-11 | Reintento idempotente | No certificado con contrato canónico |
| E2E-12 | F5 y sincronización posterior | No certificado |


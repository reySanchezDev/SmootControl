# Conexion Al Remoto Supabase

Este documento deja el procedimiento correcto para consultar y administrar el
proyecto remoto Supabase de SmooControl desde este repositorio.

## Regla Principal

Desde la raiz del proyecto, usar Supabase CLI enlazado:

```powershell
cd C:\Users\reyre\Aplicaciones\SmooControl
supabase db query "select now() as checked_at;" --linked
```

Este es el metodo preferido para auditorias puntuales, validaciones de datos,
revision de ventas sincronizadas, movimientos de inventario, dispositivos POS y
pruebas de migraciones ya aplicadas.

## Por Que No Usar `psql` Directo Primero

En esta maquina el host directo:

```text
db.hexejdgbcmyiyqtvfihr.supabase.co
```

puede resolver solo IPv6. Eso puede causar errores como:

```text
getaddrinfo ENOTFOUND db.hexejdgbcmyiyqtvfihr.supabase.co
```

Ademas, `psql` no siempre esta instalado en PATH. Por eso el primer intento debe
ser siempre `supabase db query --linked`.

## Consultas Frecuentes

### Ver ventas recientes de un producto

```powershell
supabase db query @"
select s.id,
       s.invoice_number,
       s.total_amount,
       s.total_cost,
       s.gross_profit,
       s.sold_at,
       s.pos_device_id,
       d.name as device_name
  from public.sales s
  left join public.pos_devices d on d.id = s.pos_device_id
 where s.restaurant_id = '0f4e9ea0-948e-4d07-b2e0-55a96b3a462f'
   and exists (
     select 1
       from public.sale_items i
      where i.sale_id = s.id
        and upper(i.product_name) like '%A LO NICA%'
   )
 order by s.sold_at desc
 limit 10;
"@ --linked
```

### Ver detalle de una venta

```powershell
supabase db query @"
select product_name,
       quantity,
       unit_price,
       unit_cost,
       subtotal,
       gross_profit
  from public.sale_items
 where sale_id = 'SALE_ID_AQUI'
 order by created_at;
"@ --linked
```

### Ver explosion de receta por venta

```powershell
supabase db query @"
select m.id,
       p.name as product_name,
       m.movement_type,
       m.quantity_delta,
       m.reference_type,
       m.reference_id,
       m.pos_device_id,
       m.created_at,
       m.notes
  from public.inventory_movements m
  left join public.products p on p.id = m.product_id
 where m.restaurant_id = '0f4e9ea0-948e-4d07-b2e0-55a96b3a462f'
   and m.reference_id = 'SALE_ID_AQUI'
 order by m.created_at desc, m.id;
"@ --linked
```

### Ver stock de una materia prima

```powershell
supabase db query @"
select p.id,
       p.name,
       s.quantity_on_hand,
       p.inventory_unit_id,
       u.name as inventory_unit_name,
       u.symbol as inventory_unit_symbol
  from public.products p
  left join public.inventory_stock s
    on s.product_id = p.id
   and s.restaurant_id = p.restaurant_id
  left join public.measurement_units u
    on u.id = p.inventory_unit_id
 where p.restaurant_id = '0f4e9ea0-948e-4d07-b2e0-55a96b3a462f'
   and upper(p.name) like '%CONSOME POLLO%';
"@ --linked
```

### Ver dispositivos POS

```powershell
supabase db query @"
select id,
       name,
       is_active,
       created_at,
       last_seen_at,
       updated_at
  from public.pos_devices
 where restaurant_id = '0f4e9ea0-948e-4d07-b2e0-55a96b3a462f'
 order by last_seen_at desc nulls last, created_at desc;
"@ --linked
```

## Migraciones

Para validar migraciones locales/remotas:

```powershell
supabase migration list
```

Para aplicar migraciones pendientes:

```powershell
supabase db push
```

Despues de aplicar, confirmar que la version aparece en local y remoto:

```powershell
supabase migration list
```

## Seguridad

- No imprimir contrasenas ni claves secretas en respuestas al usuario.
- No copiar secretos a codigo fuente, migraciones, tests ni documentacion nueva.
- `Requerimiento/CredencialesSupabase.md` es la fuente privada local de
  credenciales, pero no debe ser citado con valores sensibles en respuestas.
- Las consultas SQL deben limitarse por `restaurant_id` cuando sean de datos de
  negocio.
- Cualquier `delete` o `update` manual en produccion debe ser quirurgico,
  comentado en la respuesta y preferiblemente precedido por un `select` de
  vista previa.

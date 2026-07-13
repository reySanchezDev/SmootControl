alter table public.expense_categories
  add column if not exists coverage_expense_type text,
  add column if not exists coverage_estimated_amount numeric(15, 4),
  add column if not exists coverage_frequency text,
  add column if not exists coverage_due_days jsonb not null default '[]'::jsonb,
  add column if not exists coverage_notes text,
  add column if not exists coverage_is_active boolean not null default true;

comment on column public.expense_categories.include_in_gross_profit_coverage is
  'Subcategory flag. When true, operational expenses in this subcategory are measured against gross profit coverage reports.';
comment on column public.expense_categories.coverage_expense_type is
  'Projected coverage behavior: fixed or variable.';
comment on column public.expense_categories.coverage_estimated_amount is
  'Expected amount for projected coverage. Required by the app for fixed expenses and optional for variable expenses.';
comment on column public.expense_categories.coverage_frequency is
  'Expected recurrence: weekly, biweekly, monthly, or custom.';
comment on column public.expense_categories.coverage_due_days is
  'Payment days used by projected coverage reports.';

alter table public.expense_categories
  drop constraint if exists expense_categories_coverage_only_root_chk,
  drop constraint if exists expense_categories_coverage_child_only_chk,
  drop constraint if exists expense_categories_coverage_type_chk,
  drop constraint if exists expense_categories_coverage_frequency_chk,
  drop constraint if exists expense_categories_coverage_amount_chk,
  drop constraint if exists expense_categories_coverage_due_days_chk;

update public.expense_categories child
set include_in_gross_profit_coverage = true,
    coverage_expense_type = coalesce(child.coverage_expense_type, 'variable'),
    coverage_frequency = coalesce(child.coverage_frequency, 'custom'),
    coverage_is_active = true,
    updated_at = now()
from public.expense_categories parent
where child.parent_id = parent.id
  and parent.include_in_gross_profit_coverage is true
  and child.include_in_gross_profit_coverage is false;

update public.expense_categories
set include_in_gross_profit_coverage = false,
    coverage_expense_type = null,
    coverage_estimated_amount = null,
    coverage_frequency = null,
    coverage_due_days = '[]'::jsonb,
    coverage_notes = null,
    updated_at = now()
where parent_id is null
  and include_in_gross_profit_coverage is true;

create or replace function public.app_expense_due_days_are_valid(p_days jsonb)
returns boolean
language sql
immutable
as $$
  select jsonb_typeof(coalesce(p_days, '[]'::jsonb)) = 'array'
     and not exists (
       select 1
       from jsonb_array_elements(coalesce(p_days, '[]'::jsonb)) as value(day)
       where jsonb_typeof(value.day) <> 'number'
          or value.day::text !~ '^[0-9]+$'
          or value.day::text::int < 1
          or value.day::text::int > 31
     );
$$;

alter table public.expense_categories
  add constraint expense_categories_coverage_child_only_chk
    check (parent_id is not null or include_in_gross_profit_coverage is false),
  add constraint expense_categories_coverage_type_chk
    check (
      include_in_gross_profit_coverage is false
      or coverage_expense_type in ('fixed', 'variable')
    ),
  add constraint expense_categories_coverage_frequency_chk
    check (
      include_in_gross_profit_coverage is false
      or coverage_frequency in ('weekly', 'biweekly', 'monthly', 'custom')
    ),
  add constraint expense_categories_coverage_amount_chk
    check (
      include_in_gross_profit_coverage is false
      or coverage_expense_type <> 'fixed'
      or coalesce(coverage_estimated_amount, 0) > 0
    ),
  add constraint expense_categories_coverage_due_days_chk
    check (
      include_in_gross_profit_coverage is false
      or public.app_expense_due_days_are_valid(coverage_due_days)
    );

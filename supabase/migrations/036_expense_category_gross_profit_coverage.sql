alter table public.expense_categories
  add column if not exists include_in_gross_profit_coverage boolean not null default false;

comment on column public.expense_categories.include_in_gross_profit_coverage is
  'Root expense category flag. When true, expenses under this category are subtracted in gross-profit coverage reports. Keep false for payroll, salary advances, and inventory/provider purchases to avoid double counting.';

update public.expense_categories
set include_in_gross_profit_coverage = false
where parent_id is not null
  and include_in_gross_profit_coverage is true;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'expense_categories_coverage_only_root_chk'
  ) then
    alter table public.expense_categories
      add constraint expense_categories_coverage_only_root_chk
      check (
        parent_id is null
        or include_in_gross_profit_coverage is false
      );
  end if;
end $$;

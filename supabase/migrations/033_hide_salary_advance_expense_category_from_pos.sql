UPDATE public.expense_categories
   SET is_active = false,
       updated_at = now()
 WHERE id = '33333333-3333-4333-8333-333333333333';

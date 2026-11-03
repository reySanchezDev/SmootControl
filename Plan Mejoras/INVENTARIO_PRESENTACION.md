# F1 — Catálogo de subpantallas y componentes de presentación

**Fuente:** árbol Git de `main`, 2026-11-03. Archivos clasificados por `lib/features/<feature>/presentation/pages|widgets`. Esto mide cobertura **de código** y no significa que cada archivo sea una pantalla independiente ni que todos sean accesibles a usuarios finales.

**Experiencia prevista:** `pos` → POS; `auth`, `sync` → compartida/entrada; `attendance` combina administración y Time Clock (inspección de modo obligatoria); el resto puede incluir operaciones tanto POS como Backoffice cuando es reutilizado, por lo que **no** se etiqueta como exclusivo sin comprobar referencias.

## Archivos por módulo

| Módulo | Archivos de presentación | Propiedad preliminar / verificación |
|---|---:|---|
| `attendance` | 11 | Backoffice / Time Clock; revisar |
| `audit` | 2 | Backoffice o componente compartido; revisar usos |
| `auth` | 4 | Entrada compartida |
| `cash_register` | 5 | Backoffice o componente compartido; revisar usos |
| `catalog` | 5 | Backoffice o componente compartido; revisar usos |
| `dashboard` | 5 | Backoffice o componente compartido; revisar usos |
| `exchange_rates` | 2 | Backoffice o componente compartido; revisar usos |
| `expenses` | 6 | Backoffice o componente compartido; revisar usos |
| `inventory` | 11 | Backoffice o componente compartido; revisar usos |
| `modifiers` | 5 | Backoffice o componente compartido; revisar usos |
| `packaging` | 6 | Backoffice o componente compartido; revisar usos |
| `payment_methods` | 4 | Backoffice o componente compartido; revisar usos |
| `pos` | 56 | POS |
| `products` | 19 | Backoffice o componente compartido; revisar usos |
| `recipes` | 3 | Backoffice o componente compartido; revisar usos |
| `reports` | 35 | Backoffice o componente compartido; revisar usos |
| `roles` | 2 | Backoffice o componente compartido; revisar usos |
| `sales` | 10 | Backoffice o componente compartido; revisar usos |
| `settings` | 1 | Backoffice o componente compartido; revisar usos |
| `staff` | 19 | Backoffice o componente compartido; revisar usos |
| `sync` | 3 | Compartido/administración; revisar |
| `system` | 4 | Backoffice o componente compartido; revisar usos |
| `tables` | 2 | Backoffice o componente compartido; revisar usos |
| `users` | 2 | Backoffice o componente compartido; revisar usos |

## Detalle auditable

### attendance

- `lib/features/attendance/presentation/pages/attendance_admin_page.dart`
- `lib/features/attendance/presentation/pages/attendance_admin_table_part.dart`
- `lib/features/attendance/presentation/pages/attendance_admin_widgets_part.dart`
- `lib/features/attendance/presentation/pages/overtime_approvals_page.dart`
- `lib/features/attendance/presentation/pages/time_clock_gate.dart`
- `lib/features/attendance/presentation/pages/time_clock_page.dart`
- `lib/features/attendance/presentation/pages/time_clock_widgets_part.dart`
- `lib/features/attendance/presentation/pages/vacation_requests_form_part.dart`
- `lib/features/attendance/presentation/pages/vacation_requests_page.dart`
- `lib/features/attendance/presentation/pages/vacation_requests_table_part.dart`
- `lib/features/attendance/presentation/pages/vacation_requests_widgets_part.dart`

### audit

- `lib/features/audit/presentation/pages/audit_log_page.dart`
- `lib/features/audit/presentation/widgets/audit_log_tile.dart`

### auth

- `lib/features/auth/presentation/pages/auth_gate.dart`
- `lib/features/auth/presentation/pages/device_initialization_page.dart`
- `lib/features/auth/presentation/pages/login_page.dart`
- `lib/features/auth/presentation/pages/remote_initial_admin_setup_page.dart`

### cash_register

- `lib/features/cash_register/presentation/pages/cash_register_admin_page.dart`
- `lib/features/cash_register/presentation/pages/cash_register_admin_tile.dart`
- `lib/features/cash_register/presentation/widgets/cash_register_backoffice_table.dart`
- `lib/features/cash_register/presentation/widgets/close_cash_register_dialog.dart`
- `lib/features/cash_register/presentation/widgets/open_cash_register_dialog.dart`

### catalog

- `lib/features/catalog/presentation/pages/catalog_page.dart`
- `lib/features/catalog/presentation/widgets/catalog_backoffice_table.dart`
- `lib/features/catalog/presentation/widgets/catalog_category_tile.dart`
- `lib/features/catalog/presentation/widgets/catalog_tree_list.dart`
- `lib/features/catalog/presentation/widgets/create_category_dialog.dart`

### dashboard

- `lib/features/dashboard/presentation/pages/backoffice_home_page.dart`
- `lib/features/dashboard/presentation/pages/dashboard_content_part.dart`
- `lib/features/dashboard/presentation/pages/dashboard_page.dart`
- `lib/features/dashboard/presentation/pages/dashboard_staff_section_part.dart`
- `lib/features/dashboard/presentation/pages/dashboard_widgets_part.dart`

### exchange_rates

- `lib/features/exchange_rates/presentation/pages/exchange_rate_tile.dart`
- `lib/features/exchange_rates/presentation/pages/exchange_rates_page.dart`

### expenses

- `lib/features/expenses/presentation/pages/expenses_page.dart`
- `lib/features/expenses/presentation/widgets/create_expense_category_dialog.dart`
- `lib/features/expenses/presentation/widgets/create_expense_category_dialog_support.dart`
- `lib/features/expenses/presentation/widgets/create_expense_dialog.dart`
- `lib/features/expenses/presentation/widgets/expenses_backoffice_table.dart`
- `lib/features/expenses/presentation/widgets/expenses_overview_list.dart`

### inventory

- `lib/features/inventory/presentation/pages/inventory_adjustment_dialog_part.dart`
- `lib/features/inventory/presentation/pages/inventory_adjustment_widgets_part.dart`
- `lib/features/inventory/presentation/pages/inventory_batch_packaging_dialog_part.dart`
- `lib/features/inventory/presentation/pages/inventory_batch_product_dialog_part.dart`
- `lib/features/inventory/presentation/pages/inventory_batch_rows_part.dart`
- `lib/features/inventory/presentation/pages/inventory_batch_widgets_part.dart`
- `lib/features/inventory/presentation/pages/inventory_movements_page.dart`
- `lib/features/inventory/presentation/pages/inventory_movements_widgets_part.dart`
- `lib/features/inventory/presentation/pages/inventory_page.dart`
- `lib/features/inventory/presentation/pages/inventory_stock_tables_part.dart`
- `lib/features/inventory/presentation/pages/inventory_stock_tabs_part.dart`

### modifiers

- `lib/features/modifiers/presentation/pages/modifiers_page.dart`
- `lib/features/modifiers/presentation/widgets/modifier_dialogs.dart`
- `lib/features/modifiers/presentation/widgets/modifier_group_actions.dart`
- `lib/features/modifiers/presentation/widgets/modifier_group_tile.dart`
- `lib/features/modifiers/presentation/widgets/modifiers_backoffice_table.dart`

### packaging

- `lib/features/packaging/presentation/pages/packaging_dialogs_part.dart`
- `lib/features/packaging/presentation/pages/packaging_models_part.dart`
- `lib/features/packaging/presentation/pages/packaging_page.dart`
- `lib/features/packaging/presentation/pages/packaging_responsive_dialog_part.dart`
- `lib/features/packaging/presentation/pages/packaging_tab_shell_part.dart`
- `lib/features/packaging/presentation/pages/packaging_tabs_part.dart`

### payment_methods

- `lib/features/payment_methods/presentation/pages/payment_method_tile.dart`
- `lib/features/payment_methods/presentation/pages/payment_methods_page.dart`
- `lib/features/payment_methods/presentation/widgets/create_payment_method_dialog.dart`
- `lib/features/payment_methods/presentation/widgets/payment_methods_backoffice_table.dart`

### pos

- `lib/features/pos/presentation/pages/pos_cash_transactions_detail_part.dart`
- `lib/features/pos/presentation/pages/pos_cash_transactions_page.dart`
- `lib/features/pos/presentation/pages/pos_cash_transactions_table_part.dart`
- `lib/features/pos/presentation/pages/pos_cash_transactions_widgets_part.dart`
- `lib/features/pos/presentation/pages/pos_modifier_availability_page.dart`
- `lib/features/pos/presentation/pages/pos_modifier_availability_widgets.dart`
- `lib/features/pos/presentation/pages/pos_page.dart`
- `lib/features/pos/presentation/pages/pos_register_expense_page.dart`
- `lib/features/pos/presentation/widgets/pos_actions_band.dart`
- `lib/features/pos/presentation/widgets/pos_cart_panel.dart`
- `lib/features/pos/presentation/widgets/pos_catalog_category_tiles_part.dart`
- `lib/features/pos/presentation/widgets/pos_catalog_panel.dart`
- `lib/features/pos/presentation/widgets/pos_catalog_product_tiles_part.dart`
- `lib/features/pos/presentation/widgets/pos_catalog_tiles.dart`
- `lib/features/pos/presentation/widgets/pos_category_band.dart`
- `lib/features/pos/presentation/widgets/pos_checkout_bar.dart`
- `lib/features/pos/presentation/widgets/pos_danger_confirmation.dart`
- `lib/features/pos/presentation/widgets/pos_more_options_actions_part.dart`
- `lib/features/pos/presentation/widgets/pos_more_options_dialog_part.dart`
- `lib/features/pos/presentation/widgets/pos_more_options_enums_part.dart`
- `lib/features/pos/presentation/widgets/pos_more_options_panel.dart`
- `lib/features/pos/presentation/widgets/pos_more_options_salary_advance_dialog_part.dart`
- `lib/features/pos/presentation/widgets/pos_more_options_staff_actions_part.dart`
- `lib/features/pos/presentation/widgets/pos_more_options_staff_consumption_dialog_part.dart`
- `lib/features/pos/presentation/widgets/pos_more_options_widgets_part.dart`
- `lib/features/pos/presentation/widgets/pos_payment_amount_dialog.dart`
- `lib/features/pos/presentation/widgets/pos_payment_flow.dart`
- `lib/features/pos/presentation/widgets/pos_payment_method_selector.dart`
- `lib/features/pos/presentation/widgets/pos_payment_section.dart`
- `lib/features/pos/presentation/widgets/pos_ready_mobile_layout_part.dart`
- `lib/features/pos/presentation/widgets/pos_ready_mobile_tables_launcher_part.dart`
- `lib/features/pos/presentation/widgets/pos_ready_mobile_tables_sheet_part.dart`
- `lib/features/pos/presentation/widgets/pos_ready_state_helpers_part.dart`
- `lib/features/pos/presentation/widgets/pos_ready_view.dart`
- `lib/features/pos/presentation/widgets/pos_responsive_layout.dart`
- `lib/features/pos/presentation/widgets/pos_split_account_name_input.dart`
- `lib/features/pos/presentation/widgets/pos_split_account_payments.dart`
- `lib/features/pos/presentation/widgets/pos_split_accounts_dialog.dart`
- `lib/features/pos/presentation/widgets/pos_split_accounts_header.dart`
- `lib/features/pos/presentation/widgets/pos_split_accounts_items.dart`
- `lib/features/pos/presentation/widgets/pos_split_accounts_workspace.dart`
- `lib/features/pos/presentation/widgets/pos_split_dialog_launcher.dart`
- `lib/features/pos/presentation/widgets/pos_split_dialog_layout.dart`
- `lib/features/pos/presentation/widgets/pos_table_selector.dart`
- `lib/features/pos/presentation/widgets/pos_tables_band.dart`
- `lib/features/pos/presentation/widgets/pos_tables_band_button_part.dart`
- `lib/features/pos/presentation/widgets/pos_tables_band_entry_part.dart`
- `lib/features/pos/presentation/widgets/pos_ticket_exchange_rate_text.dart`
- `lib/features/pos/presentation/widgets/pos_ticket_line_controls.dart`
- `lib/features/pos/presentation/widgets/pos_ticket_panel.dart`
- `lib/features/pos/presentation/widgets/pos_ticket_panel_parts.dart`
- `lib/features/pos/presentation/widgets/pos_ticket_sales_type_controls.dart`
- `lib/features/pos/presentation/widgets/pos_ticket_total_band.dart`
- `lib/features/pos/presentation/widgets/pos_touch_grid.dart`
- `lib/features/pos/presentation/widgets/pos_touch_input_helpers.dart`
- `lib/features/pos/presentation/widgets/product_options_dialog.dart`

### products

- `lib/features/products/presentation/pages/backoffice_products_compact_part.dart`
- `lib/features/products/presentation/pages/backoffice_products_table.dart`
- `lib/features/products/presentation/pages/backoffice_products_table_controls.dart`
- `lib/features/products/presentation/pages/measurement_units_dialog_part.dart`
- `lib/features/products/presentation/pages/measurement_units_page.dart`
- `lib/features/products/presentation/pages/product_tile.dart`
- `lib/features/products/presentation/pages/products_page.dart`
- `lib/features/products/presentation/widgets/create_product_dialog.dart`
- `lib/features/products/presentation/widgets/create_product_dialog_layout_part.dart`
- `lib/features/products/presentation/widgets/create_product_dialog_units_part.dart`
- `lib/features/products/presentation/widgets/modifier_group_selector.dart`
- `lib/features/products/presentation/widgets/product_category_dropdown.dart`
- `lib/features/products/presentation/widgets/product_flags_section.dart`
- `lib/features/products/presentation/widgets/product_option_groups_editor.dart`
- `lib/features/products/presentation/widgets/product_option_groups_editor_draft.dart`
- `lib/features/products/presentation/widgets/product_option_groups_editor_value.dart`
- `lib/features/products/presentation/widgets/product_units_config_dialog.dart`
- `lib/features/products/presentation/widgets/product_units_section.dart`
- `lib/features/products/presentation/widgets/product_units_summary.dart`

### recipes

- `lib/features/recipes/presentation/pages/recipes_page.dart`
- `lib/features/recipes/presentation/widgets/product_recipe_dialog.dart`
- `lib/features/recipes/presentation/widgets/product_recipe_row_card.dart`

### reports

- `lib/features/reports/presentation/pages/inventory_value_report_page.dart`
- `lib/features/reports/presentation/pages/monthly_operational_report_page.dart`
- `lib/features/reports/presentation/pages/negative_inventory_filter_part.dart`
- `lib/features/reports/presentation/pages/negative_inventory_report_page.dart`
- `lib/features/reports/presentation/pages/payroll_payments_report_detail_part.dart`
- `lib/features/reports/presentation/pages/payroll_payments_report_page.dart`
- `lib/features/reports/presentation/pages/payroll_payments_report_widgets_part.dart`
- `lib/features/reports/presentation/pages/reports_cash_closing_page_part.dart`
- `lib/features/reports/presentation/pages/reports_cash_closing_view_part.dart`
- `lib/features/reports/presentation/pages/reports_daily_filter_part.dart`
- `lib/features/reports/presentation/pages/reports_daily_page_part.dart`
- `lib/features/reports/presentation/pages/reports_daily_view_part.dart`
- `lib/features/reports/presentation/pages/reports_expenses_page_part.dart`
- `lib/features/reports/presentation/pages/reports_expenses_view_part.dart`
- `lib/features/reports/presentation/pages/reports_menu_widgets_part.dart`
- `lib/features/reports/presentation/pages/reports_page.dart`
- `lib/features/reports/presentation/pages/reports_product_performance_filters_part.dart`
- `lib/features/reports/presentation/pages/reports_product_performance_page_part.dart`
- `lib/features/reports/presentation/pages/reports_product_performance_view_part.dart`
- `lib/features/reports/presentation/pages/reports_shared_part.dart`
- `lib/features/reports/presentation/pages/salary_advances_report_page.dart`
- `lib/features/reports/presentation/pages/salary_advances_report_widgets_part.dart`
- `lib/features/reports/presentation/pages/vacation_summary_report_page.dart`
- `lib/features/reports/presentation/widgets/inventory_value_mobile_card.dart`
- `lib/features/reports/presentation/widgets/inventory_value_report_widgets.dart`
- `lib/features/reports/presentation/widgets/monthly_operational_period_cuts_widgets.dart`
- `lib/features/reports/presentation/widgets/monthly_operational_report_coverage_widgets.dart`
- `lib/features/reports/presentation/widgets/monthly_operational_report_detail_widgets.dart`
- `lib/features/reports/presentation/widgets/monthly_operational_report_widgets.dart`
- `lib/features/reports/presentation/widgets/report_cash_section.dart`
- `lib/features/reports/presentation/widgets/report_expenses_section.dart`
- `lib/features/reports/presentation/widgets/report_metric_card.dart`
- `lib/features/reports/presentation/widgets/report_period_selector.dart`
- `lib/features/reports/presentation/widgets/report_summary_view.dart`
- `lib/features/reports/presentation/widgets/report_voids_section.dart`

### roles

- `lib/features/roles/presentation/pages/roles_page.dart`
- `lib/features/roles/presentation/widgets/create_role_dialog.dart`

### sales

- `lib/features/sales/presentation/pages/sale_detail_lines_part.dart`
- `lib/features/sales/presentation/pages/sale_detail_page.dart`
- `lib/features/sales/presentation/pages/sale_detail_view_part.dart`
- `lib/features/sales/presentation/pages/sale_detail_widgets_part.dart`
- `lib/features/sales/presentation/pages/sales_page.dart`
- `lib/features/sales/presentation/widgets/sale_invoice_preview_dialog.dart`
- `lib/features/sales/presentation/widgets/sale_tile.dart`
- `lib/features/sales/presentation/widgets/sales_date_selector.dart`
- `lib/features/sales/presentation/widgets/sales_searchable_list.dart`
- `lib/features/sales/presentation/widgets/void_sale_dialog.dart`

### settings

- `lib/features/settings/presentation/pages/settings_page.dart`

### staff

- `lib/features/staff/presentation/pages/staff_admin_pages.dart`
- `lib/features/staff/presentation/pages/staff_business_rules_page_part.dart`
- `lib/features/staff/presentation/pages/staff_business_rules_shifts_part.dart`
- `lib/features/staff/presentation/pages/staff_consumptions_page_part.dart`
- `lib/features/staff/presentation/pages/staff_employees_list_part.dart`
- `lib/features/staff/presentation/pages/staff_employees_page_part.dart`
- `lib/features/staff/presentation/pages/staff_overtime_dialog_part.dart`
- `lib/features/staff/presentation/pages/staff_overtime_page_part.dart`
- `lib/features/staff/presentation/pages/staff_payroll_dialog_part.dart`
- `lib/features/staff/presentation/pages/staff_payroll_models_part.dart`
- `lib/features/staff/presentation/pages/staff_payroll_page_part.dart`
- `lib/features/staff/presentation/pages/staff_payroll_widgets_part.dart`
- `lib/features/staff/presentation/pages/staff_positions_page_part.dart`
- `lib/features/staff/presentation/pages/staff_raw_material_consumptions_dialog_part.dart`
- `lib/features/staff/presentation/pages/staff_raw_material_consumptions_line_part.dart`
- `lib/features/staff/presentation/pages/staff_raw_material_consumptions_page_part.dart`
- `lib/features/staff/presentation/pages/staff_salary_advance_dialog_part.dart`
- `lib/features/staff/presentation/pages/staff_salary_advances_page_part.dart`
- `lib/features/staff/presentation/pages/staff_salary_advances_widgets_part.dart`

### sync

- `lib/features/sync/presentation/pages/sync_page.dart`
- `lib/features/sync/presentation/pages/sync_settings_panel.dart`
- `lib/features/sync/presentation/widgets/sync_queue_tile.dart`

### system

- `lib/features/system/presentation/pages/pilot_operation_reset_actions_part.dart`
- `lib/features/system/presentation/pages/pilot_operation_reset_device_widgets_part.dart`
- `lib/features/system/presentation/pages/pilot_operation_reset_page.dart`
- `lib/features/system/presentation/pages/pilot_operation_reset_widgets_part.dart`

### tables

- `lib/features/tables/presentation/pages/tables_page.dart`
- `lib/features/tables/presentation/widgets/create_table_dialog.dart`

### users

- `lib/features/users/presentation/pages/users_page.dart`
- `lib/features/users/presentation/widgets/create_user_dialog.dart`


## Reglas de cierre

- Confrontar las 222 piezas de presentación de este inventario con `MATRIZ_EXPERIENCIAS.md`, no asumir separación solo por carpeta.
- Marcar widgets compartidos y dependencia real cuando F2/F3 inspeccione importaciones y navegación dinámica.
- Las rutas nominales registradas son la base para los guards; los diálogos y páginas hijas no deben recibir acceso más amplio que su flujo de entrada.
- Diferenciar pantalla protegida por guard Flutter de autorización efectiva en backend (F5).

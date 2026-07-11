import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/design_system/responsive_touch_dialog_frame.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/navigation/app_routes.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/core/theme/app_palette.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:smoo_control/features/auth/presentation/bloc/auth_event.dart';
import 'package:smoo_control/features/cash_register/presentation/widgets/close_cash_register_dialog.dart';
import 'package:smoo_control/features/expenses/domain/entities/operating_expense.dart';
import 'package:smoo_control/features/expenses/domain/repositories/i_expenses_repository.dart';
import 'package:smoo_control/features/modifiers/domain/repositories/i_modifiers_repository.dart';
import 'package:smoo_control/features/packaging/domain/entities/sales_type.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_event.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/pages/pos_cash_transactions_page.dart';
import 'package:smoo_control/features/pos/presentation/pages/pos_modifier_availability_page.dart';
import 'package:smoo_control/features/pos/presentation/pages/pos_register_expense_page.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_danger_confirmation.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_payment_section.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_split_dialog_launcher.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_touch_grid.dart';
import 'package:smoo_control/features/staff/data/repositories/staff_pos_repository.dart';
import 'package:smoo_control/features/staff/domain/entities/business_rule.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';
import 'package:smoo_control/features/staff/domain/entities/salary_advance.dart';
import 'package:smoo_control/features/staff/domain/repositories/i_staff_repository.dart';
import 'package:smoo_control/features/sync/domain/services/i_catalog_pull_service.dart';
import 'package:smoo_control/features/sync/domain/services/sync_scheduler_service.dart';
import 'package:smoo_control/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

part 'pos_more_options_actions_part.dart';
part 'pos_more_options_dialog_part.dart';
part 'pos_more_options_enums_part.dart';
part 'pos_more_options_salary_advance_dialog_part.dart';
part 'pos_more_options_staff_actions_part.dart';
part 'pos_more_options_staff_consumption_dialog_part.dart';
part 'pos_more_options_widgets_part.dart';

const _salaryAdvanceExpenseCategoryId = '33333333-3333-4333-8333-333333333333';

/// Middle bottom POS section reserved for secondary actions.
class PosMoreOptionsPanel extends StatelessWidget
    with
        _PosMoreOptionsDialogMixin,
        _PosMoreOptionsActionsMixin,
        _PosMoreOptionsStaffActionsMixin {
  /// Creates the panel.
  const PosMoreOptionsPanel({
    required this.state,
    this.buttonOnly = false,
    this.compactOperationalMode = false,
    this.onPaymentParentChanged,
    this.paymentParentKey,
    super.key,
  });

  /// Current POS state.
  @override
  final PosReady state;

  /// Whether to render only the tactile button without the grid wrapper.
  final bool buttonOnly;

  /// Whether phone layouts should move POS actions and payments inside.
  @override
  final bool compactOperationalMode;

  /// Current selected payment parent for compact phone payment navigation.
  @override
  final String? paymentParentKey;

  /// Payment navigation change callback for compact phone payment navigation.
  @override
  final ValueChanged<String?>? onPaymentParentChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final button = PosTouchButton(
      icon: Icons.more_horiz,
      label: l10n.moreOptionsAction,
      onPressed: () => _openMoreOptions(context),
      tone: PosButtonTone.neutral,
    );

    if (buttonOnly) return button;

    return PosTouchGrid(
      minTileHeight: 52,
      minTileWidth: 130,
      children: [button],
    );
  }
}

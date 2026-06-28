import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_bloc.dart';
import 'package:smoo_control/features/pos/presentation/bloc/pos_state.dart';
import 'package:smoo_control/features/pos/presentation/widgets/pos_split_accounts_dialog.dart';

/// Opens the split-account workspace with the active POS bloc.
Future<void> showPosSplitAccountsDialog({
  required BuildContext context,
  required PosReady state,
}) {
  final bloc = context.read<PosBloc>();
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: PosSplitAccountsDialog(state: state),
    ),
  );
}

part of 'pos_more_options_panel.dart';

mixin _PosMoreOptionsStaffActionsMixin on StatelessWidget {
  PosReady get state;

  Future<void> registerStaffConsumption(BuildContext context) async {
    final result = await serviceLocator<IStaffRepository>().getEmployees();
    if (!context.mounted) return;
    switch (result) {
      case AppSuccess(:final value):
        final draft =
            await showDialog<({Employee employee, DateTime deliveredAt})>(
              context: context,
              builder: (_) => _EmployeePickerDialog(employees: value),
            );
        if (draft == null || !context.mounted) return;
        context.read<PosBloc>().add(
          PosStaffConsumptionRequested(
            employeeId: draft.employee.id,
            deliveredAt: draft.deliveredAt,
          ),
        );
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }

  Future<void> registerSalaryAdvance(BuildContext context) async {
    final repository = serviceLocator<StaffPosRepository>();
    final employeesResult = await repository.getEmployees();
    final affectsCash = await repository.getBoolRule(
      BusinessRule.salaryAdvancePosAffectsCash,
      defaultValue: false,
    );
    if (!context.mounted) return;

    switch (employeesResult) {
      case AppSuccess(:final value):
        final session = state.openCashRegisterSession;
        if (affectsCash && session == null) {
          await showAppMessageDialog(
            context: context,
            message: 'Abre caja para registrar un adelanto que afecta caja.',
          );
          return;
        }
        final advance = await showDialog<SalaryAdvance>(
          context: context,
          builder: (_) => _SalaryAdvancePosDialog(
            affectsCash: affectsCash,
            cashRegisterSessionId: affectsCash ? session?.id : null,
            employees: value,
          ),
        );
        if (advance == null || !context.mounted) return;
        final result = await repository.saveSalaryAdvance(advance);
        if (!context.mounted) return;
        switch (result) {
          case AppSuccess():
            if (advance.affectsCash) {
              final expenseResult = await _saveSalaryAdvanceCashExpense(
                advance,
              );
              if (!context.mounted) return;
              switch (expenseResult) {
                case AppSuccess():
                  break;
                case AppFailureResult(:final error):
                  await showAppMessageDialog(
                    context: context,
                    message: error.message,
                  );
                  return;
              }
            }
            if (!context.mounted) return;
            await showAppMessageDialog(
              context: context,
              message: 'Adelanto registrado.',
            );
          case AppFailureResult(:final error):
            await showAppMessageDialog(
              context: context,
              message: error.message,
            );
        }
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }

  Future<AppResult<OperatingExpense>> _saveSalaryAdvanceCashExpense(
    SalaryAdvance advance,
  ) {
    final note = advance.note?.trim();
    return serviceLocator<IExpensesRepository>().saveExpense(
      OperatingExpense(
        id: const Uuid().v4(),
        categoryId: _salaryAdvanceExpenseCategoryId,
        cashRegisterSessionId: advance.cashRegisterSessionId,
        kind: OperatingExpenseKind.salaryAdvance,
        employeeId: advance.employeeId,
        amountInCents: advance.amountInCents,
        description: note == null || note.isEmpty
            ? 'Adelanto de salario'
            : 'Adelanto de salario - $note',
        createdBy: advance.createdBy,
        createdAt: advance.createdAt,
      ),
    );
  }
}

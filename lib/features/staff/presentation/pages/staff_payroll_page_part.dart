part of 'staff_admin_pages.dart';

/// Admin page for pending payroll payments.
class PayrollPage extends StatefulWidget {
  /// Creates the page.
  const PayrollPage({super.key});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  late Future<
    ({
      List<Employee> employees,
      List<StaffConsumption> consumptions,
      List<SalaryAdvance> advances,
      List<PayrollPendingLine> pendingLines,
    })
  >
  _future;

  SupabaseStaffAdminRepository get _repository =>
      serviceLocator<SupabaseStaffAdminRepository>();

  late final _PayrollPeriod _period = _currentPayrollPeriod(DateTime.now());

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<
    ({
      List<Employee> employees,
      List<StaffConsumption> consumptions,
      List<SalaryAdvance> advances,
      List<PayrollPendingLine> pendingLines,
    })
  >
  _load() async {
    final employees = await _repository.getEmployees();
    final consumptions = await _repository.getStaffConsumptions();
    final advances = await _repository.getSalaryAdvances();
    final pendingLines = await _repository.getPendingPayrollLines();
    return (
      employees: switch (employees) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
      consumptions: switch (consumptions) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
      advances: switch (advances) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
      pendingLines: switch (pendingLines) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Planilla',
      body:
          FutureBuilder<
            ({
              List<Employee> employees,
              List<StaffConsumption> consumptions,
              List<SalaryAdvance> advances,
              List<PayrollPendingLine> pendingLines,
            })
          >(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppEmptyState(
                  icon: Icons.summarize_outlined,
                  title: 'Planilla',
                  message: snapshot.error.toString(),
                );
              }
              if (!snapshot.hasData) return const AppLoadingPage();
              final data = snapshot.requireData;
              return _PayrollDraftList(
                advances: data.advances,
                consumptions: data.consumptions,
                employees: data.employees,
                pendingLines: data.pendingLines,
                period: _period,
                onPay: _payEmployee,
              );
            },
          ),
    );
  }

  Future<void> _payEmployee(_PayrollPayRequest request) async {
    final deduction = await showDialog<int>(
      context: context,
      builder: (_) => _PayrollPaymentDialog(request: request),
    );
    if (deduction == null || !mounted) return;
    final entry = request.entry;
    final result = await _repository.postPayrollEmployee(
      employeeId: entry.employeeId,
      periodStart: entry.periodStart,
      periodEnd: entry.periodEnd,
      baseSalaryInCents: entry.baseSalaryInCents,
      consumptionInCents: entry.consumptionInCents,
      salaryAdvanceDeductionInCents: deduction,
      paymentAmountInCents: request.paymentAmountInCents,
    );
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        setState(() => _future = _load());
      case AppFailureResult(:final error):
        await showAppMessageDialog(context: context, message: error.message);
    }
  }
}

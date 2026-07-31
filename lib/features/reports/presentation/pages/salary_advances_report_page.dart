import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/staff/data/repositories/supabase_staff_admin_repository.dart';
import 'package:smoo_control/features/staff/domain/entities/employee.dart';
import 'package:smoo_control/features/staff/domain/entities/salary_advance.dart';

part 'salary_advances_report_widgets_part.dart';

/// Historical salary advances report.
class SalaryAdvancesReportPage extends StatefulWidget {
  /// Creates the report.
  const SalaryAdvancesReportPage({super.key});

  @override
  State<SalaryAdvancesReportPage> createState() =>
      _SalaryAdvancesReportPageState();
}

class _SalaryAdvancesReportPageState extends State<SalaryAdvancesReportPage> {
  final _search = TextEditingController();
  late DateTime _from;
  late Future<({List<Employee> employees, List<SalaryAdvance> advances})>
  _future;
  var _grouped = true;
  var _status = 'paid';
  late DateTime _to;
  String _query = '';

  SupabaseStaffAdminRepository get _repository =>
      serviceLocator<SupabaseStaffAdminRepository>();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month);
    _to = DateTime(now.year, now.month, now.day);
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Reporte de adelantos',
      body: Column(
        children: [
          _SalaryAdvanceReportFilters(
            from: _from,
            grouped: _grouped,
            onChanged: _selectRange,
            onGroupedChanged: (value) => setState(() => _grouped = value),
            onReload: () => setState(() => _future = _load()),
            onStatusChanged: _setStatus,
            status: _status,
            to: _to,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar empleado, fecha o monto',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child:
                FutureBuilder<
                  ({List<Employee> employees, List<SalaryAdvance> advances})
                >(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return AppEmptyState(
                        icon: Icons.payments_outlined,
                        title: 'No se pudo cargar',
                        message: snapshot.error.toString(),
                      );
                    }
                    if (!snapshot.hasData) return const AppLoadingPage();
                    return _SalaryAdvanceReportBody(
                      advances: _filtered(snapshot.requireData),
                      employees: snapshot.requireData.employees,
                      grouped: _grouped,
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Future<({List<Employee> employees, List<SalaryAdvance> advances})>
  _load() async {
    final employees = await _repository.getEmployees();
    final advances = await _repository.getSalaryAdvances(
      from: _from,
      statuses: _status == 'all' ? null : [_status],
      to: _to,
    );
    return (
      employees: switch (employees) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
      advances: switch (advances) {
        AppSuccess(:final value) => value,
        AppFailureResult(:final error) => throw StateError(error.message),
      },
    );
  }

  List<SalaryAdvance> _filtered(
    ({List<Employee> employees, List<SalaryAdvance> advances}) data,
  ) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return data.advances;
    final employees = {
      for (final employee in data.employees) employee.id: employee,
    };
    return data.advances.where((advance) {
      final employee = employees[advance.employeeId];
      final balance = advance.balanceInCents ?? advance.amountInCents;
      final values = [
        employee?.fullName ?? '',
        employee?.code ?? '',
        _dateOnly(advance.deliveredAt),
        _statusLabel(advance.status),
        MoneyFormatter.format(advance.amountInCents),
        MoneyFormatter.format(advance.amountInCents - balance),
        MoneyFormatter.format(balance),
      ].join(' ').toLowerCase();
      return values.contains(query);
    }).toList();
  }

  void _selectRange(DateTimeRange range) {
    setState(() {
      _from = range.start;
      _to = range.end;
      _future = _load();
    });
  }

  void _setStatus(String value) {
    setState(() {
      _status = value;
      _future = _load();
    });
  }
}

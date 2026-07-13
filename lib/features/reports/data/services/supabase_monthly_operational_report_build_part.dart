part of 'supabase_monthly_operational_report_service.dart';

extension _MonthlyOperationalReportBuilder
    on SupabaseMonthlyOperationalReportService {
  MonthlyOperationalReport _buildReport({
    required int advancesDeliveredInCents,
    required Map<String, _ExpenseCategory> categories,
    required List<_RemoteExpense> expenses,
    required DateTime from,
    required _PayrollTotals payroll,
    required int pendingStaffConsumptionInCents,
    required List<_RemoteSaleItem> saleItems,
    required List<_RemoteSale> sales,
    required DateTime to,
  }) {
    final dateBySaleId = {for (final sale in sales) sale.id: sale.date};
    final salesByDate = <DateTime, _DailyAccumulator>{};
    final expensesByCategory = <String, int>{};
    var excludedExpenses = 0;
    var totalCost = 0;

    for (final sale in sales) {
      salesByDate.putIfAbsent(sale.date, _DailyAccumulator.new).sales +=
          sale.totalInCents;
    }
    for (final item in saleItems) {
      final date = dateBySaleId[item.saleId];
      if (date == null) continue;
      salesByDate.putIfAbsent(date, _DailyAccumulator.new).cost +=
          item.costInCents;
      totalCost += item.costInCents;
    }
    for (final expense in expenses) {
      final category = categories[expense.categoryId];
      if (category?.includeInCoverage != true) {
        excludedExpenses += expense.amountInCents;
        continue;
      }
      salesByDate.putIfAbsent(expense.date, _DailyAccumulator.new).expenses +=
          expense.amountInCents;
      final name = _categoryPath(category, categories);
      expensesByCategory.update(
        name ?? 'Sin categoria',
        (current) => current + expense.amountInCents,
        ifAbsent: () => expense.amountInCents,
      );
    }

    final dailyRows = _dailyRows(salesByDate);
    final coverageRows = _coverageRows(
      actualByCategory: _actualByCategory(expenses, categories),
      categories: categories,
      from: from,
      to: to,
    );

    return MonthlyOperationalReport(
      advancesDeliveredInCents: advancesDeliveredInCents,
      consideredExpensesByCategory: _expenseRows(expensesByCategory),
      coverageRows: coverageRows,
      dailyRows: dailyRows,
      excludedExpensesInCents: excludedExpenses,
      from: from,
      payrollBalanceInCents: payroll.balance,
      payrollNetInCents: payroll.net,
      payrollPaidInCents: payroll.paid,
      pendingStaffConsumptionInCents: pendingStaffConsumptionInCents,
      periodCuts: _periodCuts(
        coverageRows: coverageRows,
        dailyRows: dailyRows,
        from: from,
        payroll: payroll,
        to: to,
      ),
      totalCostInCents: totalCost,
      totalSalesInCents: sales.fold(0, (sum, sale) => sum + sale.totalInCents),
      to: to,
    );
  }

  List<MonthlyOperationalPeriodCut> _periodCuts({
    required List<MonthlyOperationalCoverageRow> coverageRows,
    required List<MonthlyOperationalDailyRow> dailyRows,
    required DateTime from,
    required _PayrollTotals payroll,
    required DateTime to,
  }) {
    final firstEnd = DateTime(from.year, from.month, 15);
    final monthEnd = DateTime(from.year, from.month + 1, 0);
    final first = _periodCut(
      coverageRows: coverageRows,
      dailyRows: dailyRows,
      from: from,
      labelKey: 'first_half',
      payroll: _halfPayroll(payroll),
      to: to.isBefore(firstEnd) ? to : firstEnd,
    );
    final secondStart = DateTime(from.year, from.month, 16);
    final secondFrom = from.isAfter(secondStart) ? from : secondStart;
    final secondTo = to.isBefore(monthEnd) ? to : monthEnd;
    final second = secondTo.isBefore(secondFrom)
        ? null
        : _periodCut(
            coverageRows: coverageRows,
            dailyRows: dailyRows,
            from: secondFrom,
            labelKey: 'second_half',
            payroll: payroll.net - _halfPayroll(payroll),
            to: secondTo,
          );
    return [first, ?second];
  }

  MonthlyOperationalPeriodCut _periodCut({
    required List<MonthlyOperationalCoverageRow> coverageRows,
    required List<MonthlyOperationalDailyRow> dailyRows,
    required DateTime from,
    required String labelKey,
    required int payroll,
    required DateTime to,
  }) {
    final grossProfit = dailyRows
        .where((row) => !row.date.isBefore(from) && !row.date.isAfter(to))
        .fold(0, (total, row) => total + row.grossProfitInCents);
    final coverage = coverageRows.fold(
      0,
      (total, row) => total + _periodCoverage(row, from, to),
    );
    return MonthlyOperationalPeriodCut(
      from: from,
      grossProfitInCents: grossProfit,
      labelKey: labelKey,
      obligationInCents: coverage + payroll,
      pendingDisbursementInCents: coverage + payroll,
      to: to,
    );
  }

  int _periodCoverage(
    MonthlyOperationalCoverageRow row,
    DateTime from,
    DateTime to,
  ) {
    if (row.dueDays.isEmpty) return row.obligationInCents;
    final dueInPeriod = row.dueDays.any((day) {
      final safeDay = day.clamp(1, DateTime(from.year, from.month + 1, 0).day);
      final due = DateTime(from.year, from.month, safeDay);
      return !due.isBefore(from) && !due.isAfter(to);
    });
    return dueInPeriod ? row.obligationInCents : 0;
  }

  int _halfPayroll(_PayrollTotals payroll) => (payroll.net / 2).round();

  Map<String, int> _actualByCategory(
    List<_RemoteExpense> expenses,
    Map<String, _ExpenseCategory> categories,
  ) {
    final result = <String, int>{};
    for (final expense in expenses) {
      final category = categories[expense.categoryId];
      if (category == null || !category.includeInCoverage) continue;
      result.update(
        category.id,
        (current) => current + expense.amountInCents,
        ifAbsent: () => expense.amountInCents,
      );
    }
    return result;
  }

  List<MonthlyOperationalCoverageRow> _coverageRows({
    required Map<String, int> actualByCategory,
    required Map<String, _ExpenseCategory> categories,
    required DateTime from,
    required DateTime to,
  }) {
    return categories.values
        .where((category) => category.includeInCoverage)
        .where((category) => category.coverageIsActive)
        .map((category) {
          return MonthlyOperationalCoverageRow(
            actualInCents: actualByCategory[category.id] ?? 0,
            categoryName: _categoryPath(category, categories) ?? category.name,
            dueDays: category.coverageDueDays,
            frequencyLabel: category.coverageFrequency ?? '',
            projectedInCents: _projectedAmount(category, from, to),
            typeLabel: category.coverageType ?? '',
          );
        })
        .toList()
      ..sort((a, b) => a.categoryName.compareTo(b.categoryName));
  }

  int _projectedAmount(_ExpenseCategory category, DateTime from, DateTime to) {
    final amount = category.coverageEstimatedAmountInCents ?? 0;
    if (amount <= 0) return 0;
    return switch (category.coverageFrequency) {
      'weekly' => amount * _weeklyOccurrences(from, to),
      'biweekly' => amount * _dueDayOccurrences(category, from, to),
      'monthly' => amount * _dueDayOccurrences(category, from, to),
      _ => amount,
    };
  }

  List<MonthlyOperationalDailyRow> _dailyRows(
    Map<DateTime, _DailyAccumulator> byDate,
  ) {
    return byDate.entries
        .map(
          (entry) => MonthlyOperationalDailyRow(
            date: entry.key,
            expensesInCents: entry.value.expenses,
            grossProfitInCents: entry.value.sales - entry.value.cost,
            salesInCents: entry.value.sales,
          ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<MonthlyOperationalExpenseRow> _expenseRows(Map<String, int> values) {
    return values.entries
        .map(
          (entry) => MonthlyOperationalExpenseRow(
            categoryName: entry.key,
            totalInCents: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.totalInCents.compareTo(a.totalInCents));
  }

  String? _categoryPath(
    _ExpenseCategory? category,
    Map<String, _ExpenseCategory> categories,
  ) {
    if (category == null) return null;
    final parent = category.parentId == null
        ? null
        : categories[category.parentId];
    if (parent == null) return category.name;
    return '${parent.name} / ${category.name}';
  }

  int _dueDayOccurrences(
    _ExpenseCategory category,
    DateTime from,
    DateTime to,
  ) {
    final dueDays = category.coverageDueDays;
    if (dueDays.isEmpty) return 1;
    var count = 0;
    for (final day in dueDays) {
      final safeDay = day.clamp(1, DateTime(from.year, from.month + 1, 0).day);
      final due = DateTime(from.year, from.month, safeDay);
      if (!due.isBefore(from) && !due.isAfter(to)) count++;
    }
    return count == 0 ? 0 : count;
  }

  int _weeklyOccurrences(DateTime from, DateTime to) {
    final days = to.difference(from).inDays + 1;
    return (days / 7).ceil();
  }
}

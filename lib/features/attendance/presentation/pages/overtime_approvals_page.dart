import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/design_system/app_text.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/formatters/money_formatter.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/features/attendance/domain/entities/overtime_candidate.dart';
import 'package:smoo_control/features/attendance/domain/repositories/i_attendance_repository.dart';

/// Approval inbox for overtime calculated from attendance.
final class OvertimeApprovalsPage extends StatefulWidget {
  /// Creates the overtime approval page.
  const OvertimeApprovalsPage({super.key});

  @override
  State<OvertimeApprovalsPage> createState() => _OvertimeApprovalsPageState();
}

class _OvertimeApprovalsPageState extends State<OvertimeApprovalsPage> {
  final IAttendanceRepository _repository =
      serviceLocator<IAttendanceRepository>();
  late DateTime _from;
  late DateTime _to;
  List<OvertimeCandidate>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month);
    _to = DateTime(now.year, now.month, now.day);
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Horas extra por autorizar',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.calendar_month_outlined),
                label: Text('Desde ${_fmt(_from)}'),
                onPressed: () => _pickDate(isFrom: true),
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_month_outlined),
                label: Text('Hasta ${_fmt(_to)}'),
                onPressed: () => _pickDate(isFrom: false),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Recargar'),
                onPressed: _load,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            AppEmptyState(
              icon: Icons.error_outline,
              message: _error!,
              title: 'Horas extra',
            )
          else if (_items == null)
            const AppLoadingPage()
          else if (_items!.isEmpty)
            const AppEmptyState(
              icon: Icons.more_time_outlined,
              message: 'No hay horas extra pendientes.',
              title: 'Sin pendientes',
            )
          else
            for (final item in _items!) _CandidateCard(item: item, act: _act),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    final result = await _repository.getOvertimeCandidates(
      from: _from,
      status: 'pending',
      to: _to,
    );
    if (!mounted) return;
    switch (result) {
      case AppSuccess(:final value):
        setState(() => _items = value);
      case AppFailureResult(:final error):
        setState(() => _error = error.message);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      initialDate: isFrom ? _from : _to,
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _act(OvertimeCandidate item, {required bool approve}) async {
    final result = approve
        ? await _repository.approveOvertimeCandidate(item.id)
        : await _repository.rejectOvertimeCandidate(item.id);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Hora extra autorizada.' : 'Hora extra rechazada.',
            ),
          ),
        );
        await _load();
      case AppFailureResult(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
    }
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.item, required this.act});

  final OvertimeCandidate item;
  final Future<void> Function(OvertimeCandidate item, {required bool approve})
  act;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              '${item.employeeName} | ${_fmt(item.workedDate)}',
              variant: AppTextVariant.titleMedium,
            ),
            const SizedBox(height: 8),
            _Row(label: 'Horas', value: item.hours.toStringAsFixed(2)),
            _Row(
              label: 'Monto',
              value: MoneyFormatter.format(item.totalInCents),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => unawaited(act(item, approve: false)),
                  child: const Text('Rechazar'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Autorizar'),
                  onPressed: () => unawaited(act(item, approve: true)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AppText(label)),
        AppText(value, variant: AppTextVariant.label),
      ],
    );
  }
}

String _fmt(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

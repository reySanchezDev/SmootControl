import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smoo_control/core/design_system/app_empty_state.dart';
import 'package:smoo_control/core/design_system/app_loading_page.dart';
import 'package:smoo_control/core/design_system/app_message_dialog.dart';
import 'package:smoo_control/core/design_system/app_page_scaffold.dart';
import 'package:smoo_control/core/di/service_locator.dart';
import 'package:smoo_control/core/result/app_result.dart';
import 'package:smoo_control/core/session/current_operator_service.dart';
import 'package:smoo_control/features/admin_remote/data/repositories/supabase_admin_repository.dart';
import 'package:smoo_control/features/sales/data/repositories/supabase_sales_admin_repository.dart';
import 'package:smoo_control/features/sales/domain/entities/sale.dart';
import 'package:smoo_control/features/sales/domain/entities/sale_item.dart';
import 'package:smoo_control/features/sales/domain/repositories/i_sales_repository.dart';
import 'package:smoo_control/features/sales/domain/services/sale_invoice_pdf_service.dart';
import 'package:smoo_control/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:smoo_control/features/sales/presentation/bloc/sales_event.dart';
import 'package:smoo_control/features/sales/presentation/bloc/sales_state.dart';
import 'package:smoo_control/features/sales/presentation/pages/sale_detail_page.dart';
import 'package:smoo_control/features/sales/presentation/widgets/sale_invoice_preview_dialog.dart';
import 'package:smoo_control/features/sales/presentation/widgets/sales_date_selector.dart';
import 'package:smoo_control/features/sales/presentation/widgets/sales_searchable_list.dart';
import 'package:smoo_control/features/sales/presentation/widgets/void_sale_dialog.dart';
import 'package:smoo_control/features/settings/domain/entities/business_settings.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Daily sales and transaction page.
class SalesPage extends StatefulWidget {
  /// Creates the sales page.
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  late final SalesBloc _bloc;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _bloc = serviceLocator<SalesBloc>();
    _selectedDate = _dateOnly(DateTime.now());
    _loadSelectedDate();
  }

  @override
  void dispose() {
    unawaited(_bloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider.value(
      value: _bloc,
      child: AppPageScaffold(
        title: l10n.moduleSales,
        body: BlocConsumer<SalesBloc, SalesState>(
          listener: (context, state) {
            if (state is SaleVoidSuccess) {
              unawaited(
                showAppMessageDialog(
                  context: context,
                  message: l10n.saleVoidedMessage,
                  title: l10n.moduleSales,
                ),
              );
              _loadSelectedDate();
            }
          },
          builder: _buildBody,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SalesState state) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        SalesDateSelector(
          selectedDate: _selectedDate,
          onChanged: _changeSelectedDate,
        ),
        Expanded(child: _buildContent(context, state, l10n)),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    SalesState state,
    AppLocalizations l10n,
  ) {
    return switch (state) {
      SalesInitial() || SalesLoading() => const AppLoadingPage(),
      SalesFailure(:final failure) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AppEmptyState(
            icon: Icons.error_outline,
            message: failure.message,
            title: l10n.moduleSales,
          ),
        ),
      ),
      SalesLoaded(:final sales) when sales.isEmpty => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AppEmptyState(
            icon: Icons.receipt_long_outlined,
            message: l10n.emptySalesMessage,
            title: l10n.emptySalesTitle,
          ),
        ),
      ),
      SalesLoaded(:final sales) => SalesSearchableList(
        sales: sales,
        onOpenDetails: _openDetail,
        onPreviewPdf: _previewPdf,
        onVoid: _voidSale,
      ),
      SaleItemsLoaded() ||
      SaleSaveSuccess() ||
      SaleVoidSuccess() => const AppLoadingPage(),
    };
  }

  void _changeSelectedDate(DateTime date) {
    setState(() {
      _selectedDate = _dateOnly(date);
    });
    _loadSelectedDate();
  }

  void _loadSelectedDate() {
    final range = _dateRangeFor(_selectedDate);
    _bloc.add(SalesLoadRequested(from: range.from, to: range.to));
  }

  Future<void> _previewPdf(BuildContext context, Sale sale) async {
    final l10n = AppLocalizations.of(context);
    final salesRepository = serviceLocator<SupabaseSalesAdminRepository>();
    final adminRepository = serviceLocator<SupabaseAdminRepository>();
    final pdfService = serviceLocator<SaleInvoicePdfService>();

    final items = await _loadSaleItems(salesRepository, sale.id);
    if (items == null) {
      if (context.mounted) {
        _showPdfError(context, l10n);
      }
      return;
    }

    final settings = await _loadSettings(adminRepository);
    final paymentMethodName = await _loadPaymentMethodName(
      adminRepository,
      sale.paymentMethodId,
      l10n.paymentMethodField,
    );

    final bytes = await pdfService.buildPdf(
      sale: sale,
      items: items,
      settings: settings,
      paymentMethodName: paymentMethodName,
    );

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => SaleInvoicePreviewDialog(
        bytes: bytes,
        filename: '${sale.invoiceNumber}.pdf',
      ),
    );
  }

  void _openDetail(BuildContext context, Sale sale) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SaleDetailPage(sale: sale),
        ),
      ),
    );
  }

  Future<void> _voidSale(BuildContext context, Sale sale) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const VoidSaleDialog(),
    );

    if (reason == null || !context.mounted) {
      return;
    }

    context.read<SalesBloc>().add(
      SaleVoided(
        saleId: sale.id,
        reason: reason,
        voidedBy: serviceLocator<CurrentOperatorService>().userId,
      ),
    );
  }

  Future<List<SaleItem>?> _loadSaleItems(
    ISalesRepository repository,
    String saleId,
  ) async {
    final result = await repository.getSaleItems(saleId);

    return switch (result) {
      AppSuccess(:final value) => value,
      AppFailureResult() => null,
    };
  }

  Future<BusinessSettings> _loadSettings(
    SupabaseAdminRepository repository,
  ) async {
    final result = await repository.getSettings();

    return switch (result) {
      AppSuccess(:final value) => value,
      AppFailureResult() => BusinessSettings.empty,
    };
  }

  Future<String> _loadPaymentMethodName(
    SupabaseAdminRepository repository,
    String paymentMethodId,
    String fallback,
  ) async {
    final result = await repository.getPaymentMethods();

    if (result case AppSuccess(:final value)) {
      for (final method in value) {
        if (method.id == paymentMethodId) {
          return method.name;
        }
      }
    }

    return fallback;
  }

  void _showPdfError(BuildContext context, AppLocalizations l10n) {
    unawaited(
      showAppMessageDialog(
        context: context,
        message: l10n.pdfGenerationError,
        title: l10n.moduleSales,
      ),
    );
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  _DateRange _dateRangeFor(DateTime date) {
    final from = _dateOnly(date);

    return _DateRange(from: from, to: from.add(const Duration(days: 1)));
  }
}

class _DateRange {
  const _DateRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;
}

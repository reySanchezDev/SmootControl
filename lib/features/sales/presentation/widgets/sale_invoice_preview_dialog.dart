import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:smoo_control/l10n/app_localizations.dart';

/// Dialog that previews a sale invoice PDF before printing or sharing it.
class SaleInvoicePreviewDialog extends StatelessWidget {
  /// Creates a sale invoice preview dialog.
  const SaleInvoicePreviewDialog({
    required this.bytes,
    required this.filename,
    super.key,
  });

  /// PDF bytes to preview.
  final Uint8List bytes;

  /// Default filename used by the printing/share controls.
  final String filename;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final isCompact = mediaSize.width < 600;
    final l10n = AppLocalizations.of(context);

    final preview = PdfPreview(
      canChangeOrientation: false,
      canChangePageFormat: false,
      pdfFileName: filename,
      build: (_) async => bytes,
    );

    if (isCompact) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.invoicePreviewTitle),
          ),
          body: preview,
        ),
      );
    }

    return Dialog(
      child: SizedBox(
        height: mediaSize.height * 0.86,
        width: mediaSize.width.clamp(600, 960).toDouble(),
        child: Column(
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: Text(l10n.invoicePreviewTitle),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: l10n.cancelAction,
                ),
              ],
            ),
            Expanded(child: preview),
          ],
        ),
      ),
    );
  }
}

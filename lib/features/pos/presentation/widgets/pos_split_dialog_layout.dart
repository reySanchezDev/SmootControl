part of 'pos_split_accounts_dialog.dart';

final class _SplitDialogLayout {
  const _SplitDialogLayout({
    required this.accountPanelWidth,
    required this.compact,
    required this.originalPanelWidth,
    required this.stacked,
  });

  factory _SplitDialogLayout.fromSize(double width, double height) {
    final usableWidth = width - 28;
    final stacked = width < 760 || height < 620;
    final targetWidth = stacked
        ? usableWidth.clamp(280.0, 430.0)
        : ((usableWidth - 16) / 3).clamp(250.0, 390.0);
    final compact = targetWidth < 300;
    return _SplitDialogLayout(
      accountPanelWidth: targetWidth,
      compact: compact,
      originalPanelWidth: targetWidth,
      stacked: stacked,
    );
  }

  final double accountPanelWidth;
  final bool compact;
  final double originalPanelWidth;
  final bool stacked;
}

part of 'packaging_page.dart';

class _ResponsiveDialog extends StatelessWidget {
  const _ResponsiveDialog({
    required this.children,
    required this.onSave,
    required this.title,
  });

  final List<Widget> children;
  final VoidCallback onSave;
  final String title;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      title: AppText(title, variant: AppTextVariant.titleMedium),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width < 520 ? width * 0.92 : 420),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          onPressed: () => Navigator.of(context).pop(),
          primary: false,
        ),
        AppButton(label: 'Guardar', onPressed: onSave),
      ],
    );
  }
}

part of 'canonical_items_content.dart';

extension _CanonicalItemsContentActions on _CanonicalItemsContentState {
  Future<void> _recipe(CanonicalItem selected) async {
    if (_busy ||
        selected.id == null ||
        selected.type == CanonicalItemType.service) {
      return;
    }
    setState(() => _busy = true);
    try {
      final catalog = await _repository.getCanonicalItems();
      final units = await _repository.getMeasurementUnits();
      final existing = await _repository.loadCanonicalRecipe(selected.id!);
      if (!mounted) return;
      if (catalog case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      if (units case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      if (existing case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      final result = await showDialog<bool>(
        context: context,
        builder: (_) => CanonicalRecipeDialog(
          item: selected,
          items: (catalog as AppSuccess<List<CanonicalItem>>).value,
          units: (units as AppSuccess<List<MeasurementUnit>>).value,
          existing: (existing as AppSuccess<CanonicalRecipe?>).value,
        ),
      );
      if (result ?? false) {
        if (mounted) _refresh();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _packagingRules(CanonicalItem selected) async {
    if (_busy || !selected.canSell) return;
    setState(() => _busy = true);
    try {
      final catalog = await _repository.getCanonicalItems();
      final saleTypes = await _repository.getSalesTypes();
      final rules = await _repository.getCanonicalConsumptionRules();
      if (!mounted) return;
      if (catalog case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      if (saleTypes case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      if (rules case AppFailureResult(:final error)) {
        _error(error.message);
        return;
      }
      final result = await showDialog<bool>(
        context: context,
        builder: (_) => CanonicalPackagingRulesDialog(
          source: selected,
          items: (catalog as AppSuccess<List<CanonicalItem>>).value,
          salesTypes: (saleTypes as AppSuccess<List<SalesType>>).value,
          rules: (rules as AppSuccess<List<CanonicalConsumptionRule>>).value,
        ),
      );
      if (result ?? false) {
        if (mounted) _refresh();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(String message) {
    if (!mounted) return;
    BackofficeActionFeedback.show(
      context,
      outcome: BackofficeActionOutcome.error,
      message: message,
    );
  }
}

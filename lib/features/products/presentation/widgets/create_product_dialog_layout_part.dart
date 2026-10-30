part of 'create_product_dialog.dart';

/// Responsive editor composition, separated from validation and persistence.
extension _CreateProductDialogLayout on _CreateProductDialogState {
  Widget buildProductForm(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final height = MediaQuery.sizeOf(context).height;
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestClose());
      },
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 760, maxHeight: height - 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppText(
                      widget.product == null
                          ? l10n.createProductTitle
                          : l10n.editProductTitle,
                      variant: AppTextVariant.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppButton(
                          label: l10n.cancelAction,
                          onPressed: _requestClose,
                          primary: false,
                        ),
                        AppButton(
                          label: l10n.saveAction,
                          icon: Icons.save_outlined,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppInput(
                        label: l10n.nameField,
                        controller: _nameController,
                        focusNode: _nameFocus,
                        requiredField: true,
                        errorText: _showValidation &&
                                _nameController.text.trim().isEmpty
                            ? l10n.fieldRequiredError
                            : null,
                      ),
                      const SizedBox(height: 16),
                      ProductCategoryDropdown(
                        categories: widget.categories,
                        selectedCategoryId: _selectedCategoryId,
                        focusNode: _categoryFocus,
                        onChanged: (value) {
                          _updateForm(() {
                            _selectedCategoryId = value;
                            _error = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: l10n.priceInCentsField,
                        controller: _priceController,
                        focusNode: _priceFocus,
                        requiredField: !_isRawMaterial,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppInput(
                        label: costFieldLabel(l10n),
                        controller: _costController,
                        focusNode: _costFocus,
                        requiredField: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ProductFlagsSection(
                        isActive: _isActive,
                        isAvailableInPos: _isAvailableInPos,
                        isRawMaterial: _isRawMaterial,
                        usesRecipe: _usesRecipe,
                        tracksInventory: _tracksInventory,
                        onActiveChanged: (v) => _updateForm(() => _isActive = v),
                        onAvailableInPosChanged: (v) =>
                            _updateForm(() => _isAvailableInPos = v),
                        onRawMaterialChanged: (v) => _updateForm(() {
                          _isRawMaterial = v;
                          if (v) {
                            _isAvailableInPos = false;
                            _usesRecipe = false;
                          }
                        }),
                        onUsesRecipeChanged: (v) =>
                            _updateForm(() => _usesRecipe = v),
                        onTracksInventoryChanged: (v) =>
                            _updateForm(() => _tracksInventory = v),
                      ),
                      if (_tracksInventory) ...[
                        const SizedBox(height: 12),
                        ProductUnitsSummary(
                          factor: _purchaseFactorController.text.trim(),
                          inventoryUnitName: unitName(_inventoryUnitId),
                          onConfigure: openUnitsDialog,
                          purchaseUnitName: unitName(_purchaseUnitId),
                          recipeUnitName: unitName(_recipeDefaultUnitId),
                          displayUnitName: unitName(_inventoryDisplayUnitId),
                        ),
                      ],
                      ModifierGroupSelector(
                        groups: _activeModifierGroups,
                        selectedIds: _selectedModifierGroupIds,
                        onChanged: (id, {required selected}) {
                          _updateForm(() {
                            if (selected) {
                              _selectedModifierGroupIds.add(id);
                            } else {
                              _selectedModifierGroupIds.remove(id);
                            }
                            _error = null;
                          });
                        },
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: AppText(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

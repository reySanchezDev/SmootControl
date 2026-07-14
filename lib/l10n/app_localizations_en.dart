// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SmooControl';

  @override
  String get dashboardTitle => 'Operations dashboard';

  @override
  String get dashboardSubtitle =>
      'Initial foundation ready for sales, cash register, expenses, and sync.';

  @override
  String get primaryAction => 'Open POS';

  @override
  String get secondaryAction => 'View reports';

  @override
  String get signOutAction => 'Sign out';

  @override
  String get trackingStatus => 'Project status';

  @override
  String get trackingStatusValue => 'Foundation in progress';

  @override
  String get offlineFirst => 'Offline-first';

  @override
  String get offlineFirstValue =>
      'The app will store sales and expenses locally before syncing.';

  @override
  String get responsiveReady => 'Responsive';

  @override
  String get responsiveReadyValue =>
      'Designed for mobile, tablet, and web from day one.';

  @override
  String get moduleCatalog => 'Categories';

  @override
  String get moduleProducts => 'Products';

  @override
  String get moduleModifiers => 'POS modifiers';

  @override
  String get modulePaymentMethods => 'Payment methods';

  @override
  String get moduleTables => 'Tables';

  @override
  String get moduleSales => 'Sales';

  @override
  String get moduleCashRegister => 'Daily cash register';

  @override
  String get cashRegisterAdminTitle => 'Cash register transactions';

  @override
  String get cashRegisterAdminEmpty =>
      'There are no cash registers in this range.';

  @override
  String get cashRegisterAdminEdit => 'Edit cash register';

  @override
  String get cashRegisterAdminDelete => 'Delete cash register';

  @override
  String get cashRegisterAdminDeleted => 'Cash register deleted.';

  @override
  String get cashRegisterAdminSaved => 'Cash register updated.';

  @override
  String get cashRegisterAdminDeleteConfirm =>
      'This action deletes the cash register in Supabase. If it has linked sales or expenses, the operation will be rejected.';

  @override
  String get cashRegisterAdminOpened => 'Opened';

  @override
  String get cashRegisterAdminClosed => 'Closed';

  @override
  String get moduleExpenses => 'Expenses';

  @override
  String get moduleExchangeRates => 'Exchange rates';

  @override
  String get moduleSettings => 'Settings';

  @override
  String get moduleRoles => 'Roles';

  @override
  String get moduleUsers => 'Users';

  @override
  String get moduleAudit => 'Audit';

  @override
  String get moduleSync => 'Sync';

  @override
  String get moduleComingSoon => 'Module in progress';

  @override
  String get emptyCatalogTitle => 'No categories';

  @override
  String get emptyCatalogMessage =>
      'Create categories and subcategories to organize the POS.';

  @override
  String get emptyProductsTitle => 'No products';

  @override
  String get emptyProductsMessage =>
      'Create products to sell them from the POS.';

  @override
  String get emptyModifiersTitle => 'No modifiers';

  @override
  String get emptyModifiersMessage =>
      'Create groups such as sides or garnishes and add the available options.';

  @override
  String get emptyPaymentMethodsTitle => 'No payment methods';

  @override
  String get emptyPaymentMethodsMessage =>
      'Configure cash, card, transfer or other methods.';

  @override
  String get emptyTablesTitle => 'No tables';

  @override
  String get emptyTablesMessage => 'Create the tables used during service.';

  @override
  String get emptySalesTitle => 'No sales';

  @override
  String get emptySalesMessage => 'Registered sales will appear here.';

  @override
  String get salesDateLabel => 'Date';

  @override
  String get emptyExpensesTitle => 'No expense categories';

  @override
  String get emptyExpensesMessage =>
      'Create categories to control operational expenses.';

  @override
  String get posReadyTitle => 'POS in progress';

  @override
  String get posReadyMessage =>
      'The checkout screen will use categories, products, tables and split accounts.';

  @override
  String get reportsReadyTitle => 'Reports in progress';

  @override
  String get reportsReadyMessage =>
      'Sales, profits, expenses, cash register and voids will be shown here.';

  @override
  String get reportPeriodToday => 'Day';

  @override
  String get reportPeriodWeek => 'Week';

  @override
  String get reportPeriodMonth => 'Month';

  @override
  String get reportPeriodYear => 'Year';

  @override
  String get reportPeriodCustom => 'Range';

  @override
  String get reportSelectDate => 'Select date';

  @override
  String get reportSelectRange => 'Select range';

  @override
  String get reportRangeLabel => 'Range';

  @override
  String get reportGrossSales => 'Sales';

  @override
  String get reportGrossProfit => 'Gross profit';

  @override
  String get reportExpenses => 'Expenses';

  @override
  String get reportExpensesDetail => 'Expense detail';

  @override
  String get reportNoExpenses => 'No expenses registered in this period.';

  @override
  String get expenseCategoryFilter => 'Filter by category';

  @override
  String get allCategoriesOption => 'All categories';

  @override
  String get reportNetProfit => 'Real profit';

  @override
  String get reportAverageTicket => 'Average ticket';

  @override
  String get reportSalesCount => 'Registered sales';

  @override
  String get reportVoidsCount => 'Voids';

  @override
  String get reportCashSessions => 'Cash sessions';

  @override
  String get reportVoidsDetail => 'Void details';

  @override
  String get reportNoVoids => 'No voids in this period.';

  @override
  String get reportVoidBy => 'Voided by';

  @override
  String get localUserLabel => 'Local user';

  @override
  String get reportTopProducts => 'Top-selling products';

  @override
  String get reportLowestProducts => 'Least-selling products';

  @override
  String get reportNoProducts => 'No products sold in this period.';

  @override
  String get reportUnitsSold => 'units';

  @override
  String get activeStatus => 'Active';

  @override
  String get inactiveStatus => 'Inactive';

  @override
  String get availableInPosField => 'Available in POS';

  @override
  String get availableInPosStatus => 'Available in POS';

  @override
  String get unavailableInPosStatus => 'Unavailable in POS';

  @override
  String get productOptionGroupsField => 'POS options';

  @override
  String get productOptionGroupsEmptyMessage =>
      'Add groups only when the product must request sides, bases or other choices.';

  @override
  String get productOptionGroupsFormatError =>
      'Complete the group name and at least one option.';

  @override
  String get productModifierGroupsField => 'Modifier groups';

  @override
  String get productModifierGroupsEmptyMessage =>
      'Create groups in POS modifiers and then assign them to the product.';

  @override
  String get productHasOptionsStatus => 'Requests options in POS';

  @override
  String get selectProductOptionsTitle => 'Select options';

  @override
  String get addOptionGroupAction => 'Add group';

  @override
  String get optionGroupNameField => 'Group name';

  @override
  String get optionGroupRequiredField => 'Required in POS';

  @override
  String get productOptionField => 'Option';

  @override
  String get addOptionAction => 'Add option';

  @override
  String get skipOptionalOptionAction => 'Skip';

  @override
  String get removeAction => 'Remove';

  @override
  String get deleteAction => 'Delete';

  @override
  String get nextAction => 'Next';

  @override
  String get previousAction => 'Previous';

  @override
  String get addToCartAction => 'Add';

  @override
  String get cashAffectsRegister => 'Affects cash';

  @override
  String get requiresReference => 'Requires reference';

  @override
  String get saleStatusCompleted => 'Completed';

  @override
  String get saleStatusVoided => 'Voided';

  @override
  String get voidSaleAction => 'Void';

  @override
  String get voidSaleTitle => 'Void sale';

  @override
  String get voidReasonField => 'Void reason';

  @override
  String get saleVoidedMessage => 'Sale voided.';

  @override
  String get generatePdfAction => 'Generate PDF';

  @override
  String get previewPdfAction => 'Preview receipt';

  @override
  String get invoicePreviewTitle => 'Receipt preview';

  @override
  String get pdfGenerationError => 'The PDF could not be generated.';

  @override
  String get createAction => 'Create';

  @override
  String get editAction => 'Edit';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get okAction => 'OK';

  @override
  String get saveAction => 'Save';

  @override
  String get reloadAction => 'Reload';

  @override
  String get backAction => 'Back';

  @override
  String get searchField => 'Search';

  @override
  String get emptySearchTitle => 'No results';

  @override
  String get emptySearchMessage => 'No records match the search.';

  @override
  String get nameField => 'Name';

  @override
  String get categoryTypeField => 'Type';

  @override
  String get categoryTypeCategory => 'Category';

  @override
  String get categoryTypeSubcategory => 'Subcategory';

  @override
  String get catalogParentField => 'Place inside';

  @override
  String get rootCategoryOption => 'Main category';

  @override
  String get categoryInsideOf => 'Inside';

  @override
  String get expandGroupAction => 'Expand group';

  @override
  String get collapseGroupAction => 'Collapse group';

  @override
  String get expandedStatus => 'Expanded';

  @override
  String get collapsedStatus => 'Collapsed';

  @override
  String get parentCategoryField => 'Category';

  @override
  String get priceInCentsField => 'Price';

  @override
  String get costInCentsField => 'Cost';

  @override
  String get createCategoryTitle => 'New category';

  @override
  String get editCategoryTitle => 'Edit category';

  @override
  String get removeCategoryLevelTitle => 'Remove level';

  @override
  String removeCategoryLevelMessage(String name) {
    return 'The \"$name\" level will be deleted. Its direct products and sublevels will move to the previous level.';
  }

  @override
  String get removeCategoryLevelWithChildrenMessage =>
      'This action does not delete the main category.';

  @override
  String get removeCategoryLevelConfirm => 'Remove level';

  @override
  String get createProductTitle => 'New product';

  @override
  String get editProductTitle => 'Edit product';

  @override
  String get createModifierGroupTitle => 'New modifier group';

  @override
  String get editModifierGroupTitle => 'Edit modifier group';

  @override
  String get createModifierOptionTitle => 'New modifier option';

  @override
  String get editModifierOptionTitle => 'Edit modifier option';

  @override
  String get addModifierOptionAction => 'Add option';

  @override
  String get deactivateAction => 'Deactivate';

  @override
  String get deactivateCatalogItemTitle => 'Deactivate record';

  @override
  String deactivateCatalogItemMessage(String name) {
    return '\"$name\" will be deactivated. History is preserved and the record is not physically deleted.';
  }

  @override
  String get deactivateModifierGroupTitle => 'Deactivate modifier group';

  @override
  String deactivateModifierGroupMessage(String name) {
    return 'The \"$name\" group will be deactivated and will no longer be requested in the POS. Its options are kept for history.';
  }

  @override
  String get deactivateModifierOptionTitle => 'Deactivate modifier option';

  @override
  String deactivateModifierOptionMessage(String name) {
    return 'The \"$name\" option will be deactivated and will no longer appear in the POS.';
  }

  @override
  String get modifierGroupNoOptions => 'No options';

  @override
  String get modifierGroupOneOption => '1 option';

  @override
  String modifierGroupManyOptions(int count) {
    return '$count options';
  }

  @override
  String get createPaymentMethodTitle => 'New payment method';

  @override
  String get editPaymentMethodTitle => 'Edit payment method';

  @override
  String get createTableTitle => 'New table';

  @override
  String get editTableTitle => 'Edit table';

  @override
  String get fieldRequiredError => 'Complete the required fields.';

  @override
  String get numericFieldError => 'Enter a valid number.';

  @override
  String get activeField => 'Active';

  @override
  String get optionalFieldHint => 'Optional';

  @override
  String get optionalField => 'Optional';

  @override
  String get yesLabel => 'Yes';

  @override
  String get noLabel => 'No';

  @override
  String get createExpenseCategoryTitle => 'New expense category';

  @override
  String get editExpenseCategoryTitle => 'Edit expense category';

  @override
  String get expenseCategoryCoverageField => 'Subtract in profit coverage';

  @override
  String get expenseCategoryCoverageHelp =>
      'Enable only for real operating expenses. Do not use for payroll or inventory purchases.';

  @override
  String get expenseCategoryCoverageSubcategoryHelp =>
      'Enable only on subcategories that should be measured against gross profit.';

  @override
  String get expenseCategoryCoverageIncluded => 'Included in coverage';

  @override
  String get expenseCategoryCoverageExcluded => 'Excluded from coverage';

  @override
  String get expenseCoverageTypeField => 'Expense type';

  @override
  String get expenseCoverageTypeFixed => 'Fixed';

  @override
  String get expenseCoverageTypeVariable => 'Variable';

  @override
  String get expenseCoverageAmountField => 'Estimated amount';

  @override
  String get expenseCoverageFrequencyField => 'Frequency';

  @override
  String get expenseCoverageFrequencyWeekly => 'Weekly';

  @override
  String get expenseCoverageFrequencyBiweekly => 'Biweekly';

  @override
  String get expenseCoverageFrequencyMonthly => 'Monthly';

  @override
  String get expenseCoverageFrequencyCustom => 'Custom';

  @override
  String get expenseCoverageDueDaysField => 'Payment days';

  @override
  String get expenseCoverageNotesField => 'Coverage notes';

  @override
  String get expenseCoverageAmountRequiredError =>
      'Amount is required for fixed expenses.';

  @override
  String get expenseCoverageAmountInvalidError =>
      'Coverage amount is not valid.';

  @override
  String get expenseCoverageDueDaysRequiredError =>
      'Enter at least one payment day.';

  @override
  String get expenseCoverageDueDaysInvalidError =>
      'Payment days must be between 1 and 31.';

  @override
  String get inventoryValueReportTitle => 'Inventory value';

  @override
  String get inventoryValueReportSubtitle =>
      'Current cost, potential sales, and estimated inventory profit.';

  @override
  String get monthlyOperationalReportTitle => 'Operational result';

  @override
  String get monthlyOperationalReportSubtitle =>
      'Monthly sales compared with expenses, payroll and estimated coverage.';

  @override
  String get monthlyOperationalEmptyMessage =>
      'There are no sales, expenses or payroll for the selected range.';

  @override
  String get monthlyOperationalProductCost => 'Product cost';

  @override
  String get monthlyOperationalConsideredExpenses => 'Operating expenses';

  @override
  String get monthlyOperationalPayroll => 'Payroll';

  @override
  String get monthlyOperationalResult => 'Result';

  @override
  String get monthlyOperationalRiskTitle => 'Insufficient profit';

  @override
  String get monthlyOperationalRiskMessage =>
      'Gross profit does not yet cover operating expenses and payroll for the period.';

  @override
  String monthlyOperationalMissingMessage(String percent, String amount) {
    return 'Accumulated gross profit covers $percent% of period obligations. $amount is still missing to cover them.';
  }

  @override
  String get monthlyOperationalHealthyTitle => 'Healthy coverage';

  @override
  String get monthlyOperationalHealthyMessage =>
      'Gross profit covers operating expenses and payroll for the period.';

  @override
  String monthlyOperationalSurplusMessage(String amount) {
    return 'Period obligations are covered and the estimated surplus is $amount.';
  }

  @override
  String get monthlyOperationalCoverage => 'Coverage used';

  @override
  String get monthlyOperationalProjectedCoverage => 'Coverage goal';

  @override
  String get monthlyOperationalActualCoverage => 'Executed';

  @override
  String get monthlyOperationalAvailableCoverage => 'Estimated surplus';

  @override
  String get monthlyOperationalReserveCost => 'Product cost reserve';

  @override
  String get monthlyOperationalMonthlyObligations => 'Period obligations';

  @override
  String get monthlyOperationalPendingDisbursement => 'Pending disbursement';

  @override
  String get monthlyOperationalEstimatedSurplus => 'Estimated surplus';

  @override
  String get monthlyOperationalMissingToCover => 'Missing to cover';

  @override
  String get monthlyOperationalFortnightCuts => 'Tracking cuts';

  @override
  String get monthlyOperationalCurrentMonth => 'Current month';

  @override
  String get monthlyOperationalPreviousMonth => 'Previous month';

  @override
  String get monthlyOperationalOtherMonth => 'Other month';

  @override
  String get monthlyOperationalFirstHalf => 'First half';

  @override
  String get monthlyOperationalSecondHalf => 'Second half';

  @override
  String get monthlyOperationalPayrollPending => 'Pending payroll';

  @override
  String get monthlyOperationalAdvances => 'Advances delivered';

  @override
  String get monthlyOperationalPendingConsumption => 'Pending consumptions';

  @override
  String get monthlyOperationalExpensesTitle => 'Considered expenses';

  @override
  String get monthlyOperationalExcludedExpenses => 'Excluded expenses';

  @override
  String get monthlyOperationalCoverageIndicators => 'Coverage indicators';

  @override
  String get monthlyOperationalNoCoverageConfigured =>
      'There are no configured obligations for this period.';

  @override
  String get monthlyOperationalCoverageGoal => 'Period goal';

  @override
  String get monthlyOperationalCoverageActual => 'Registered';

  @override
  String get monthlyOperationalCoveragePending => 'Pending';

  @override
  String get monthlyOperationalNoDueDays => 'No payment days';

  @override
  String monthlyOperationalDueDays(String days) {
    return 'Days $days';
  }

  @override
  String get monthlyOperationalNoCoverageType => 'No type';

  @override
  String get monthlyOperationalNoCoverageFrequency => 'No frequency';

  @override
  String get inventoryValueSearchLabel => 'Search product or category';

  @override
  String get inventoryOnlyWithStockFilter => 'Only with stock';

  @override
  String get inventoryValueLoadErrorTitle => 'Could not load';

  @override
  String get inventoryValueEmptyTitle => 'No data';

  @override
  String get inventoryValueEmptyMessage =>
      'There are no inventory products for the selected filter.';

  @override
  String get inventoryCostMetric => 'Inventory cost';

  @override
  String get inventoryPotentialSalesMetric => 'Potential sales';

  @override
  String get inventoryPotentialProfitMetric => 'Potential profit';

  @override
  String get inventoryMarginMetric => 'Margin';

  @override
  String get inventoryWithStockMetric => 'With stock';

  @override
  String get inventoryMissingCostMetric => 'Missing cost';

  @override
  String get inventoryMissingPriceMetric => 'Missing price';

  @override
  String get inventoryLowMarginMetric => 'Low margin';

  @override
  String get inventoryCategoryValueTitle => 'Value by category';

  @override
  String inventoryCapitalPercentLabel(String percent) {
    return '$percent% of inventory capital';
  }

  @override
  String get inventoryProductColumn => 'Product';

  @override
  String get inventoryCategoryColumn => 'Category';

  @override
  String get inventoryStockColumn => 'Stock';

  @override
  String get inventoryCostColumn => 'Cost';

  @override
  String get inventoryPriceColumn => 'Price';

  @override
  String get inventoryCostValueColumn => 'Cost value';

  @override
  String get inventoryPotentialSalesColumn => 'Potential sales';

  @override
  String get inventoryProfitColumn => 'Profit';

  @override
  String get deleteExpenseCategoryTitle => 'Delete expense category';

  @override
  String deleteExpenseCategoryMessage(String name) {
    return '\"$name\" will be deleted. If it has child categories, they will move to root.';
  }

  @override
  String get createExpenseTitle => 'New expense';

  @override
  String get expenseSavedMessage => 'Expense registered successfully.';

  @override
  String get expenseCategoriesSection => 'Expense categories';

  @override
  String get todayExpensesSection => 'Today\'s expenses';

  @override
  String get noExpensesTodayMessage => 'No expenses registered today.';

  @override
  String get unknownExpenseCategory => 'No category';

  @override
  String get amountInCentsField => 'Amount';

  @override
  String get descriptionField => 'Description';

  @override
  String get openCashRegisterTitle => 'Open cash register';

  @override
  String get closeCashRegisterTitle => 'Close cash register';

  @override
  String get openingCashField => 'Opening cash';

  @override
  String get closingCashField => 'Physical count';

  @override
  String get cashOpeningAmount => 'Opening cash';

  @override
  String get cashSalesAmount => 'Cash sales';

  @override
  String get cashExpensesAmount => 'Cash expenses';

  @override
  String get cashExpectedAmount => 'Expected cash';

  @override
  String get cashPhysicalAmount => 'Physical count';

  @override
  String get cashDifferenceAmount => 'Difference';

  @override
  String get cashStatusOpen => 'Cash register open';

  @override
  String get cashStatusClosed => 'Cash register closed';

  @override
  String get openAction => 'Open';

  @override
  String get closeAction => 'Close';

  @override
  String get posCashRegisterRequiredTitle => 'Cash register required';

  @override
  String get posCashRegisterRequiredMessage =>
      'Open your cash register to enter the POS and record sales.';

  @override
  String get posStaleCashRegisterRequiredTitle => 'Previous cash register open';

  @override
  String posStaleCashRegisterRequiredMessage(String date) {
    return 'The cash register from $date was left open. Close it before opening today\'s cash register.';
  }

  @override
  String get posOpenCashRegisterAction => 'Open cash register';

  @override
  String get posCloseCashRegisterAction => 'Close cash register';

  @override
  String get posViewTransactionsAction => 'View Transactions';

  @override
  String get posNoTransactionsMessage =>
      'There are no charged transactions in this cash register.';

  @override
  String get posTransactionsTotalLabel => 'Charged total';

  @override
  String get posCloseCashPendingCart =>
      'The cash register cannot be closed while tables have pending products.';

  @override
  String get posExitAction => 'Exit';

  @override
  String get tableOccupiedLabel => 'Occupied';

  @override
  String get renameTableTitle => 'Rename table';

  @override
  String get tableDisplayNameField => 'Visible POS name';

  @override
  String get cartTitle => 'Account';

  @override
  String get cartEmptyMessage => 'Select products to add them to the account.';

  @override
  String get checkoutAction => 'Checkout';

  @override
  String get clearCartAction => 'Clear';

  @override
  String get clearCartConfirmTitle => 'Clear order';

  @override
  String get clearCartConfirmMessage =>
      'All products will be removed from the selected table. This action cannot be undone.';

  @override
  String get removeCartLineConfirmTitle => 'Remove product';

  @override
  String removeCartLineConfirmMessage(String name) {
    return '\"$name\" will be removed from the order. This action cannot be undone.';
  }

  @override
  String get removeSplitAccountConfirmTitle => 'Remove account';

  @override
  String removeSplitAccountConfirmMessage(String name) {
    return 'The \"$name\" account will be removed and its products will return to the original order.';
  }

  @override
  String get paymentReferenceField => 'Payment reference';

  @override
  String get paymentGroupField => 'Payment group';

  @override
  String get paymentParentField => 'Location';

  @override
  String get paymentRootOption => 'Top level';

  @override
  String get paymentFinalOptionField => 'Chargeable POS option';

  @override
  String get paymentNavigationNode => 'Navigation group';

  @override
  String get removePaymentLevelTitle => 'Remove payment level';

  @override
  String removePaymentLevelMessage(String name) {
    return 'The \"$name\" level will be deleted. Its direct banks, accounts or options will move to the previous level.';
  }

  @override
  String get removePaymentLevelWithChildrenMessage =>
      'This action does not delete a top-level payment method.';

  @override
  String get removePaymentLevelConfirm => 'Remove level';

  @override
  String get currencyCodeField => 'Currency';

  @override
  String get exchangeRateField => 'Rate';

  @override
  String get exchangeRateMonthLabel => 'Month';

  @override
  String get exchangeRateMonthlyField => 'Rate for the whole month';

  @override
  String get exchangeRateApplyMonthAction => 'Apply to month';

  @override
  String get exchangeRateNotConfigured => 'Not configured';

  @override
  String exchangeRateMissingMessage(String currency) {
    return 'There is no exchange rate for $currency on the current day.';
  }

  @override
  String get moreOptionsAction => 'More options';

  @override
  String get moreOptionsEmptyMessage =>
      'Secondary POS options will be added here.';

  @override
  String get posRegisterExpenseAction => 'Register Expense';

  @override
  String paymentAmountTitle(String method) {
    return 'Amount $method';
  }

  @override
  String get paymentAmountInsufficient =>
      'The received amount does not cover the total.';

  @override
  String paymentChangeMessage(String amount) {
    return 'Change: $amount';
  }

  @override
  String get posAmountReceivedField => 'Received';

  @override
  String get posChangeDueLabel => 'Change';

  @override
  String get posDescriptionColumn => 'Description';

  @override
  String get posServedColumn => 'Served';

  @override
  String get posQuantityColumn => 'Quantity';

  @override
  String get posPriceColumn => 'Price';

  @override
  String get posAmountColumn => 'Amount';

  @override
  String get posRemoveColumn => 'Remove';

  @override
  String get posMarkServedTooltip => 'Mark as served';

  @override
  String get posMarkPendingTooltip => 'Mark as pending';

  @override
  String get posHideProductsAction => 'Hide Products';

  @override
  String get posShowProductsAction => 'Show Products';

  @override
  String get posHideProductsCompactAction => 'Hide';

  @override
  String get posShowProductsCompactAction => 'Show';

  @override
  String posTodayExchangeRateLabel(String rate) {
    return 'Today\'s exchange rate: $rate';
  }

  @override
  String get paymentMethodField => 'Payment method';

  @override
  String posTodayExchangeRateCompactLabel(String rate) {
    return 'Rate: $rate';
  }

  @override
  String get tableField => 'Table';

  @override
  String get tableStatusAvailable => 'Available';

  @override
  String get tableStatusOccupied => 'Occupied';

  @override
  String get tableStatusDisabled => 'Inactive';

  @override
  String get noTableOption => 'No table';

  @override
  String get splitAccountsAction => 'Split accounts';

  @override
  String get splitAccountsTitle => 'Split accounts';

  @override
  String get accountCountField => 'Number of accounts';

  @override
  String get accountNameField => 'Account name';

  @override
  String get assignItemsTitle => 'Assign products';

  @override
  String get selectAccountHint => 'Select an account';

  @override
  String get pendingItemsTitle => 'Pending products';

  @override
  String get assignedItemsTitle => 'Assigned products';

  @override
  String get splitAccountsHelp =>
      'Select an account and tap the products that belong to that invoice.';

  @override
  String get splitAccountsPendingError =>
      'Assign every product and leave at least one product in each account.';

  @override
  String get splitAccountsMinimumItemsError =>
      'You can split an account only when the table has more than one product.';

  @override
  String get splitAddAccountAction => 'Add account';

  @override
  String get splitOriginalOrderTitle => 'Original order';

  @override
  String get splitSelectedItemHint => 'Selected product';

  @override
  String get splitTapAccountHint => 'Tap an account to move it.';

  @override
  String get splitRemoveAccountAction => 'Remove account';

  @override
  String get splitReturnItemAction => 'Return to order';

  @override
  String get splitAccountTotalLabel => 'Total';

  @override
  String get confirmSplitAction => 'Confirm split';

  @override
  String get splitAccountsConfirmedMessage =>
      'Split accounts are ready to invoice.';

  @override
  String get splitAccountPaymentsTitle => 'Payment by account';

  @override
  String get checkoutSuccessTitle => 'Sale registered';

  @override
  String get checkoutSuccessMessage => 'The sale was saved locally.';

  @override
  String get businessSettingsTitle => 'Business information';

  @override
  String get businessNameField => 'Business name';

  @override
  String get legalNameField => 'Legal name';

  @override
  String get taxNumberField => 'Tax number';

  @override
  String get phoneField => 'Phone';

  @override
  String get addressField => 'Address';

  @override
  String get invoicePrefixField => 'Invoice prefix';

  @override
  String get initialInvoiceNumberField => 'Initial number';

  @override
  String get showCompanyInfoOnPdfField => 'Show company information on PDF';

  @override
  String get settingsSavedMessage => 'Settings saved.';

  @override
  String get emptyRolesTitle => 'No roles';

  @override
  String get emptyRolesMessage =>
      'Create roles and assign permissions to control access.';

  @override
  String get emptyUsersTitle => 'No users';

  @override
  String get emptyUsersMessage => 'Create local users and assign a role.';

  @override
  String get emptyAuditTitle => 'No events';

  @override
  String get emptyAuditMessage => 'No audited actions for the selected date.';

  @override
  String get auditActionCategorySaved => 'Category saved';

  @override
  String get auditActionProductSaved => 'Product saved';

  @override
  String get auditActionPaymentMethodSaved => 'Payment method saved';

  @override
  String get auditActionTableSaved => 'Table saved';

  @override
  String get auditActionSaleVoided => 'Sale voided';

  @override
  String get auditActionCashOpened => 'Cash register opened';

  @override
  String get auditActionCashClosed => 'Cash register closed';

  @override
  String get auditActionExpenseCategorySaved => 'Expense category saved';

  @override
  String get auditActionExpenseCategoryDeleted => 'Expense category deleted';

  @override
  String get auditActionExpenseSaved => 'Expense registered';

  @override
  String get auditActionSettingsSaved => 'Settings saved';

  @override
  String get auditActionRoleSaved => 'Role saved';

  @override
  String get auditActionUserSaved => 'User saved';

  @override
  String get auditDetailReason => 'Reason';

  @override
  String get auditDetailStatus => 'Status';

  @override
  String get auditDetailOptionGroups => 'Option groups';

  @override
  String get auditDetailPermissions => 'Permissions';

  @override
  String get emptySyncTitle => 'No pending items';

  @override
  String get emptySyncMessage => 'There are no local operations pending sync.';

  @override
  String get syncNowAction => 'Sync now';

  @override
  String get syncOperationCreate => 'New record';

  @override
  String get syncOperationUpdate => 'Update';

  @override
  String get syncOperationDelete => 'Delete';

  @override
  String get syncStatusPending => 'Pending';

  @override
  String get syncStatusSyncing => 'Syncing';

  @override
  String get syncStatusSynced => 'Synced';

  @override
  String get syncStatusError => 'Error';

  @override
  String get syncLastError => 'Last error';

  @override
  String syncRetryCount(int count) {
    return 'Retries: $count';
  }

  @override
  String syncSummary(int processed, int succeeded, int failed) {
    return 'Processed: $processed | Succeeded: $succeeded | Failed: $failed';
  }

  @override
  String get createRoleTitle => 'New role';

  @override
  String get editRoleTitle => 'Edit role';

  @override
  String get roleDescriptionField => 'Description';

  @override
  String get systemRoleField => 'System role';

  @override
  String get permissionsSection => 'Permissions';

  @override
  String get createUserTitle => 'New user';

  @override
  String get editUserTitle => 'Edit user';

  @override
  String get displayNameField => 'Display name';

  @override
  String get emailField => 'Email';

  @override
  String get pinField => 'PIN';

  @override
  String get pinOptionalField => 'New PIN (optional)';

  @override
  String get posUserField => 'POS user';

  @override
  String get posUserHelp =>
      'When signing in, opens the POS operational flow directly.';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginMessage => 'Use your email and PIN to operate SmooControl.';

  @override
  String get loginAction => 'Enter';

  @override
  String get initialAdminTitle => 'Create initial administrator';

  @override
  String get initialAdminMessage =>
      'There are no users with a PIN. Create the first administrator to enable access.';

  @override
  String get createInitialAdminAction => 'Create administrator';

  @override
  String get accessDeniedTitle => 'Restricted access';

  @override
  String get accessDeniedMessage =>
      'Your user does not have permission to open this screen.';

  @override
  String get roleField => 'Role';

  @override
  String get noRoleAvailableMessage => 'Create an active role first.';

  @override
  String get savingAction => 'Saving...';

  @override
  String get inventoryAdjustmentAction => 'Adjust inventory';

  @override
  String get inventoryAdjustmentTitle => 'Inventory count adjustment';

  @override
  String get inventoryAdjustmentFilter =>
      'Filter by product, category, or subcategory';

  @override
  String get inventoryAdjustmentNoProducts =>
      'There are no products tracking inventory.';

  @override
  String get inventoryAdjustmentEmptyTitle => 'No results';

  @override
  String get inventoryAdjustmentEmptyMessage =>
      'Adjust the filter to see products.';

  @override
  String get inventoryAdjustmentChanged => 'Changes';

  @override
  String get inventoryAdjustmentPositive => 'In';

  @override
  String get inventoryAdjustmentNegative => 'Out';

  @override
  String get inventoryAdjustmentSystemStock => 'System';

  @override
  String get inventoryAdjustmentCountedStock => 'Counted';

  @override
  String get inventoryAdjustmentDifference => 'Difference';

  @override
  String get inventoryAdjustmentInvalidCount => 'Review invalid counts.';

  @override
  String get inventoryAdjustmentNoChanges =>
      'Enter at least one count different from current stock.';

  @override
  String get inventoryAdjustmentSave => 'Save adjustment';
}

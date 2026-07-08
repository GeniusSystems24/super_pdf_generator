// APPLICATION · templates · public barrel + default registry.
//
// Declarative business templates adopted from the GeniusLink PDF reference and
// re-expressed against Folio's clean domain. Each template recomputes its
// totals with GeniusMoney and validates provided figures with
// GeniusFinancialValidator before producing an immutable document.

import 'business/account_statement_template.dart';
import 'business/balance_sheet_template.dart';
import 'business/budget_report_template.dart';
import 'business/cash_flow_template.dart';
import 'business/customer_statement_template.dart';
import 'business/income_statement_template.dart';
import 'business/inventory_report_template.dart';
import 'business/payment_voucher_template.dart';
import 'business/payslip_template.dart';
import 'business/tax_invoice_template.dart';
import 'business/trial_balance_template.dart';
import 'template_registry.dart';

export 'engine/template.dart';
export 'template_registry.dart';
export 'support/amount_in_words.dart';
export 'support/money_format.dart';

export 'business/models.dart';
export 'business/account_statement_template.dart';
export 'business/balance_sheet_template.dart';
export 'business/budget_report_template.dart';
export 'business/cash_flow_template.dart';
export 'business/customer_statement_template.dart';
export 'business/income_statement_template.dart';
export 'business/inventory_report_template.dart';
export 'business/payment_voucher_template.dart';
export 'business/payslip_template.dart';
export 'business/tax_invoice_template.dart';
export 'business/trial_balance_template.dart';

/// Builds a registry pre-populated with every built-in business template.
///
/// ```dart
/// final registry = defaultTemplateRegistry();
/// final invoice = registry.require('tax_invoice');
/// ```
PdfTemplateRegistry defaultTemplateRegistry() {
  return PdfTemplateRegistry()
    // Financial
    ..register(const TaxInvoiceTemplate())
    ..register(const TrialBalanceTemplate())
    ..register(const BalanceSheetTemplate())
    ..register(const IncomeStatementTemplate())
    ..register(const CashFlowTemplate())
    ..register(const BudgetReportTemplate())
    ..register(const CustomerStatementTemplate())
    ..register(const AccountStatementTemplate())
    ..register(const InventoryReportTemplate())
    // HR
    ..register(const PayslipTemplate())
    // Vouchers
    ..register(const PaymentVoucherTemplate());
}

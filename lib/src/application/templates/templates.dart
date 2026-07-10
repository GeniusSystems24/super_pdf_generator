// APPLICATION · templates · public barrel + default registry.
//
// Declarative business templates adopted from the GeniusLink PDF reference and
// re-expressed against Folio's clean domain. Each template recomputes its
// totals with GeniusMoney and validates provided figures with
// GeniusFinancialValidator before producing an immutable document.

import 'business/account_statement_template.dart';
import 'business/attendance_report_template.dart';
import 'business/balance_sheet_template.dart';
import 'business/budget_report_template.dart';
import 'business/cash_flow_template.dart';
import 'business/credit_note_template.dart';
import 'business/customer_statement_template.dart';
import 'business/delivery_note_template.dart';
import 'business/employee_report_template.dart';
import 'business/income_statement_template.dart';
import 'business/inventory_report_template.dart';
import 'business/leave_report_template.dart';
import 'business/payment_voucher_template.dart';
import 'business/payslip_template.dart';
import 'business/purchase_order_template.dart';
import 'business/quotation_template.dart';
import 'business/tax_invoice_template.dart';
import 'business/trial_balance_template.dart';
import 'business/voucher_templates.dart';
import 'template_registry.dart';

export 'engine/template.dart';
export 'template_registry.dart';
export 'support/amount_in_words.dart';
export 'support/money_format.dart';

export 'business/models.dart';
export 'business/account_statement_template.dart';
export 'business/attendance_report_template.dart';
export 'business/balance_sheet_template.dart';
export 'business/budget_report_template.dart';
export 'business/cash_flow_template.dart';
export 'business/credit_note_template.dart';
export 'business/customer_statement_template.dart';
export 'business/delivery_note_template.dart';
export 'business/employee_report_template.dart';
export 'business/income_statement_template.dart';
export 'business/inventory_report_template.dart';
export 'business/leave_report_template.dart';
export 'business/payment_voucher_template.dart';
export 'business/payslip_template.dart';
export 'business/purchase_order_template.dart';
export 'business/quotation_template.dart';
export 'business/tax_invoice_template.dart';
export 'business/trial_balance_template.dart';
export 'business/voucher_templates.dart';

/// Builds a registry pre-populated with every built-in business template.
///
/// ```dart
/// final registry = defaultTemplateRegistry();
/// final invoice = registry.require('tax_invoice');
/// ```
PdfTemplateRegistry defaultTemplateRegistry() {
  return PdfTemplateRegistry()
    // Financial statements & reports
    ..register(const TaxInvoiceTemplate())
    ..register(const TrialBalanceTemplate())
    ..register(const BalanceSheetTemplate())
    ..register(const IncomeStatementTemplate())
    ..register(const CashFlowTemplate())
    ..register(const BudgetReportTemplate())
    ..register(const CustomerStatementTemplate())
    ..register(const AccountStatementTemplate())
    ..register(const InventoryReportTemplate())
    // Sales
    ..register(const QuotationTemplate())
    ..register(const PurchaseOrderTemplate())
    ..register(const DeliveryNoteTemplate())
    ..register(const CreditNoteTemplate())
    // HR
    ..register(const PayslipTemplate())
    ..register(const EmployeeReportTemplate())
    ..register(const AttendanceReportTemplate())
    ..register(const LeaveReportTemplate())
    // Vouchers
    ..register(const PaymentVoucherTemplate())
    ..register(const ExpenseVoucherTemplate())
    ..register(const PettyCashVoucherTemplate())
    ..register(const JournalVoucherTemplate())
    ..register(const ContraVoucherTemplate())
    ..register(const BankPaymentVoucherTemplate())
    ..register(const BankReceiptVoucherTemplate())
    ..register(const CashPaymentVoucherTemplate())
    ..register(const CashReceiptVoucherTemplate())
    ..register(const SalaryVoucherTemplate())
    ..register(const AdvanceVoucherTemplate())
    ..register(const RefundVoucherTemplate())
    ..register(const DepositVoucherTemplate());
}

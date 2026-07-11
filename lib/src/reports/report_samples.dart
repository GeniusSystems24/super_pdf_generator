import 'documents/customer_statement_report.dart';
import 'documents/inventory_valuation_report.dart';
import 'documents/tax_invoice_report.dart';
import 'documents/trial_balance_report.dart';
import 'core/report_models.dart';

/// Ready-made sample data mirroring the GeniusLink reference PDFs, so the demo
/// (and your first integration test) can generate an identical document with
/// one call. Every string carries its Arabic counterpart for RTL parity.
abstract final class ReportSamples {
  /// Genius Systems Co. — the issuing company on every reference document.
  static const ReportCompany company = ReportCompany(
    name: 'Genius Systems Co.',
    nameAr: 'شركة جينيس سيستمز',
    address: "Yemen, Dhamar, Sana'a Street",
    addressAr: 'اليمن، ذمار، شارع صنعاء',
    vatNumber: '300012345678903',
    phone: '+967-774717166',
    email: 'info@genius-systems.com',
  );

  // ---- Tax invoice --------------------------------------------------------

  static InvoiceReportData taxInvoice() => InvoiceReportData(
        company: company,
        printedAt: DateTime(2026, 7, 11, 2, 53),
        customer: const InfoPanel(
          title: 'To',
          titleAr: 'إلى',
          fields: [
            InfoField('Customer Name', 'Modern Retailers Co.',
                labelAr: 'اسم العميل',),
            InfoField('Address', 'Jeddah, King Fahd Road', labelAr: 'العنوان'),
            InfoField('VAT No', '311122233344455', labelAr: 'الرقم الضريبي'),
            InfoField('Phone', '+966 12 345 6789', labelAr: 'رقم الهاتف'),
          ],
        ),
        details: const InfoPanel(
          title: 'Invoice Details',
          titleAr: 'بيانات الفاتورة',
          fields: [
            InfoField('Invoice No', 'SINV-2025-1001', labelAr: 'رقم الفاتورة'),
            InfoField('Date', '19/01/2025', labelAr: 'التاريخ'),
            InfoField('Payment Terms', 'Cash on Delivery', labelAr: 'شروط الدفع'),
            InfoField('PO No', 'PO-250', labelAr: 'رقم الطلب'),
          ],
        ),
        items: const [
          InvoiceItem(name: 'Smartphone Model Z (ITM-101)', nameAr: 'هاتف ذكي موديل Z', quantity: 5, unitPrice: 3200),
          InvoiceItem(name: 'Laptop Pro X1 (ITM-001)', nameAr: 'لابتوب برو X1', quantity: 2, unitPrice: 4500),
          InvoiceItem(name: '4K Monitor (ITM-105)', nameAr: 'شاشة 4K', quantity: 3, unitPrice: 1200),
          InvoiceItem(name: 'Wireless Keyboard (ITM-200)', nameAr: 'لوحة مفاتيح لاسلكية', quantity: 10, unitPrice: 150),
        ],
        subtotal: 30100,
        vatAmount: 4515,
        total: 34615,
      );

  // ---- Trial balance ------------------------------------------------------

  static TrialBalanceData trialBalance() => TrialBalanceData(
        company: company,
        asOf: DateTime(2025, 12, 31),
        user: 'Anwar Al-saiary',
        documentId: '123456789',
        qrData: 'https://genius-systems.com/tb/2025-12-31',
        printedAt: DateTime(2026, 7, 11, 2, 53),
        notes: const [
          'Trial Balance shows all account balances as of the report date',
          'Total Debit must equal Total Credit',
          'Any difference indicates errors in accounting entries',
          'For inquiries, contact the Accounting Department',
        ],
        groups: const [
          TrialBalanceGroup('Assets', [
            TrialBalanceAccount('Cash & Cash Equivalents', nameAr: 'النقد وما في حكمه', debit: 2500000),
            TrialBalanceAccount('Accounts Receivable', nameAr: 'الذمم المدينة', debit: 1800000),
            TrialBalanceAccount('Inventory', nameAr: 'المخزون', debit: 3200000),
            TrialBalanceAccount('Property, Plant & Equipment', nameAr: 'الممتلكات والمعدات', debit: 5000000),
            TrialBalanceAccount('Accumulated Depreciation', nameAr: 'مجمع الإهلاك', credit: 1500000),
          ], titleAr: 'الأصول',),
          TrialBalanceGroup('Liabilities', [
            TrialBalanceAccount('Accounts Payable', nameAr: 'الذمم الدائنة', credit: 1200000),
            TrialBalanceAccount('Short-term Loans', nameAr: 'قروض قصيرة الأجل', credit: 500000),
            TrialBalanceAccount('Long-term Loans', nameAr: 'قروض طويلة الأجل', credit: 3000000),
          ], titleAr: 'الخصوم',),
          TrialBalanceGroup('Equity', [
            TrialBalanceAccount('Capital', nameAr: 'رأس المال', credit: 5000000),
            TrialBalanceAccount('Retained Earnings', nameAr: 'الأرباح المحتجزة', credit: 1300000),
          ], titleAr: 'حقوق الملكية',),
          TrialBalanceGroup('Income', [
            TrialBalanceAccount('Sales Revenue', nameAr: 'إيرادات المبيعات', credit: 8500000),
            TrialBalanceAccount('Other Income', nameAr: 'إيرادات أخرى', credit: 200000),
          ], titleAr: 'الإيرادات',),
          TrialBalanceGroup('Expenses', [
            TrialBalanceAccount('Cost of Goods Sold', nameAr: 'تكلفة البضاعة المباعة', debit: 4500000),
            TrialBalanceAccount('Salaries Expense', nameAr: 'مصروف الرواتب', debit: 2000000),
            TrialBalanceAccount('Rent Expense', nameAr: 'مصروف الإيجار', debit: 1200000),
            TrialBalanceAccount('Depreciation Expense', nameAr: 'مصروف الإهلاك', debit: 500000),
            TrialBalanceAccount('G&A Expenses', nameAr: 'مصروفات عمومية وإدارية', debit: 800000),
          ], titleAr: 'المصروفات',),
        ],
      );

  // ---- Customer statement -------------------------------------------------

  static CustomerStatementData customerStatement() => CustomerStatementData(
        company: company,
        printedAt: DateTime(2026, 7, 11, 2, 53),
        periodFrom: DateTime(2025, 1, 1),
        periodTo: DateTime(2025, 12, 31),
        customer: const InfoPanel(
          title: 'Customer Details',
          titleAr: 'بيانات العميل',
          fields: [
            InfoField('Customer Name', 'Modern Retailers Co.', labelAr: 'اسم العميل'),
            InfoField('Address', 'Jeddah, King Fahd Road', labelAr: 'العنوان'),
            InfoField('Account No', 'CUST-1001', labelAr: 'رقم الحساب'),
            InfoField('Phone', '+966 12 345 6789', labelAr: 'رقم الهاتف'),
          ],
        ),
        details: const InfoPanel(
          title: 'Statement Details',
          titleAr: 'بيانات الكشف',
          fields: [
            InfoField('Period From', '01/01/2025', labelAr: 'الفترة من'),
            InfoField('Period To', '31/12/2025', labelAr: 'الفترة إلى'),
            InfoField('Opening Balance', '0.00', labelAr: 'الرصيد الافتتاحي'),
            InfoField('Currency', 'SAR', labelAr: 'العملة'),
          ],
        ),
        transactions: [
          StatementTxn(date: DateTime(2025, 1, 1), reference: '-', description: 'Opening Balance', descriptionAr: 'الرصيد الافتتاحي', balance: 0),
          StatementTxn(date: DateTime(2025, 1, 15), reference: 'SINV-1001', description: 'Sales Invoice', descriptionAr: 'فاتورة مبيعات', debit: 16000, balance: 16000),
          StatementTxn(date: DateTime(2025, 1, 20), reference: 'RV-1001', description: 'Payment Received', descriptionAr: 'دفعة مستلمة', credit: 10000, balance: 6000),
          StatementTxn(date: DateTime(2025, 2, 10), reference: 'SINV-1005', description: 'Sales Invoice', descriptionAr: 'فاتورة مبيعات', debit: 25500, balance: 31500),
          StatementTxn(date: DateTime(2025, 2, 25), reference: 'RV-1002', description: 'Payment Received', descriptionAr: 'دفعة مستلمة', credit: 31500, balance: 0),
          StatementTxn(date: DateTime(2025, 3, 5), reference: 'SINV-1010', description: 'Sales Invoice', descriptionAr: 'فاتورة مبيعات', debit: 12000, balance: 12000),
          StatementTxn(date: DateTime(2025, 3, 15), reference: 'SINV-1015', description: 'Sales Invoice', descriptionAr: 'فاتورة مبيعات', debit: 8000, balance: 20000),
          StatementTxn(date: DateTime(2025, 12, 31), reference: '-', description: 'Closing Balance', descriptionAr: 'الرصيد الختامي', balance: 20000, closing: true),
        ],
        aging: const [5000, 10000, 5000, 0],
      );

  // ---- Inventory valuation ------------------------------------------------

  static InventoryReportData inventory() => InventoryReportData(
        company: company,
        asOf: DateTime(2025, 1, 19),
        user: 'Anwar Al-saiary',
        printedAt: DateTime(2026, 7, 11, 2, 53),
        categories: const [
          InventoryCategory('Electronics', [
            InventoryItem(code: 'ITM-101', name: 'Smartphone Model Z', nameAr: 'هاتف ذكي موديل Z', warehouse: 'Riyadh Main', warehouseAr: 'الرياض الرئيسي', quantity: 150, avgCost: 2500),
            InventoryItem(code: 'ITM-001', name: 'Laptop Pro X1', nameAr: 'لابتوب برو X1', warehouse: 'Riyadh Main', warehouseAr: 'الرياض الرئيسي', quantity: 75, avgCost: 3800),
            InventoryItem(code: 'ITM-105', name: '4K Monitor', nameAr: 'شاشة 4K', warehouse: 'Jeddah Branch', warehouseAr: 'فرع جدة', quantity: 100, avgCost: 900),
            InventoryItem(code: 'ITM-200', name: 'Wireless Keyboard', nameAr: 'لوحة مفاتيح لاسلكية', warehouse: 'Dammam Branch', warehouseAr: 'فرع الدمام', quantity: 250, avgCost: 120),
            InventoryItem(code: 'ITM-205', name: 'Gaming Mouse', nameAr: 'فأرة ألعاب', warehouse: 'Riyadh Main', warehouseAr: 'الرياض الرئيسي', quantity: 300, avgCost: 80),
            InventoryItem(code: 'ITM-210', name: 'External SSD 1TB', nameAr: 'قرص SSD خارجي 1 تيرا', warehouse: 'Jeddah Branch', warehouseAr: 'فرع جدة', quantity: 120, avgCost: 450),
            InventoryItem(code: 'ITM-211', name: 'USB-C Hub 7-Port', nameAr: 'موزّع USB-C 7 منافذ', warehouse: 'Riyadh Main', warehouseAr: 'الرياض الرئيسي', quantity: 200, avgCost: 85),
            InventoryItem(code: 'ITM-212', name: 'Webcam HD 1080p', nameAr: 'كاميرا ويب HD', warehouse: 'Dammam Branch', warehouseAr: 'فرع الدمام', quantity: 180, avgCost: 150),
            InventoryItem(code: 'ITM-213', name: 'Wireless Earbuds Pro', nameAr: 'سماعات لاسلكية برو', warehouse: 'Jeddah Branch', warehouseAr: 'فرع جدة', quantity: 400, avgCost: 220),
            InventoryItem(code: 'ITM-214', name: 'Tablet Pro 12 inch', nameAr: 'تابلت برو 12 إنش', warehouse: 'Riyadh Main', warehouseAr: 'الرياض الرئيسي', quantity: 90, avgCost: 1800),
          ], titleAr: 'الإلكترونيات',),
          InventoryCategory('Office Furniture', [
            InventoryItem(code: 'ITM-003', name: 'Office Chair', nameAr: 'كرسي مكتب', warehouse: 'Riyadh Main', warehouseAr: 'الرياض الرئيسي', quantity: 200, avgCost: 600),
            InventoryItem(code: 'ITM-008', name: 'Desk Lamp', nameAr: 'مصباح مكتب', warehouse: 'Jeddah Branch', warehouseAr: 'فرع جدة', quantity: 150, avgCost: 80),
            InventoryItem(code: 'ITM-012', name: 'Whiteboard', nameAr: 'سبورة بيضاء', warehouse: 'Dammam Branch', warehouseAr: 'فرع الدمام', quantity: 50, avgCost: 250),
            InventoryItem(code: 'ITM-015', name: 'Ergonomic Desk', nameAr: 'مكتب مريح', warehouse: 'Riyadh Main', warehouseAr: 'الرياض الرئيسي', quantity: 80, avgCost: 1200),
            InventoryItem(code: 'ITM-020', name: 'Conference Table 8-Seater', nameAr: 'طاولة اجتماعات 8 مقاعد', warehouse: 'Dammam Branch', warehouseAr: 'فرع الدمام', quantity: 15, avgCost: 3500),
            InventoryItem(code: 'ITM-021', name: 'Bookshelf Large', nameAr: 'رف كتب كبير', warehouse: 'Jeddah Branch', warehouseAr: 'فرع جدة', quantity: 45, avgCost: 450),
            InventoryItem(code: 'ITM-022', name: 'Visitor Chair', nameAr: 'كرسي زوّار', warehouse: 'Riyadh Main', warehouseAr: 'الرياض الرئيسي', quantity: 180, avgCost: 280),
            InventoryItem(code: 'ITM-023', name: 'Standing Desk', nameAr: 'مكتب وقوف', warehouse: 'Dammam Branch', warehouseAr: 'فرع الدمام', quantity: 40, avgCost: 1800),
            InventoryItem(code: 'ITM-024', name: 'Reception Counter', nameAr: 'كاونتر استقبال', warehouse: 'Jeddah Branch', warehouseAr: 'فرع جدة', quantity: 12, avgCost: 2800),
            InventoryItem(code: 'ITM-025', name: 'Office Sofa 3-Seater', nameAr: 'كنبة مكتب 3 مقاعد', warehouse: 'Riyadh Main', warehouseAr: 'الرياض الرئيسي', quantity: 25, avgCost: 1500),
            InventoryItem(code: 'ITM-026', name: 'Mobile Pedestal', nameAr: 'خزانة متحركة', warehouse: 'Dammam Branch', warehouseAr: 'فرع الدمام', quantity: 100, avgCost: 380),
          ], titleAr: 'الأثاث المكتبي',),
          InventoryCategory('Stationery', [
            InventoryItem(code: 'ITM-301', name: 'A4 Paper Ream', nameAr: 'رزمة ورق A4', warehouse: 'Riyadh Main', warehouseAr: 'الرياض الرئيسي', quantity: 1000, avgCost: 15),
            InventoryItem(code: 'ITM-305', name: 'Ballpoint Pens (Box of 12)', nameAr: 'أقلام حبر (علبة 12)', warehouse: 'Jeddah Branch', warehouseAr: 'فرع جدة', quantity: 500, avgCost: 10),
            InventoryItem(code: 'ITM-310', name: 'Sticky Notes Pack', nameAr: 'ملاحظات لاصقة', warehouse: 'Dammam Branch', warehouseAr: 'فرع الدمام', quantity: 800, avgCost: 8),
            InventoryItem(code: 'ITM-315', name: 'Stapler Heavy Duty', nameAr: 'دبّاسة قوية', warehouse: 'Riyadh Main', warehouseAr: 'الرياض الرئيسي', quantity: 300, avgCost: 35),
            InventoryItem(code: 'ITM-320', name: 'File Folders (Box)', nameAr: 'مجلدات ملفات (علبة)', warehouse: 'Jeddah Branch', warehouseAr: 'فرع جدة', quantity: 600, avgCost: 25),
          ], titleAr: 'القرطاسية',),
        ],
      );
}

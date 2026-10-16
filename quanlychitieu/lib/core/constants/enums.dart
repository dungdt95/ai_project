enum TransactionType { income, expense }

enum DepositStatus { active, closed }

enum LoanStatus { unpaid, partial, paid, overdue }

enum PaymentMethod { cash, card, transfer }

enum ReportPeriod { week, month, quarter, year, custom }

extension TransactionTypeExt on TransactionType {
  String get label => this == TransactionType.income ? 'Thu nhập' : 'Chi tiêu';
  String get value => this == TransactionType.income ? 'income' : 'expense';
  static TransactionType fromString(String v) =>
      v == 'income' ? TransactionType.income : TransactionType.expense;
}

extension DepositStatusExt on DepositStatus {
  String get label => this == DepositStatus.active ? 'Đang hiệu lực' : 'Đã tất toán';
  String get value => this == DepositStatus.active ? 'active' : 'closed';
  static DepositStatus fromString(String v) =>
      v == 'active' ? DepositStatus.active : DepositStatus.closed;
}

extension LoanStatusExt on LoanStatus {
  String get label {
    switch (this) {
      case LoanStatus.unpaid: return 'Chưa trả';
      case LoanStatus.partial: return 'Trả một phần';
      case LoanStatus.paid: return 'Đã trả đủ';
      case LoanStatus.overdue: return 'Quá hạn';
    }
  }
  String get value {
    switch (this) {
      case LoanStatus.unpaid: return 'unpaid';
      case LoanStatus.partial: return 'partial';
      case LoanStatus.paid: return 'paid';
      case LoanStatus.overdue: return 'overdue';
    }
  }
  static LoanStatus fromString(String v) {
    switch (v) {
      case 'partial': return LoanStatus.partial;
      case 'paid': return LoanStatus.paid;
      case 'overdue': return LoanStatus.overdue;
      default: return LoanStatus.unpaid;
    }
  }
}

extension PaymentMethodExt on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash: return 'Tiền mặt';
      case PaymentMethod.card: return 'Thẻ';
      case PaymentMethod.transfer: return 'Chuyển khoản';
    }
  }
  String get value {
    switch (this) {
      case PaymentMethod.cash: return 'cash';
      case PaymentMethod.card: return 'card';
      case PaymentMethod.transfer: return 'transfer';
    }
  }
  static PaymentMethod? fromString(String? v) {
    switch (v) {
      case 'cash': return PaymentMethod.cash;
      case 'card': return PaymentMethod.card;
      case 'transfer': return PaymentMethod.transfer;
      default: return null;
    }
  }
}

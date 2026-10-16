class InvoiceCounts {
  final int paid;
  final int unpaid;
  final int cancelled;

  const InvoiceCounts({this.paid = 0, this.unpaid = 0, this.cancelled = 0});

  int get total => paid + unpaid + cancelled;
}

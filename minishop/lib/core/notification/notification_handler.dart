import '../../data/models/notification_log.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/notification_log_repository.dart';
import 'bank_notification_parser.dart';

/// Shared pipeline for turning a raw banking notification into an
/// invoice-paid confirmation. Used both by the headless background isolate
/// (real notifications, app may be closed) and by the in-app debug
/// "simulate notification" tool, so the matching logic only lives once.
class NotificationHandler {
  static Future<NotificationLog> handle({
    required String packageName,
    required String rawText,
  }) async {
    final invoiceRepo = InvoiceRepository();
    final logRepo = NotificationLogRepository();

    final parsed = BankNotificationParser.parse(packageName, rawText);

    int? matchedInvoiceId;
    String matchStatus;

    if (parsed.invoiceCode != null) {
      final invoice = await invoiceRepo.getUnpaidByCode(parsed.invoiceCode!);
      if (invoice != null) {
        matchedInvoiceId = invoice.id;
        matchStatus = NotificationLog.matchAuto;
      } else {
        matchStatus = NotificationLog.matchNone;
      }
    } else if (parsed.amount != null) {
      final candidates = await invoiceRepo.getUnpaidByAmount(parsed.amount!);
      if (candidates.length == 1) {
        matchedInvoiceId = candidates.first.id;
        matchStatus = NotificationLog.matchAuto;
      } else if (candidates.length > 1) {
        matchStatus = NotificationLog.matchAmbiguous;
      } else {
        matchStatus = NotificationLog.matchNone;
      }
    } else {
      matchStatus = NotificationLog.matchNone;
    }

    final logId = await logRepo.insert(NotificationLog(
      sourceApp: packageName,
      rawText: rawText,
      parsedAmount: parsed.amount,
      parsedCode: parsed.invoiceCode,
      receivedAt: DateTime.now(),
      matchedInvoiceId: matchedInvoiceId,
      matchStatus: matchStatus,
    ));

    if (matchedInvoiceId != null) {
      await invoiceRepo.markPaid(
        matchedInvoiceId,
        paidMethod: 'bank_transfer',
        matchedNotificationId: logId,
      );
    }

    return NotificationLog(
      id: logId,
      sourceApp: packageName,
      rawText: rawText,
      parsedAmount: parsed.amount,
      parsedCode: parsed.invoiceCode,
      receivedAt: DateTime.now(),
      matchedInvoiceId: matchedInvoiceId,
      matchStatus: matchStatus,
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:finance_app/domain/usecases/notify_transaction_usecase.dart';

class LocalPushNotificationService implements PushNotificationService {
  @override
  Future<NotifyTransactionResult> sendNotification(
    NotificationPayload payload,
    NotificationPriority priority,
  ) async {
    debugPrint('[${priority.name}] ${payload.title}: ${payload.body}');
    return NotifyTransactionResult(
      success: true,
      notificationId: 'local_${payload.transactionId}',
      payload: payload,
    );
  }

  @override
  Future<bool> isServiceAvailable() async => true;

  @override
  Future<String?> getDeviceToken() async => null;
}

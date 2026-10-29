import 'package:finance_app/domain/usecases/notify_transaction_usecase.dart';

/// Notificación enviada, registrada por [RecordingPushNotificationService].
class SentNotification {
  final NotificationPayload payload;
  final NotificationPriority priority;

  const SentNotification(this.payload, this.priority);
}

/// Implementación de [PushNotificationService] que registra lo enviado, para
/// verificar en las pruebas de integración qué recibiría el usuario.
class RecordingPushNotificationService implements PushNotificationService {
  final List<SentNotification> sent = [];

  /// Permite simular que el servicio de notificaciones no está disponible.
  bool isAvailable = true;

  @override
  Future<NotifyTransactionResult> sendNotification(
    NotificationPayload payload,
    NotificationPriority priority,
  ) async {
    sent.add(SentNotification(payload, priority));
    return NotifyTransactionResult(
      success: true,
      notificationId: 'test_${payload.transactionId}',
      payload: payload,
    );
  }

  @override
  Future<bool> isServiceAvailable() async => isAvailable;

  @override
  Future<String?> getDeviceToken() async => 'test_device_token';
}

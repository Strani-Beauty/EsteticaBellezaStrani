import '../../domain/entities/payment_intent_entity.dart';

/// Modelo de respuesta de la edge function `create-payment-intent`.
class PaymentIntentModel {
  final String clientSecret;
  final String paymentIntentId;
  final double amount;
  final String currency;

  const PaymentIntentModel({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.amount,
    this.currency = 'usd',
  });

  factory PaymentIntentModel.fromJson(Map<String, dynamic> json) {
    return PaymentIntentModel(
      clientSecret: json['client_secret'] as String? ?? '',
      paymentIntentId: json['paymentIntentId']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'usd',
    );
  }

  PaymentIntentEntity toEntity() {
    return PaymentIntentEntity(
      clientSecret: clientSecret,
      paymentIntentId: paymentIntentId,
      amount: amount,
      currency: currency,
    );
  }
}
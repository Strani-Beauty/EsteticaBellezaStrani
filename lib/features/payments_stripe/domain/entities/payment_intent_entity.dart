/// Resultado de crear un PaymentIntent en Stripe (edge function).
class PaymentIntentEntity {
  final String clientSecret;
  final String paymentIntentId;
  final double amount;
  final String currency;

  const PaymentIntentEntity({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.amount,
    this.currency = 'usd',
  });
}
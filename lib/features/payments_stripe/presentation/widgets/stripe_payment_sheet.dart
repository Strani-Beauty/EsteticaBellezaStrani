import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../../app/config/app_env.dart';
import '../../../../app/core/di/injection.dart';
import '../cubits/payments_cubit.dart';

/// true si hay una publishable key configurada en `.env`.
bool stripeConfigurado() => AppEnv.stripePublishableKey.isNotEmpty;

const String kStripeMerchantName = 'Estética y Belleza Strani';

/// Cobra [monto] con el PaymentSheet de Stripe y devuelve el id del
/// PaymentIntent confirmado.
///
/// * Sin clave configurada → devuelve una referencia simulada (`STRIPE_SIM_…`)
///   para no interrumpir el flujo en entornos de demo.
/// * Si el usuario cancela o la pasarela falla → devuelve `null`.
Future<String?> procesarPagoStripe({
  required double monto,
  required String concepto,
  String? solicitudId,
  String? citaId,
}) async {
  if (!stripeConfigurado()) {
    return 'STRIPE_SIM_${DateTime.now().millisecondsSinceEpoch}';
  }

  try {
    final intent = await sl<PaymentsCubit>().crearIntent(
      monto: monto,
      concepto: concepto,
      solicitudId: solicitudId,
      citaId: citaId,
    );
    if (intent == null) return null;

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: kStripeMerchantName,
        paymentIntentClientSecret: intent.clientSecret,
        style: ThemeMode.light,
      ),
    );
    await Stripe.instance.presentPaymentSheet();
    return intent.paymentIntentId;
  } on StripeException {
    return null; // usuario canceló o método de pago no completado
  } catch (e) {
    debugPrint('⚠️ [procesarPagoStripe] $e');
    return null;
  }
}
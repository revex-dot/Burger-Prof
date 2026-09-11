import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_stripe/flutter_stripe.dart';

/// Thin client over the Cloud Functions in `functions/src/index.ts`.
///
/// Card data never touches our servers: the backend creates a PaymentIntent /
/// Subscription and returns a client secret; Stripe's PaymentSheet collects
/// the card on-device. Fees, charity routing and receipts are handled by the
/// Stripe webhook on the backend.
class PaymentService {
  PaymentService(this._functions);
  final FirebaseFunctions _functions;

  /// Donation processing fee, in basis points (2.9% + Stripe's fixed 30¢ is
  /// covered by this). Must match `DONATION_FEE_BPS` in the backend.
  static const donationFeeBps = 500;

  static int feeForAmount(int amountCents) =>
      (amountCents * donationFeeBps / 10000).round();

  Future<void> donate({
    required String charityId,
    required int amountCents,
    required String currency,
    String? message,
  }) async {
    final result = await _functions.httpsCallable('createDonationIntent').call({
      'charityId': charityId,
      'amountCents': amountCents,
      'currency': currency,
      'message': message,
    });
    await _presentSheet(Map<String, dynamic>.from(result.data as Map));
  }

  Future<void> subscribe({required String tier}) async {
    final result = await _functions
        .httpsCallable('createSubscription')
        .call({'tier': tier});
    await _presentSheet(Map<String, dynamic>.from(result.data as Map));
  }

  Future<void> checkoutCart({
    required List<Map<String, dynamic>> items,
    required String? charityId,
    required String currency,
  }) async {
    final result = await _functions.httpsCallable('createOrderIntent').call({
      'items': items,
      'charityId': charityId,
      'currency': currency,
    });
    await _presentSheet(Map<String, dynamic>.from(result.data as Map));
  }

  Future<String> customerPortalUrl() async {
    final result = await _functions.httpsCallable('createPortalLink').call();
    return (result.data as Map)['url'] as String;
  }

  Future<void> _presentSheet(Map<String, dynamic> data) async {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: 'Pawsitive Cat',
        paymentIntentClientSecret: data['clientSecret'] as String,
        customerId: data['customerId'] as String?,
        customerEphemeralKeySecret: data['ephemeralKey'] as String?,
        style: ThemeMode.system,
        applePay: const PaymentSheetApplePay(merchantCountryCode: 'US'),
        googlePay: const PaymentSheetGooglePay(
          merchantCountryCode: 'US',
          testEnv: true,
        ),
      ),
    );
    await Stripe.instance.presentPaymentSheet();
  }
}

final paymentServiceProvider =
    Provider((_) => PaymentService(FirebaseFunctions.instance));

class PaymentAuthorization {
  const PaymentAuthorization({
    required this.id,
    required this.amount,
    required this.currency,
  });

  final String id;
  final double amount;
  final String currency;
}

abstract class PaymentGateway {
  Future<PaymentAuthorization> authorize({
    required String customerId,
    required double amount,
    required String currency,
  });

  Future<void> capture({
    required String authorizationId,
    required double finalAmount,
  });

  Future<void> cancelAuthorization(String authorizationId);
}

class MockPaymentGateway implements PaymentGateway {
  @override
  Future<PaymentAuthorization> authorize({
    required String customerId,
    required double amount,
    required String currency,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    return PaymentAuthorization(
      id: 'pi_mock_${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
      currency: currency,
    );
  }

  @override
  Future<void> capture({
    required String authorizationId,
    required double finalAmount,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
  }

  @override
  Future<void> cancelAuthorization(String authorizationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }
}

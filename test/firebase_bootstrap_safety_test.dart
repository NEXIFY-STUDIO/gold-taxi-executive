import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('firebase bootstrap paths no longer invoke driver self-bootstrap',
      () async {
    final runtimeGateway = File(
      'lib/src/data/repositories/firebase_runtime_gateway.dart',
    );
    final clientProfileRepository = File(
      'lib/src/services/push/firebase_client_profile_repository.dart',
    );

    expect(await runtimeGateway.exists(), isTrue);
    expect(await clientProfileRepository.exists(), isTrue);

    final runtimeGatewaySource = await runtimeGateway.readAsString();
    final clientProfileSource = await clientProfileRepository.readAsString();

    expect(runtimeGatewaySource, isNot(contains('bootstrapDriverProfile')));
    expect(clientProfileSource, isNot(contains('bootstrapDriverProfile')));
    expect(runtimeGatewaySource, contains('bootstrapUserProfile'));
    expect(clientProfileSource, contains('bootstrapUserProfile'));
  });
}

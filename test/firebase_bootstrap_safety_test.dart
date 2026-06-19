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
    final authGateway = File(
      'lib/src/services/auth/firebase_auth_gateway.dart',
    );

    expect(await runtimeGateway.exists(), isTrue);
    expect(await clientProfileRepository.exists(), isTrue);
    expect(await authGateway.exists(), isTrue);

    final runtimeGatewaySource = await runtimeGateway.readAsString();
    final clientProfileSource = await clientProfileRepository.readAsString();
    final authGatewaySource = await authGateway.readAsString();

    expect(runtimeGatewaySource, isNot(contains('bootstrapDriverProfile')));
    expect(clientProfileSource, isNot(contains('bootstrapDriverProfile')));
    expect(authGatewaySource, isNot(contains('bootstrapDriverProfile')));
    expect(authGatewaySource, contains('bootstrapUserProfile'));
    expect(authGatewaySource, contains('GoogleAuthProvider'));
    expect(runtimeGatewaySource, isNot(contains('signInAnonymously')));
    expect(clientProfileSource, isNot(contains('signInAnonymously')));
  });
}

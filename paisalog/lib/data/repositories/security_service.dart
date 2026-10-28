/// SecurityService — local_auth + flutter_secure_storage.
///
/// NOTE: Verified biometric capability is only claimed when tested on the
/// actual iPhone. On Windows dev machine, all calls fall back gracefully.
library;

import 'dart:async';
import '../../domain/services/service_contracts.dart';

class DefaultSecurityService implements SecurityService {
  bool _isLocked = false;
  final _lockedController = StreamController<bool>.broadcast();

  @override
  Future<bool> isBiometricAvailable() async {
    // TODO: replace with real local_auth check on iOS
    // import 'package:local_auth/local_auth.dart';
    // final auth = LocalAuthentication();
    // return auth.canCheckBiometrics;
    return false; // conservative: unknown until tested
  }

  @override
  Future<bool> requestUnlock({String? reason}) async {
    // TODO: replace with real local_auth prompt on iOS
    // final auth = LocalAuthentication();
    // return auth.authenticate(localizedReason: reason ?? 'Unlock PaisaLog');
    _isLocked = false;
    _lockedController.add(false);
    return true;
  }

  @override
  void lockApp() {
    _isLocked = true;
    _lockedController.add(true);
  }

  @override
  bool get isLocked => _isLocked;

  @override
  Stream<bool> watchLocked() => _lockedController.stream;

  void dispose() => _lockedController.close();
}


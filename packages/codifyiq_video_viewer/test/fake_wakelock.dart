import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// A stand-in for the wake lock plugin that records whether it is held.
class FakeWakelock extends WakelockPlusPlatformInterface {
  /// Whether the screen is being kept on.
  bool isEnabled = false;

  /// Installs a fresh fake and returns it.
  static FakeWakelock install() {
    final fake = FakeWakelock();
    wakelockPlusPlatformInstance = fake;
    return fake;
  }

  @override
  Future<void> toggle({required bool enable}) async => isEnabled = enable;

  @override
  Future<bool> get enabled async => isEnabled;
}

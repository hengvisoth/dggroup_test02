import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_ip_platform_interface.dart';

/// An implementation of [DeviceIpPlatform] that uses method channels.
class MethodChannelDeviceIp extends DeviceIpPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('device_ip');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device_ip_method_channel.dart';

abstract class DeviceIpPlatform extends PlatformInterface {
  /// Constructs a DeviceIpPlatform.
  DeviceIpPlatform() : super(token: _token);

  static final Object _token = Object();

  static DeviceIpPlatform _instance = MethodChannelDeviceIp();

  /// The default instance of [DeviceIpPlatform] to use.
  ///
  /// Defaults to [MethodChannelDeviceIp].
  static DeviceIpPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DeviceIpPlatform] when
  /// they register themselves.
  static set instance(DeviceIpPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}

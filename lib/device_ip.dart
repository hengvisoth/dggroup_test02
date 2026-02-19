
import 'device_ip_platform_interface.dart';

class DeviceIp {
  Future<String?> getPlatformVersion() {
    return DeviceIpPlatform.instance.getPlatformVersion();
  }
}

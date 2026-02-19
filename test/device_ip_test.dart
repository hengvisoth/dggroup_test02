import 'package:flutter_test/flutter_test.dart';
import 'package:device_ip/device_ip.dart';
import 'package:device_ip/device_ip_platform_interface.dart';
import 'package:device_ip/device_ip_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDeviceIpPlatform
    with MockPlatformInterfaceMixin
    implements DeviceIpPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final DeviceIpPlatform initialPlatform = DeviceIpPlatform.instance;

  test('$MethodChannelDeviceIp is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDeviceIp>());
  });

  test('getPlatformVersion', () async {
    DeviceIp deviceIpPlugin = DeviceIp();
    MockDeviceIpPlatform fakePlatform = MockDeviceIpPlatform();
    DeviceIpPlatform.instance = fakePlatform;

    expect(await deviceIpPlugin.getPlatformVersion(), '42');
  });
}

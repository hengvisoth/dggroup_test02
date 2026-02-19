import 'package:device_ip/device_ip_platform_interface.dart';
import 'package:device_ip/model/result_model.dart';
import 'package:flutter/services.dart';

enum NetworkType { any, wifi, mobile }

class DeviceIp {
  static const MethodChannel _channel = MethodChannel('device_ip');

  static final Map<NetworkType, ({IpResult value, DateTime time})> _cache = {};
  static Duration defaultCacheTtl = const Duration(seconds: 10);

  static Future<IpResult> getIp({NetworkType type = NetworkType.any, bool useCache = true, Duration? cacheTtl}) async {
    final ttl = cacheTtl ?? defaultCacheTtl;

    if (useCache) {
      final entry = _cache[type];
      if (entry != null && DateTime.now().difference(entry.time) <= ttl) {
        return entry.value;
      }
    }

    final map = await _channel.invokeMapMethod<String, dynamic>('getIp', {
      'network': type.name, // any | wifi | mobile
      'useNativeCache': true,
      'nativeCacheTtlMs': ttl.inMilliseconds,
    });

    final res = IpResult.fromMap(map ?? const {});
    _cache[type] = (value: res, time: DateTime.now());
    return res;
  }

  static void clearCache() => _cache.clear();

  Future<String?> getPlatformVersion() {
    return DeviceIpPlatform.instance.getPlatformVersion();
  }
}

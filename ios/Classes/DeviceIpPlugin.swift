import Flutter
import UIKit
import Darwin

public class DeviceIpPlugin: NSObject, FlutterPlugin {
  private struct CacheEntry {
    let ts: Int64
    let data: [String: Any]
  }

  private struct IpPair {
    var ipv4 = ""
    var ipv6 = ""
    var linkLocalIpv6 = ""
  }

  private static var cache: [String: CacheEntry] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "device_ip", binaryMessenger: registrar.messenger())
    let instance = DeviceIpPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getIp":
      let args = call.arguments as? [String: Any]
      let network = ((args?["network"] as? String) ?? "any").lowercased()
      let useNativeCache = (args?["useNativeCache"] as? Bool) ?? true
      let nativeCacheTtlMs = Self.toInt64(args?["nativeCacheTtlMs"]) ?? 10_000

      if useNativeCache, let cached = Self.cache[network] {
        let ageMs = Self.nowMs() - cached.ts
        if ageMs <= nativeCacheTtlMs {
          result(cached.data)
          return
        }
      }

      let data = getIpAddresses(networkChoice: network)
      if useNativeCache {
        Self.cache[network] = CacheEntry(ts: Self.nowMs(), data: data)
      }
      result(data)
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func nowMs() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
  }

  private static func toInt64(_ value: Any?) -> Int64? {
    switch value {
    case let v as Int:
      return Int64(v)
    case let v as Int64:
      return v
    case let v as NSNumber:
      return v.int64Value
    case let v as Double:
      return Int64(v)
    default:
      return nil
    }
  }

  private func getIpAddresses(networkChoice: String) -> [String: Any] {
    let interfaces = collectInterfaceIps()
    guard let picked = pickInterface(interfaces: interfaces, networkChoice: networkChoice) else {
      return noConnection()
    }

    let ipv4 = picked.pair.ipv4
    let ipv6 = picked.pair.ipv6.isEmpty ? picked.pair.linkLocalIpv6 : picked.pair.ipv6

    if ipv4.isEmpty && ipv6.isEmpty {
      return noConnection()
    }

    return [
      "ok": true,
      "ipv4": ipv4,
      "ipv6": ipv6,
      "connection": picked.connection,
      "message": "OK",
    ]
  }

  private func collectInterfaceIps() -> [String: IpPair] {
    var result: [String: IpPair] = [:]
    var ifaddr: UnsafeMutablePointer<ifaddrs>?

    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
      return result
    }
    defer { freeifaddrs(ifaddr) }

    var cursor: UnsafeMutablePointer<ifaddrs>? = first
    while let current = cursor {
      let iface = current.pointee
      cursor = iface.ifa_next

      let flags = Int32(iface.ifa_flags)
      let isUp = (flags & IFF_UP) != 0
      let isRunning = (flags & IFF_RUNNING) != 0
      let isLoopback = (flags & IFF_LOOPBACK) != 0
      guard isUp && isRunning && !isLoopback else { continue }

      guard let addrPtr = iface.ifa_addr else { continue }
      let family = Int32(addrPtr.pointee.sa_family)
      guard family == AF_INET || family == AF_INET6 else { continue }

      guard let ip = ipString(from: addrPtr, family: family) else { continue }
      let name = String(cString: iface.ifa_name)

      var pair = result[name] ?? IpPair()
      if family == AF_INET {
        if pair.ipv4.isEmpty {
          pair.ipv4 = ip
        }
      } else {
        if ip == "::" || isMulticastIpv6(ip) {
          continue
        }
        if isLinkLocalIpv6(ip) {
          if pair.linkLocalIpv6.isEmpty {
            pair.linkLocalIpv6 = ip
          }
        } else if pair.ipv6.isEmpty {
          pair.ipv6 = ip
        }
      }
      result[name] = pair
    }

    return result
  }

  private func pickInterface(
    interfaces: [String: IpPair],
    networkChoice: String
  ) -> (connection: String, pair: IpPair)? {
    func hasAddress(_ pair: IpPair) -> Bool {
      !pair.ipv4.isEmpty || !pair.ipv6.isEmpty || !pair.linkLocalIpv6.isEmpty
    }

    let wifiNames = interfaces.keys.filter { $0.hasPrefix("en") }.sorted()
    let mobileNames = interfaces.keys.filter { $0.hasPrefix("pdp_ip") }.sorted()

    switch networkChoice {
    case "wifi":
      for name in wifiNames {
        guard let pair = interfaces[name], hasAddress(pair) else { continue }
        return ("wifi", pair)
      }
      return nil
    case "mobile":
      for name in mobileNames {
        guard let pair = interfaces[name], hasAddress(pair) else { continue }
        return ("mobile", pair)
      }
      return nil
    default:
      for name in wifiNames {
        guard let pair = interfaces[name], hasAddress(pair) else { continue }
        return ("wifi", pair)
      }
      for name in mobileNames {
        guard let pair = interfaces[name], hasAddress(pair) else { continue }
        return ("mobile", pair)
      }
      let otherNames = interfaces.keys
        .filter { !wifiNames.contains($0) && !mobileNames.contains($0) }
        .sorted()
      for name in otherNames {
        guard let pair = interfaces[name], hasAddress(pair) else { continue }
        return ("none", pair)
      }
      return nil
    }
  }

  private func ipString(from addr: UnsafePointer<sockaddr>, family: Int32) -> String? {
    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
    let len: socklen_t = family == AF_INET
      ? socklen_t(MemoryLayout<sockaddr_in>.size)
      : socklen_t(MemoryLayout<sockaddr_in6>.size)

    let rc = getnameinfo(addr, len, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
    guard rc == 0 else { return nil }

    let raw = String(cString: host)
    let normalized = raw.split(separator: "%", maxSplits: 1, omittingEmptySubsequences: false)
      .first
      .map(String.init) ?? raw
    return normalized.isEmpty ? nil : normalized
  }

  private func isLinkLocalIpv6(_ ip: String) -> Bool {
    let lower = ip.lowercased()
    guard let first = lower.split(separator: ":").first, let prefix = UInt16(first, radix: 16) else {
      return false
    }
    return (prefix & 0xffc0) == 0xfe80
  }

  private func isMulticastIpv6(_ ip: String) -> Bool {
    ip.lowercased().hasPrefix("ff")
  }

  private func noConnection() -> [String: Any] {
    [
      "ok": false,
      "ipv4": "",
      "ipv6": "",
      "connection": "none",
      "message": "No internet connection",
    ]
  }
}

package com.example.device_ip

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.LinkAddress
import android.net.LinkProperties
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.Inet6Address

class DeviceIpPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var appContext: Context

  companion object {
    private data class CacheEntry(val ts: Long, val data: Map<String, Any>)
    private val cache = HashMap<String, CacheEntry>()
  }

  override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    appContext = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "device_ip")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
    when (call.method) {
      "getIp" -> {
        val network = (call.argument<String>("network") ?: "any").lowercase()
        val useNativeCache = call.argument<Boolean>("useNativeCache") ?: true
        val nativeCacheTtlMs = call.argument<Number>("nativeCacheTtlMs")?.toLong() ?: 10_000L

        if (useNativeCache) {
          val cached = cache[network]
          if (cached != null && (System.currentTimeMillis() - cached.ts) <= nativeCacheTtlMs) {
            result.success(cached.data)
            return
          }
        }

        val data = getIpAddresses(network)
        if (useNativeCache) {
          cache[network] = CacheEntry(System.currentTimeMillis(), data)
        }
        result.success(data)
      }
      else -> result.notImplemented()
    }
  }

  private fun getIpAddresses(networkChoice: String): Map<String, Any> {
    val cm = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    val desiredTransport = when (networkChoice) {
      "wifi" -> NetworkCapabilities.TRANSPORT_WIFI
      "mobile" -> NetworkCapabilities.TRANSPORT_CELLULAR
      else -> null
    }

    val chosenNetwork = pickNetwork(cm, desiredTransport) ?: return noConnection()

    val caps = cm.getNetworkCapabilities(chosenNetwork)
    if (desiredTransport != null && caps?.hasTransport(desiredTransport) != true) {
      return noConnection()
    }

    val connection = when {
      caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "wifi"
      caps?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "mobile"
      else -> "none"
    }

    val lp: LinkProperties = cm.getLinkProperties(chosenNetwork) ?: return noConnection()
    val (ipv4, ipv6) = extractIps(lp.linkAddresses)

    if (ipv4.isEmpty() && ipv6.isEmpty()) return noConnection()

    return mapOf(
      "ok" to true,
      "ipv4" to ipv4,
      "ipv6" to ipv6,
      "connection" to connection,
      "message" to "OK"
    )
  }

  private fun pickNetwork(cm: ConnectivityManager, desiredTransport: Int?): Network? {
    val networks = cm.allNetworks ?: return null

    if (desiredTransport != null) {
      for (n in networks) {
        val caps = cm.getNetworkCapabilities(n) ?: continue
        if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            caps.hasTransport(desiredTransport)) {
          return n
        }
      }
      return null
    }

    
    val active = cm.activeNetwork
    if (active != null) return active

    
    for (n in networks) {
      val caps = cm.getNetworkCapabilities(n) ?: continue
      if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) return n
    }
    return null
  }

  private fun extractIps(linkAddresses: List<LinkAddress>): Pair<String, String> {
    var ipv4 = ""
    var ipv6 = ""

    for (la in linkAddresses) {
      val addr = la.address ?: continue
      if (addr.isLoopbackAddress) continue

      when (addr) {
        is Inet4Address -> if (ipv4.isEmpty() && !addr.isAnyLocalAddress) {
          ipv4 = addr.hostAddress ?: ""
        }
        is Inet6Address -> if (ipv6.isEmpty() &&
          !addr.isLinkLocalAddress &&
          !addr.isMulticastAddress &&
          !addr.isAnyLocalAddress
        ) {
          val raw = addr.hostAddress ?: ""
          ipv6 = raw.substringBefore('%') // remove scope id
        }
      }

      if (ipv4.isNotEmpty() && ipv6.isNotEmpty()) break
    }

    return Pair(ipv4, ipv6)
  }

  private fun noConnection(): Map<String, Any> {
    return mapOf(
      "ok" to false,
      "ipv4" to "",
      "ipv6" to "",
      "connection" to "none",
      "message" to "No internet connection"
    )
  }
}

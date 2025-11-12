package com.unicornsonlsd.finamp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.unicornsonlsd.finamp/network"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getVpnIp") {
                val vpnIp = getVpnIpAddress()
                if (vpnIp != null) {
                    result.success(vpnIp)
                } else {
                    result.error("UNAVAILABLE", "VPN IP not available", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getVpnIpAddress(): String? {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                val addresses = networkInterface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val address = addresses.nextElement()
                    if (!address.isLoopbackAddress && !address.isLinkLocalAddress) {
                        val ip = address.hostAddress
                        // Check if it's an IPv4 address starting with 100.
                        if (ip != null && ip.contains(".") && ip.startsWith("100.")) {
                            return ip
                        }
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }
}

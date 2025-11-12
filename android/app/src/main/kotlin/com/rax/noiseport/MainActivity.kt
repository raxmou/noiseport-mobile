package com.rax.noiseport

import android.util.Log

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.rax.noiseport/network"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "Configuring Flutter Engine with channel: $CHANNEL")
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "Method called: ${call.method}")
            if (call.method == "getVpnIp") {
                val vpnIp = getVpnIpAddress()
                Log.d(TAG, "VPN IP: $vpnIp")
                if (vpnIp != null) {
                    result.success(vpnIp)
                } else {
                    result.error("UNAVAILABLE", "VPN IP not available", null)
                }
            } else {
                result.notImplemented()
            }
        }
        
        Log.d(TAG, "Method channel configured successfully")
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
                            Log.d(TAG, "Found VPN IP: $ip")
                            return ip
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting VPN IP", e)
            e.printStackTrace()
        }
        return null
    }
}

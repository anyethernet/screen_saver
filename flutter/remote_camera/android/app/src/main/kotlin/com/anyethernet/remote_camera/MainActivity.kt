package com.anyethernet.remote_camera

import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.ConnectException
import java.net.InetSocketAddress
import java.net.Socket

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.anyethernet.remote_camera/native",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "tailscaleInstalled" -> result.success(isTailscaleInstalled())
                "openTailscale" -> result.success(openTailscale())
                "tailscaleConnected" -> {
                    Thread {
                        val connected = probeTailscale()
                        runOnUiThread {
                            try {
                                result.success(connected)
                            } catch (_: Exception) {
                            }
                        }
                    }.start()
                }
                "startForeground" -> {
                    try {
                        val intent = Intent(this, CameraForegroundService::class.java)
                        intent.putExtra("title", call.argument<String>("title"))
                        intent.putExtra("text", call.argument<String>("text"))
                        if (Build.VERSION.SDK_INT >= 26) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "stopForeground" -> {
                    stopService(Intent(this, CameraForegroundService::class.java))
                    result.success(true)
                }
                "acquireMulticast" -> {
                    result.success(acquireMulticast())
                }
                "releaseMulticast" -> {
                    releaseMulticast()
                    result.success(true)
                }
                "dimScreen" -> {
                    dimScreen(call.argument<Boolean>("dim") == true)
                    result.success(true)
                }
                "batteryUnrestricted" -> result.success(batteryUnrestricted())
                "requestBatteryUnrestricted" -> {
                    requestBatteryUnrestricted()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isTailscaleInstalled(): Boolean {
        return packageManager.getLaunchIntentForPackage("com.tailscale.ipn") != null
    }

    private fun openTailscale(): String {
        val launch = packageManager.getLaunchIntentForPackage("com.tailscale.ipn")
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launch)
            return "opened"
        }
        return try {
            val market = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("market://details?id=com.tailscale.ipn"),
            )
            market.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(market)
            "store"
        } catch (_: Exception) {
            "missing"
        }
    }

    private fun probeTailscale(): Boolean {
        return try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress("100.100.100.100", 80), 1500)
            }
            true
        } catch (error: Exception) {
            val message = error.message?.lowercase() ?: ""
            error is ConnectException || message.contains("refused") || message.contains("reset")
        }
    }

    private fun acquireMulticast(): Boolean {
        return try {
            val wifi = applicationContext.getSystemService(WifiManager::class.java) ?: return false
            val lock = multicastLock ?: wifi.createMulticastLock("remote_camera:discover").also {
                it.setReferenceCounted(false)
                multicastLock = it
            }
            if (!lock.isHeld) lock.acquire()
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun releaseMulticast() {
        try {
            multicastLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {
            // The lock was already released.
        }
    }

    private fun dimScreen(dim: Boolean) {
        val params = window.attributes
        params.screenBrightness = if (dim) 0.01f else WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
        window.attributes = params
        if (dim) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    private fun batteryUnrestricted(): Boolean {
        val power = getSystemService(PowerManager::class.java) ?: return true
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestBatteryUnrestricted() {
        if (batteryUnrestricted()) return
        val intent = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:$packageName"),
        )
        startActivity(intent)
    }
}

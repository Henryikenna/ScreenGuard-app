package com.screenguard.app

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.screenguard.app/overlay"
        private const val OVERLAY_PERMISSION_REQUEST_CODE = 1234
    }

    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startOverlay" -> {
                    if (Settings.canDrawOverlays(this)) {
                        val intent = Intent(this, OverlayService::class.java)
                        startForegroundService(intent)
                        result.success(true)
                    } else {
                        result.error("NO_PERMISSION", "Overlay permission not granted", null)
                    }
                }
                "stopOverlay" -> {
                    val intent = Intent(this, OverlayService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                "isOverlayActive" -> {
                    result.success(OverlayService.isRunning)
                }
                "checkOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                    startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
            channel.invokeMethod("onPermissionResult", Settings.canDrawOverlays(this))
        }
    }
}

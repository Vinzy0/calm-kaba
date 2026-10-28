package com.example.thesis_anxiety

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration

class MainActivity : FlutterActivity() {
    private var panel: CameraPanel? = null
    private var sink: EventChannel.EventSink? = null
    private var diagnostics = false
    private var modelFolder = "behavior"
    private var trackingDelegate = "CPU"
    private var lockFps30 = true
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        EventChannel(messenger,"calm/detection/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events }
            override fun onCancel(arguments: Any?) { panel?.stop(); sink = null }
        })
        flutterEngine.platformViewsController.registry.registerViewFactory("calm/camera",object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
            override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                panel?.stop()
                return CameraPanel(this@MainActivity) { sink?.success(it) }.also { panel = it; it.diagnosticsEnabled = diagnostics; it.modelFolder = modelFolder; it.requestedDelegate = trackingDelegate; it.lockFps30 = lockFps30 }
            }
        })
        MethodChannel(messenger,"calm/detection").setMethodCallHandler { call,result ->
            when (call.method) {
                "start" -> if (panel == null) result.error("camera_not_ready","Wait for the preview to open",null) else { panel!!.start(); result.success(null) }
                "stop" -> { panel?.stop(); result.success(null) }
                "models" -> { modelFolder = if (call.arguments == "v6") "behavior_v6" else "behavior"; panel?.modelFolder = modelFolder; result.success(null) }
                "delegate" -> { trackingDelegate = if (call.arguments == "GPU") "GPU" else "CPU"; panel?.requestedDelegate = trackingDelegate; result.success(null) }
                "fpsLock" -> { lockFps30 = call.arguments == true; panel?.lockFps30 = lockFps30; result.success(null) }
                "diagnostics" -> { diagnostics = call.arguments == true; panel?.diagnosticsEnabled = diagnostics; result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
    fun detachPanel(value: CameraPanel) { if (panel === value) panel = null }
    fun requestCameraPermission() { requestPermissions(arrayOf(android.Manifest.permission.CAMERA),701) }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode,permissions,grantResults)
        if (requestCode == 701) {
            // Restart requires a fresh user action, so a late permission response
            // cannot restart a scan after the page has been left.
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            sink?.success(mapOf("type" to "stopped", "message" to if (granted) "Camera allowed. Tap Scan Now to begin." else "Camera permission denied. Enable it in Android Settings, then retry."))
        }
    }
    override fun onPause() { panel?.stop(); sink?.success(mapOf("type" to "stopped", "message" to "Scan paused. Tap Scan Now to restart.")); super.onPause() }
    override fun onConfigurationChanged(newConfig: Configuration) {
        panel?.stop(); sink?.success(mapOf("type" to "stopped", "message" to "Orientation changed. Tap Scan Now to restart."))
        super.onConfigurationChanged(newConfig)
    }
}

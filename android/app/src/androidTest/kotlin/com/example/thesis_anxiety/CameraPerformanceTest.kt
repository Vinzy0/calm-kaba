package com.example.thesis_anxiety

import android.content.Intent
import android.util.Log
import android.widget.FrameLayout
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Real CameraX frames and the same Developer diagnostics emitted by the app. */
class CameraPerformanceTest {
    @Test fun cameraDeveloperDiagnostics() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val activity = instrumentation.startActivitySync(Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) as MainActivity
        val packets = JSONArray()
        val done = CountDownLatch(40)
        var panel: CameraPanel? = null
        instrumentation.runOnMainSync {
            panel = CameraPanel(activity) { packet ->
                if (packet["type"] == "diagnostics" && packet["processedFps"] is Number && done.count > 0) {
                    if (done.count <= 30) packets.put(JSONObject().apply { packet.forEach { (k, v) -> put(k, JSONObject.wrap(v)) } })
                    done.countDown()
                }
                if (packet["type"] == "error") Log.e("CalmPerf", packet.toString())
            }.also {
                // Same 3:4 preview/analysis ViewPort as HomePage.
                val container = FrameLayout(activity)
                container.addView(it.view, FrameLayout.LayoutParams(-1, activity.resources.displayMetrics.widthPixels*4/3))
                activity.setContentView(container)
                it.diagnosticsEnabled = true
                it.start()
            }
        }
        try {
            assertTrue("40 diagnostics packets within 120 seconds", done.await(120, TimeUnit.SECONDS))
            val report = JSONObject().put("packets", packets).put("warmupSeconds", 10)
            File(context.filesDir, "camera_performance.json").writeText(report.toString(2))
            Log.i("CalmPerf", "Collected ${packets.length()} Developer diagnostics packets")
        } finally {
            instrumentation.runOnMainSync { panel?.dispose(); activity.finish() }
        }
    }
}

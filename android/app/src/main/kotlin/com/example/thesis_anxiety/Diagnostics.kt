package com.example.thesis_anxiety

import android.os.SystemClock

/**
 * Rolling pipeline metrics for developer mode. Recording is a few array writes per
 * frame; summaries (sorting <=120 samples per series) run once per second only while
 * diagnostics are shown, so collection stays on in every build.
 *
 * Sensor timestamps come from Camera2 SENSOR_TIMESTAMP. Their clock is REALTIME
 * (elapsedRealtimeNanos) or UNKNOWN (usually System.nanoTime). Ages are reported
 * only when the chosen clock gives plausible values; otherwise they are unavailable.
 */
class Diagnostics {
    class Series(capacity: Int = 120) {
        private val values = LongArray(capacity); private var count = 0; private var next = 0
        @Synchronized fun add(ns: Long) { values[next] = ns; next = (next+1)%values.size; if (count < values.size) count++ }
        @Synchronized fun clear() { count = 0; next = 0 }
        @Synchronized fun summary(): Map<String, Double>? {
            if (count == 0) return null
            val s = values.copyOf(count).also { it.sort() }
            fun ms(v: Long) = v/1e6
            fun p(q: Double) = ms(s[((s.size-1)*q).toInt()])
            return mapOf("mean" to s.sum()/1e6/s.size, "p50" to p(.5), "p95" to p(.95), "max" to ms(s.last()), "n" to s.size.toDouble())
        }
    }
    /** Event rate from monotonic event times within the last two seconds. */
    class Rate(private val windowNs: Long = 2_000_000_000L) {
        private val times = ArrayDeque<Long>()
        @Synchronized fun tick(now: Long = System.nanoTime()) { times.addLast(now); trim(now) }
        @Synchronized fun count(now: Long = System.nanoTime()): Int { trim(now); return times.size }
        @Synchronized fun perSecond(now: Long = System.nanoTime()): Double? {
            trim(now)
            if (times.size < 2) return null
            return (times.size-1)*1e9/(times.last()-times.first()).coerceAtLeast(1)
        }
        @Synchronized fun clear() = times.clear()
        private fun trim(now: Long) { while (times.isNotEmpty() && now-times.first() > windowNs) times.removeFirst() }
    }

    @Volatile var realtimeClock: Boolean? = null
    fun sensorNow(): Long = if (realtimeClock == false) System.nanoTime() else SystemClock.elapsedRealtimeNanos()
    /** Age of a sensor timestamp, or null when no plausible shared clock is known. */
    fun age(sensorNs: Long): Long? {
        if (realtimeClock == null || sensorNs <= 0) return null
        val age = sensorNow()-sensorNs
        return if (age in 0..10_000_000_000L) age else null
    }

    val captured = Rate(); val delivered = Rate(); val processed = Rate(); val skipped = Rate()
    /** Predictions arrive every 2 s, so their rate needs a longer window. */
    val predictions = Rate(12_000_000_000L)
    val stages = linkedMapOf(
        "captureToAnalyzer" to Series(), "convert" to Series(), "cropRotate" to Series(),
        "face" to Series(), "pose" to Series(), "hands" to Series(), "adaptWindow" to Series(),
        "features" to Series(), "classifiers" to Series(), "total" to Series(),
        "captureToResult" to Series(), "overlayAge" to Series(), "windowAge" to Series())
    val stageLabels = mapOf("captureToAnalyzer" to "capture → analyzer", "convert" to "YUV/RGBA → bitmap",
        "cropRotate" to "crop + rotate", "adaptWindow" to "adapt + window", "features" to "window features",
        "classifiers" to "7 classifiers", "total" to "analyzer total", "captureToResult" to "capture → result",
        "overlayAge" to "overlay age at draw", "windowAge" to "window end → prediction")
    private val tracked = linkedMapOf("face" to Rate(), "body" to Rate(), "left_hand" to Rate(), "right_hand" to Rate(), "knees" to Rate())
    @Volatile var input: Map<String, Any?> = emptyMap()
    @Volatile var delegates: Map<String, Any?> = emptyMap()
    @Volatile var exposure: Map<String, Any?> = emptyMap()

    fun stage(name: String, ns: Long) { stages[name]?.add(ns) }
    fun tracking(values: Map<String, Boolean>, now: Long) { for ((k, r) in tracked) if (values[k] == true) r.tick(now) }
    fun reset() {
        listOf(captured, delivered, processed, skipped, predictions).forEach { it.clear() }
        stages.values.forEach { it.clear() }; tracked.values.forEach { it.clear() }
        input = emptyMap(); delegates = emptyMap(); exposure = emptyMap(); realtimeClock = null
    }
    fun snapshot(): Map<String, Any?> {
        val now = System.nanoTime()
        val processedCount = processed.count(now)
        val cap = captured.perSecond(now); val del = delivered.perSecond(now)
        return mapOf(
            "type" to "diagnostics",
            "captureFps" to cap, "deliveredFps" to del, "processedFps" to processed.perSecond(now),
            "skippedPerSecond" to skipped.count(now)/2.0,
            "droppedFpsEstimate" to if (cap != null && del != null) (cap-del).coerceAtLeast(0.0) else null,
            "predictionHz" to predictions.perSecond(now),
            // Emulator cameras can stamp frames slightly after "now"; such ages are skipped.
            "stages" to stages.mapValues { it.value.summary() },
            "stageLabels" to stageLabels,
            "trackingRate" to tracked.mapValues { if (processedCount == 0) null else it.value.count(now).toDouble()/processedCount },
            "clock" to when (realtimeClock) { true -> "REALTIME"; false -> "MONOTONIC (assumed)"; null -> "unknown" },
            "input" to input, "delegates" to delegates, "exposure" to exposure)
    }
}

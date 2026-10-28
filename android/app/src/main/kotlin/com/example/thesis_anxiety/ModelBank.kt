package com.example.thesis_anxiety

import org.json.JSONObject
import java.io.Closeable
import java.security.MessageDigest

/**
 * Seven independent classifiers from one bundle directory:
 *  behavior/    822-feature full models, symptom vs everything (2026-10-27 run)
 *  behavior_v6/ the lead's 1,122-feature LightGBM models, symptom vs control
 */
class ModelBank(val folder: String = "behavior", read: (String) -> ByteArray) : Closeable {
    data class Model(val symptom: String, val threshold: Double, val handle: Long, val indices: IntArray)
    val manifest = JSONObject(String(read("$folder/manifest.json"), Charsets.UTF_8))
    val runId: String = manifest.getString("run_id")
    val mode: String = manifest.getString("mode")
    val engine: FeatureEngine
    private val models = mutableListOf<Model>()
    init {
        val version = manifest.getString("feature_version")
        require(runId == "2026-10-27_51participants_full_vs_restricted" && version == "full" && mode == "vs_everything" ||
            runId == "lead_2026-10-27_lgbm_vs_control_both" && version == "v6" && mode == "vs_control") { "Unknown model bundle $runId" }
        fun strings(key: String) = manifest.getJSONArray(key).let { a -> List(a.length()) { a.getString(it) } }
        engine = FeatureEngine(strings("bs_names"), strings("fm_names"), pooled = version == "v6")
        try {
            val list = manifest.getJSONArray("models")
            require(list.length() == 7)
            for (i in 0 until list.length()) {
                val m = list.getJSONObject(i)
                val schema = m.getJSONArray("features")
                val indices = IntArray(schema.length()) { j -> engine.names.indexOf(schema.getString(j)).also { require(it >= 0) } }
                require(indices.size == engine.names.size && indices.toSet().size == indices.size)
                val bytes = read("$folder/${m.getString("file")}")
                require(sha256(bytes) == m.getString("model_sha256")) { "Model checksum failed" }
                models.add(Model(m.getString("symptom"), m.getDouble("threshold"), NativeLgbm.load(String(bytes, Charsets.UTF_8)), indices))
            }
        } catch (e: Throwable) { close(); throw e }
    }
    fun predict(records: List<Observation>, start: Double, timing: (String, Long) -> Unit = { _, _ -> }): Map<String, Any> {
        val inside = records.filter { it.time >= start && it.time < start+4 }
        val fps = if (inside.size > 1) (inside.size-1)/(inside.last().time-inside.first().time) else 0.0
        val maxGap = inside.zipWithNext { a,b -> b.time-a.time }.maxOrNull() ?: Double.POSITIVE_INFINITY
        val coverage = LandmarkAdapter.trackKeys.associateWith { key -> if (inside.isEmpty()) 0.0 else inside.count { it.tracking[key] == true }.toDouble()/inside.size }
        val begin = System.nanoTime()
        val features = engine.extract(records,start)
        require(features.none { it.isInfinite() })
        val extracted = System.nanoTime(); timing("features",extracted-begin)
        val results = models.map { model ->
            val reason = if (maxGap > .5) "Tracking was interrupted; collect a fresh window" else trackingReason(model.symptom,coverage,fps)
            val warning = if (model.symptom in listOf("hand_tremor","knee_tremor") && fps < 20 && reason.isEmpty()) "Low FPS (${String.format(java.util.Locale.US,"%.1f",fps)}); tremor score may be unreliable" else ""
            val score = if (reason.isEmpty()) NativeLgbm.predict(model.handle,DoubleArray(model.indices.size) { features[model.indices[it]] }) else null
            mapOf("symptom" to model.symptom, "score" to score, "threshold" to model.threshold,
                "reason" to reason, "warning" to warning)
        }
        timing("classifiers",System.nanoTime()-extracted)
        return mapOf("results" to results, "fps" to fps, "coverage" to coverage, "runId" to runId, "mode" to mode,
            "featureCoverage" to features.count { it.isFinite() }.toDouble()/features.size, "start" to start, "end" to start+4)
    }
    override fun close() { models.forEach { NativeLgbm.free(it.handle) }; models.clear() }
    companion object {
        fun sha256(bytes: ByteArray) = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
    }
}

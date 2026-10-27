package com.example.thesis_anxiety

import org.json.JSONObject
import java.io.Closeable
import java.security.MessageDigest

class ModelBank(read: (String) -> ByteArray) : Closeable {
    data class Model(val symptom: String, val threshold: Double, val handle: Long, val indices: IntArray)
    val manifest = JSONObject(String(read("behavior/manifest.json"), Charsets.UTF_8))
    val engine: FeatureEngine
    private val models = mutableListOf<Model>()
    init {
        require(manifest.getString("run_id") == "2026-10-27_51participants_full_vs_restricted")
        require(manifest.getString("feature_version") == "restricted" && manifest.getString("mode") == "vs_control")
        fun strings(key: String) = manifest.getJSONArray(key).let { a -> List(a.length()) { a.getString(it) } }
        engine = FeatureEngine(strings("bs_names"), strings("fm_names"), strings("features"))
        try {
            val list = manifest.getJSONArray("models")
            require(list.length() == 7)
            val expected = mapOf("fidgeting" to 373, "hand_tremor" to 222, "knee_tremor" to 121,
                "avoidant_gaze" to 103, "facial_tension" to 158, "heavy_breathing" to 111, "fear" to 213)
            val seen = mutableSetOf<String>()
            for (i in 0 until list.length()) {
                val m = list.getJSONObject(i)
                val symptom = m.getString("symptom")
                require(seen.add(symptom) && symptom in expected) { "Unknown or duplicate model: $symptom" }
                val schema = m.getJSONArray("features")
                val indices = IntArray(schema.length()) { j -> engine.names.indexOf(schema.getString(j)).also { require(it >= 0) } }
                require(indices.size == expected[symptom] && indices.toSet().size == indices.size) { "Incorrect restricted schema: $symptom" }
                val bytes = read("behavior/${m.getString("file")}")
                require(sha256(bytes) == m.getString("model_sha256")) { "Model checksum failed" }
                models.add(Model(m.getString("symptom"), m.getDouble("threshold"), NativeLgbm.load(String(bytes, Charsets.UTF_8)), indices))
            }
        } catch (e: Throwable) { close(); throw e }
    }
    fun predict(records: List<Observation>, start: Double): Map<String, Any> {
        val inside = records.filter { it.time >= start && it.time < start+4 }
        val fps = if (inside.size > 1) (inside.size-1)/(inside.last().time-inside.first().time) else 0.0
        val maxGap = inside.zipWithNext { a,b -> b.time-a.time }.maxOrNull() ?: Double.POSITIVE_INFINITY
        val coverage = LandmarkAdapter.trackKeys.associateWith { key -> if (inside.isEmpty()) 0.0 else inside.count { it.tracking[key] == true }.toDouble()/inside.size }
        val features = engine.extract(records,start)
        require(features.none { it.isInfinite() })
        val results = models.map { model ->
            val reason = if (maxGap > .5) "Tracking was interrupted; collect a fresh window" else trackingReason(model.symptom,coverage,fps)
            val warning = if (model.symptom in listOf("hand_tremor","knee_tremor") && fps < 20 && reason.isEmpty()) "Low FPS (${String.format(java.util.Locale.US,"%.1f",fps)}); tremor score may be unreliable" else ""
            val score = if (reason.isEmpty()) NativeLgbm.predict(model.handle,DoubleArray(model.indices.size) { features[model.indices[it]] }) else null
            mapOf("symptom" to model.symptom, "score" to score, "threshold" to model.threshold,
                "modelRun" to "${manifest.getString("run_id")}/restricted/vs_control",
                "reason" to reason, "warning" to warning)
        }
        return mapOf("results" to results, "fps" to fps, "coverage" to coverage,
            "featureCoverage" to features.count { it.isFinite() }.toDouble()/features.size, "start" to start, "end" to start+4)
    }
    override fun close() { models.forEach { NativeLgbm.free(it.handle) }; models.clear() }
    companion object {
        fun sha256(bytes: ByteArray) = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
    }
}

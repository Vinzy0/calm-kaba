package com.example.thesis_anxiety

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import kotlin.math.abs

class PipelineParityTest {
    private var assets = File("src/main/assets")
    private var fixtures = File("src/test/resources/parity")
    private var evidence = File("../../.verification").apply { mkdirs() }
    fun configure(assets: File, fixtures: File, evidence: File) = apply {
        this.assets = assets; this.fixtures = fixtures; this.evidence = evidence
    }
    private fun array(a: JSONArray) = DoubleArray(a.length()) { if (a.isNull(it)) Double.NaN else a.getDouble(it) }
    private fun bank() = ModelBank { File(assets,it).readBytes() }

    @Test fun rawTaskResultsMatchPythonAdapter() {
        val cases = JSONArray(File(fixtures,"adapter.json").readText())
        val manifest = JSONObject(File(assets,"behavior/manifest.json").readText())
        fun names(key: String) = manifest.getJSONArray(key).let { a -> List(a.length()) { a.getString(it) } }
        fun points(a: JSONArray): List<Point3> = List(a.length()) { i -> val p = a.getJSONArray(i)
            Point3(p.getDouble(0),p.getDouble(1),p.getDouble(2),p.getDouble(3),p.getDouble(4)) }
        var error = 0.0
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i); val hh = c.getJSONArray("hands"); val b = c.getJSONObject("blend")
            val observation = LandmarkAdapter.adapt(0.0,points(c.getJSONArray("face")),points(c.getJSONArray("pose")),
                List(hh.length()) { points(hh.getJSONArray(it)) },b.keys().asSequence().associateWith { b.getDouble(it) },
                LandmarkAdapter.rowMajorMatrix(array(c.getJSONArray("packed_matrix")).map { it.toFloat() }.toFloatArray()),
                names("bs_names"),names("fm_names"))
            val expected = c.getJSONObject("row")
            for (key in expected.keys()) {
                val actual = observation.row[key] ?: Double.NaN
                if (expected.isNull(key)) assertTrue("${c.getString("name")}/$key missing",actual.isNaN())
                else { val delta = abs(actual-expected.getDouble(key)); error = maxOf(error,delta); assertTrue("$key: $delta",delta <= 2e-7) }
            }
            val track = c.getJSONObject("tracking")
            for (key in track.keys()) assertEquals("${c.getString("name")}/$key",track.getBoolean(key),observation.tracking[key])
        }
        File(evidence,"adapter.json").writeText(JSONObject(mapOf("cases" to cases.length(),"max_absolute_error" to error,"tolerance" to 2e-7)).toString(2))
    }

    @Test fun recordedWindowsMatchPython() {
        val cases = JSONArray(File(fixtures,"windows.json").readText())
        val manifest = JSONObject(File(assets,"behavior/manifest.json").readText())
        fun names(key: String) = manifest.getJSONArray(key).let { a -> List(a.length()) { a.getString(it) } }
        val engine = FeatureEngine(names("bs_names"),names("fm_names"),names("features"))
        var maxAbs = 0.0; var maxRelative = 0.0; var count = 0; var nanCount = 0; var maxPrediction = 0.0
        val failures = mutableListOf<String>()
        val models = manifest.getJSONArray("models")
        val liveBank = bank()
        try {
            for (i in 0 until cases.length()) {
                val c = cases.getJSONObject(i); val columns = c.getJSONArray("columns")
                val tt = array(c.getJSONArray("times")); val rows = c.getJSONArray("rows")
                val records = List(tt.size) { j ->
                    val values = array(rows.getJSONArray(j))
                    Observation(tt[j],(values.indices).associate { columns.getString(it) to values[it] },LandmarkAdapter.trackKeys.associateWith { true })
                }
                val actual = engine.extract(records,c.getDouble("start"))
                val expected = array(c.getJSONArray("features"))
                assertEquals(788,actual.size)
                assertEquals(expected.size,actual.size)
                for (j in actual.indices) {
                    if (expected[j].isNaN()) { assertTrue("NaN mask ${c.getString("name")}/${engine.names[j]}",actual[j].isNaN()); nanCount++; continue }
                    assertTrue("Unexpected NaN ${engine.names[j]}",actual[j].isFinite())
                    val delta = abs(actual[j]-expected[j]); maxAbs = maxOf(maxAbs,delta)
                    maxRelative = maxOf(maxRelative,delta/maxOf(1.0,abs(expected[j])))
                    if (delta > 2e-5+2e-6*abs(expected[j])) failures.add("${c.getString("name")}/${engine.names[j]}: ${actual[j]} vs ${expected[j]}")
                    count++
                }
                val probs = array(c.getJSONArray("probabilities"))
                val predictions = liveBank.predict(records,c.getDouble("start"))["results"] as List<*>
                for (m in 0 until models.length()) {
                    val prediction = predictions[m] as Map<*,*>
                    assertEquals(models.getJSONObject(m).getString("symptom"),prediction["symptom"])
                    assertEquals("2026-10-27_51participants_full_vs_restricted/restricted/vs_control",prediction["modelRun"])
                    val score = prediction["score"] as Double
                    val delta = abs(score-probs[m])
                    maxPrediction = maxOf(maxPrediction,delta)
                    if (delta > 1e-6) failures.add("${c.getString("name")}/prediction/$m: error=$delta")
                }
            }
        } finally { liveBank.close() }
        File(evidence,"kotlin_features.json").writeText(JSONObject(mapOf("cases" to cases.length(),"finite_features" to count,
            "missing_features" to nanCount,"max_absolute_error" to maxAbs,"max_scaled_error" to maxRelative,
            "feature_atol" to 2e-5,"feature_rtol" to 2e-6,"max_prediction_error" to maxPrediction,
            "prediction_tolerance" to 1e-6,"failures" to failures)).toString(2))
        assertTrue(failures.take(30).joinToString("\n"),failures.isEmpty())
    }
    @Test fun jniPredictionsMatchPythonWithMissingInputs() {
        val data = JSONObject(File(fixtures,"predictions.json").readText())
        val manifest = JSONObject(File(assets,"behavior/manifest.json").readText())
        val list = manifest.getJSONArray("models")
        val names = manifest.getJSONArray("features").let { a -> List(a.length()) { a.getString(it) } }
        val indices = List(list.length()) { m -> list.getJSONObject(m).getJSONArray("features").let { a ->
            IntArray(a.length()) { names.indexOf(a.getString(it)).also { i -> assertTrue(i >= 0) } }
        } }
        val handles = LongArray(list.length()) { i -> NativeLgbm.load(File(assets,"behavior/${list.getJSONObject(i).getString("file")}").readText()) }
        var error = 0.0
        try {
            val rows = data.getJSONArray("features"); val expected = data.getJSONArray("probabilities")
            for (i in 0 until rows.length()) for (m in handles.indices) {
                val shared = array(rows.getJSONArray(i))
                val selected = DoubleArray(indices[m].size) { shared[indices[m][it]] }
                error = maxOf(error,abs(NativeLgbm.predict(handles[m],selected)-expected.getJSONArray(i).getDouble(m)))
            }
            File(evidence,"jni_predictions.json").writeText(JSONObject(mapOf("cases" to rows.length(),"models" to 7,"max_absolute_error" to error,"tolerance" to 1e-12)).toString(2))
            assertTrue("JNI probability max error $error",error <= 1e-12)
        } finally { handles.forEach { NativeLgbm.free(it) } }
    }
    @Test fun restrictedSchemasExcludeOtherAnatomy() {
        val manifest = JSONObject(File(assets,"behavior/manifest.json").readText())
        assertEquals("restricted",manifest.getString("feature_version"))
        assertEquals("vs_control",manifest.getString("mode"))
        val models = manifest.getJSONArray("models")
        val expected = mapOf("fidgeting" to 373,"hand_tremor" to 222,"knee_tremor" to 121,
            "avoidant_gaze" to 103,"facial_tension" to 158,"heavy_breathing" to 111,"fear" to 213)
        for (i in 0 until models.length()) {
            val model = models.getJSONObject(i)
            val symptom = model.getString("symptom")
            val names = model.getJSONArray("features").let { a -> List(a.length()) { a.getString(it) } }
            assertEquals(expected[symptom],names.size)
            assertEquals(names.size,names.toSet().size)
            val allowed = when (symptom) {
                "hand_tremor" -> listOf("f_left_hand_","f_right_hand_")
                "knee_tremor","heavy_breathing" -> listOf("f_pose_")
                "fidgeting" -> listOf("f_left_hand_","f_right_hand_","f_pose_")
                else -> listOf("f_face_","f_bs_")
            }
            assertTrue("Unexpected anatomy in $symptom",names.all { name -> allowed.any { name.startsWith(it) } })
        }
        bank().use { assertEquals(788,it.engine.names.size) }
    }
    @Test fun windowsResetAndTrackingDoesNotBecomeZeroScore() {
        val live = LiveWindow()
        val tracking = LandmarkAdapter.trackKeys.associateWith { false }
        val snapshots = mutableListOf<Double>()
        for (i in 0..220) live.push(Observation(i/30.0,emptyMap(),tracking))?.let { snapshots.add(it.second) }
        assertEquals(listOf(1.0,3.0),snapshots)
        assertNull(live.push(Observation(12.0,emptyMap(),tracking)))
        assertEquals(0.0,live.progress(),0.0)
        assertNull(live.push(Observation(11.0,emptyMap(),tracking)))
        for (symptom in listOf("fidgeting","hand_tremor","knee_tremor","avoidant_gaze","facial_tension","heavy_breathing","fear")) {
            assertTrue(trackingReason(symptom,emptyMap(),30.0).isNotEmpty())
            assertTrue(trackingReason(symptom,LandmarkAdapter.trackKeys.associateWith { 1.0 },7.0).isNotEmpty())
        }
        bank().use { b ->
            val records = List(122) { Observation(it/30.0,emptyMap(),tracking) }
            val results = b.predict(records,0.0)["results"] as List<*>
            for (r in results) assertNull((r as Map<*,*>)["score"])
        }
    }
}

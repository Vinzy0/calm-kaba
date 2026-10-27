package com.example.thesis_anxiety

import kotlin.math.*

data class Observation(val time: Double, val row: Map<String, Double>, val tracking: Map<String, Boolean>)
data class Point3(val x: Double, val y: Double, val z: Double = 0.0,
                  val visibility: Double = 1.0, val presence: Double = 1.0)

/** Same image-XY conventions as webcam_core.adapt_landmarks. Inference is never mirrored. */
object LandmarkAdapter {
    fun rowMajorMatrix(packed: FloatArray): DoubleArray {
        require(packed.size == 16)
        return DoubleArray(16) { k -> packed[(k%4)*4+k/4].toDouble() }
    }
    val hands = listOf(0, 4, 8, 12, 20)
    val pose = listOf(0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28)
    val face = listOf(1, 13, 14, 33, 61, 105, 133, 145, 159, 263, 291, 334, 362, 374, 386, 468, 473)
    val trackKeys = listOf("face", "body", "left_hand", "right_hand", "knees", "reference")
    fun local(points: List<Point3>, a: Point3, b: Point3, origin: Point3, scale: Double): List<Point3> {
        val dx = b.x-a.x; val dy = b.y-a.y; val norm = hypot(dx, dy)
        if (!scale.isFinite() || scale < 1e-6 || norm < 1e-6) return points.map { Point3(Double.NaN, Double.NaN) }
        return points.map {
            val x = it.x-origin.x; val y = it.y-origin.y
            Point3(((x*dx/norm+y*dy/norm)/scale).toFloat().toDouble(),
                   ((-x*dy/norm+y*dx/norm)/scale).toFloat().toDouble())
        }
    }
    fun adapt(time: Double, facePoints: List<Point3>, body: List<Point3>, handPoints: List<List<Point3>>,
              blendshapes: Map<String, Double>, matrix: DoubleArray?, bs: List<String>, fm: List<String>): Observation {
        val row = mutableMapOf<String, Double>()
        val tracking = trackKeys.associateWith { false }.toMutableMap()
        fun store(prefix: String, points: List<Point3>, indices: List<Int>) {
            for (i in indices) { row["${prefix}_${i}_x"] = points[i].x; row["${prefix}_${i}_y"] = points[i].y }
        }
        fun mid(a: Point3, b: Point3) = Point3((a.x+b.x)/2, (a.y+b.y)/2, (a.z+b.z)/2)
        fun visible(p: Point3) = p.x in 0.0..1.0 && p.y in 0.0..1.0 && p.visibility >= .5 && p.presence >= .5
        if (facePoints.size >= 478) {
            val p = facePoints
            val normalized = local(p, p[133], p[362], mid(p[133], p[362]), hypot(p[33].x-p[263].x, p[33].y-p[263].y))
            store("face", normalized, face)
            tracking["face"] = face.all { normalized[it].x.isFinite() && normalized[it].y.isFinite() }
            for (name in bs) row[name] = blendshapes[name.removePrefix("bs_")] ?: Double.NaN
            if (matrix?.size == 16) for (name in fm) {
                val parts = name.split('_')
                row[name] = matrix[parts[2].toInt()*4+parts[3].toInt()]
            }
        }
        if (body.size >= 33) {
            val origin = mid(body[23], body[24]); val a = body[11]; val b = body[12]
            val scale = hypot(b.x-a.x, b.y-a.y)
            val normalized = local(body, a, b, origin, scale)
            store("pose", normalized, pose)
            val reference = pose.all { normalized[it].x.isFinite() && normalized[it].y.isFinite() }
            tracking["reference"] = reference
            tracking["body"] = reference && visible(a) && visible(b)
            tracking["knees"] = reference && visible(body[25]) && visible(body[26])
            val hh = handPoints.take(2).filter { it.size >= 21 }
            if (reference && hh.isNotEmpty()) {
                fun cost(hand: Int, slot: Int) = hypot(hh[hand][0].x-body[15+slot].x, hh[hand][0].y-body[15+slot].y)
                val first = if (hh.size == 1) { if (cost(0,0) <= cost(0,1)) 0 else 1 }
                            else if (cost(0,0)+cost(1,1) <= cost(0,1)+cost(1,0)) 0 else 1
                for (i in hh.indices) {
                    val side = if ((first+i)%2 == 0) "left_hand" else "right_hand"
                    store(side, local(hh[i], a, b, origin, scale), hands)
                    tracking[side] = true
                }
            }
        }
        row["face_detected"] = if (facePoints.isNotEmpty()) 1.0 else 0.0
        row["pose_detected"] = if (body.isNotEmpty()) 1.0 else 0.0
        for (side in listOf("left_hand", "right_hand")) row["${side}_detected"] = if (tracking[side] == true) 1.0 else 0.0
        return Observation(time, row, tracking)
    }
}

class FeatureEngine(val bs: List<String>, val fm: List<String>, requestedFeatures: List<String>? = null) {
    companion object {
        val flags = listOf("face_detected", "pose_detected", "left_hand_detected", "right_hand_detected")
        val stats = listOf("mean", "std", "range", "vel_mean", "vel_p95", "log_power", "dom_freq", "band_breath", "band_move", "band_tremor")
    }
    fun signals(c: Map<String, Double>): LinkedHashMap<String, Double> {
        fun v(n: String) = c[n] ?: Double.NaN
        fun dist(prefix: String, a: Int, b: Int) = hypot(v("${prefix}_${a}_x")-v("${prefix}_${b}_x"), v("${prefix}_${a}_y")-v("${prefix}_${b}_y"))
        fun proj(p: Int, a: Int, b: Int): Double {
            val dx = v("face_${b}_x")-v("face_${a}_x"); val dy = v("face_${b}_y")-v("face_${a}_y")
            return ((v("face_${p}_x")-v("face_${a}_x"))*dx+(v("face_${p}_y")-v("face_${a}_y"))*dy)/(dx*dx+dy*dy)
        }
        val s = linkedMapOf<String, Double>()
        for (side in listOf("left_hand", "right_hand")) {
            for (p in LandmarkAdapter.hands) for (a in listOf("x", "y")) s["${side}_${p}_$a"] = v("${side}_${p}_$a")
            s["${side}_openness"] = dist(side, 0, 12)
        }
        for (p in LandmarkAdapter.pose) for (a in listOf("x", "y")) s["pose_${p}_$a"] = v("pose_${p}_$a")
        val shoulderY = (v("pose_11_y")+v("pose_12_y"))/2
        s["pose_shoulder_mid_y"] = shoulderY
        s["pose_shoulder_width"] = dist("pose", 11, 12)
        s["pose_torso_len"] = (v("pose_23_y")+v("pose_24_y"))/2-shoulderY
        val iod = dist("face", 33, 263)
        s["face_nose_x"] = v("face_1_x")/iod; s["face_nose_y"] = v("face_1_y")/iod
        s["face_gaze_h_468"] = proj(468,33,133); s["face_gaze_h_473"] = proj(473,362,263)
        s["face_gaze_v_468"] = proj(468,159,145); s["face_gaze_v_473"] = proj(473,386,374)
        s["face_head_yaw"] = (v("face_1_x")-(v("face_33_x")+v("face_263_x"))/2)/iod
        s["face_head_pitch"] = (v("face_1_y")-(v("face_33_y")+v("face_263_y"))/2)/iod
        s["face_mouth_open"] = dist("face",13,14)/iod; s["face_mouth_width"] = dist("face",61,291)/iod
        s["face_brow_105"] = dist("face",105,159)/iod; s["face_brow_334"] = dist("face",334,386)/iod
        for ((key, value) in s.toMap()) if (!value.isFinite()) s[key] = Double.NaN
        return s
    }
    val signalNames = signals(emptyMap()).keys.toList()
    private val availableNames = signalNames.flatMap { s -> stats.map { "f_${s}_$it" } } +
        bs.flatMap { s -> listOf("mean", "std", "max").map { "f_${s}_$it" } } +
        fm.flatMap { s -> listOf("mean", "std").map { "f_${s}_$it" } } + flags.map { "f_${it}_rate" }
    val names = requestedFeatures?.toList() ?: availableNames
    private val selected = names.toSet()
    private val outputIndices = names.map { name -> availableNames.indexOf(name).also {
        require(it >= 0) { "Unknown feature: $name" }
    } }
    private val activeSignals = signalNames.indices.filter { j -> stats.any { "f_${signalNames[j]}_$it" in selected } }
    init { require(selected.size == names.size) { "Duplicate requested features" } }

    // NumPy's contiguous float64 pairwise reduction, including the eight accumulators.
    private fun sum(a: DoubleArray, from: Int = 0, n: Int = a.size): Double {
        if (n < 8) { var r = -0.0; for (i in from until from+n) r += a[i]; return r }
        if (n <= 128) {
            val r = DoubleArray(8) { a[from+it] }; var i = 8
            while (i < n-n%8) { for (j in 0..7) r[j] += a[from+i+j]; i += 8 }
            var result = ((r[0]+r[1])+(r[2]+r[3]))+((r[4]+r[5])+(r[6]+r[7]))
            while (i < n) { result += a[from+i]; i++ }; return result
        }
        var half = n/2; half -= half%8
        return sum(a,from,half)+sum(a,from+half,n-half)
    }
    private fun percentile(sorted: DoubleArray, p: Double): Double {
        val x = (sorted.size-1)*p; val i = x.toInt(); val f = x-i
        val a = sorted[i]; val b = sorted[min(i+1,sorted.lastIndex)]
        return if (f >= .5) b-(b-a)*(1-f) else a+(b-a)*f
    }
    private val hann = DoubleArray(120) { .5-.5*cos(2*PI*it/119) }
    private val cosines = Array(60) { k -> DoubleArray(120) { cos(2*PI*(k+1)*it/120) } }
    private val sines = Array(60) { k -> DoubleArray(120) { sin(2*PI*(k+1)*it/120) } }
    private fun signalStats(g: DoubleArray): DoubleArray {
        val mean = sum(g)/g.size
        val std = sqrt(sum(DoubleArray(g.size) { (g[it]-mean).pow(2) })/g.size)
        val sorted = g.sortedArray()
        val vel = DoubleArray(g.size-1) { abs(g[it+1]-g[it])*30 }
        val x = DoubleArray(120) { (g[it]-mean)*hann[it] }
        val power = DoubleArray(60) { k ->
            var real = 0.0; var imag = 0.0
            for (i in 0..119) { real += x[i]*cosines[k][i]; imag += x[i]*sines[k][i] }
            real*real+imag*imag
        }
        val total = sum(power)
        fun band(lo: Double, hi: Double, inclusive: Boolean = false): Double {
            if (total <= 0) return Double.NaN
            return sum(power.filterIndexed { i, _ -> val f = (i+1)*.25; f >= lo && if (inclusive) f <= hi else f < hi }.toDoubleArray())/total
        }
        val dominant = if (total > 0) (power.indices.maxBy { power[it] }+1)*.25 else Double.NaN
        return doubleArrayOf(mean,std,percentile(sorted,.95)-percentile(sorted,.05),sum(vel)/vel.size,
            percentile(vel.sortedArray(),.95),log10(total+1e-12),dominant,band(.15,.8),band(.8,3.0),band(3.0,9.0,true))
    }
    fun extract(records: List<Observation>, start: Double): DoubleArray {
        require(records.first().time <= start+1e-9 && records.last().time+1e-9 >= start+4)
        val inside = records.filter { it.time >= start && it.time < start+4 }
        val ss = inside.map { signals(it.row).values.toDoubleArray() }
        val out = DoubleArray(availableNames.size) { Double.NaN }
        for (j in activeSignals) {
            val valid = inside.indices.filter { ss[it][j].isFinite() }
            if (valid.size < 2 || valid.size < .5*inside.size) continue
            var k = 0
            val grid = DoubleArray(120) { i ->
                val t = start+i/30.0
                while (k+1 < valid.size && inside[valid[k+1]].time <= t) k++
                val a = valid[k]; val b = valid[min(k+1,valid.lastIndex)]
                if (t <= inside[a].time || a == b) ss[a][j]
                else ss[a][j]+(ss[b][j]-ss[a][j])/(inside[b].time-inside[a].time)*(t-inside[a].time)
            }
            signalStats(grid).copyInto(out,j*stats.size)
        }
        // Extras use C-contiguous float32 axis-0 nan reductions, as in Python.
        var offset = signalNames.size*stats.size
        fun extra(name: String, withMax: Boolean) {
            val n = if (withMax) 3 else 2
            val first = offset; offset += n
            if (listOf("mean", "std", "max").take(n).none { "f_${name}_$it" in selected }) return
            val a = inside.map { (it.row[name] ?: Double.NaN).toFloat() }.filter { !it.isNaN() }
            if (a.isEmpty()) return
            var total = 0f; for (v in a) total += v
            val mean = total/a.size
            var variance = 0f; for (v in a) { val diff = v-mean; variance += diff*diff }
            out[first] = mean.toDouble(); out[first+1] = sqrt(variance/a.size).toDouble()
            if (withMax) out[first+2] = a.max().toDouble()
        }
        for (name in bs) extra(name,true)
        for (name in fm) extra(name,false)
        for (name in flags) {
            val first = offset++
            if ("f_${name}_rate" !in selected) continue
            val a = inside.map { (it.row[name] ?: Double.NaN).toFloat() }.filter { !it.isNaN() }
            var total = 0f; for (v in a) total += v
            out[first] = if (a.isEmpty()) Double.NaN else (total/a.size).toDouble()
        }
        require(offset == availableNames.size)
        return DoubleArray(outputIndices.size) { out[outputIndices[it]].toFloat().toDouble() }
    }
}

/** Timestamp-based windows; reset after a >500ms processing interruption. */
class LiveWindow {
    private val records = ArrayDeque<Observation>()
    private var began: Double? = null
    private var start: Double? = null
    private var last: Double? = null
    fun reset() { records.clear(); began = null; start = null; last = null }
    fun push(observation: Observation): Pair<List<Observation>, Double>? {
        val t = observation.time
        if (last != null && t <= last!!) return null
        if (last != null && t-last!! > .5) reset()
        last = t
        if (began == null) began = t
        if (t-began!! < 1) return null
        if (start == null) start = t
        records.add(observation)
        if (t+1e-9 < start!!+4) return null
        val result = records.toList() to start!!
        start = start!!+2
        while (records.size > 1 && records.elementAt(1).time <= start!!) records.removeFirst()
        return result
    }
    fun progress(): Double = if (start == null || last == null) 0.0 else ((last!!-start!!)/4).coerceIn(0.0,1.0)
}

fun trackingReason(symptom: String, coverage: Map<String, Double>, fps: Double): String {
    fun enough(key: String) = (coverage[key] ?: 0.0) >= .5
    if (fps < 8) return "Too few processed frames. Improve lighting or use a faster phone."
    if (symptom in listOf("avoidant_gaze", "facial_tension", "fear") && !enough("face")) return "Keep your face in view"
    if (symptom in listOf("fidgeting", "hand_tremor", "knee_tremor", "heavy_breathing") && (!enough("body") || !enough("reference"))) return "Keep your shoulders and body in view"
    if (symptom == "hand_tremor" && !enough("left_hand") && !enough("right_hand")) return "Bring a hand into view"
    if (symptom == "knee_tremor" && !enough("knees")) return "Move back until both knees are visible"
    return ""
}

package com.example.thesis_anxiety

import kotlin.math.*

/**
 * The lead's all-landmark movement summaries (train/27-10-26 train/common.py,
 * pooled_window and channel_stats): 30 landmark groups x {mean,max} across channels x
 * {std, vel_mean, band_breath, band_move, band_tremor} = 300 features.
 *
 * Observation.coords holds every normalized landmark in common.PART_COLS order:
 * face 478 x/y, pose 33 x/y, left hand 21 x/y, right hand 21 x/y (1,106 channels, float32,
 * NaN when missing). Observation.visibility holds the 33 pose visibilities.
 */
object AllLandmarkFeatures {
    const val CHANNELS = 1106
    private const val T = 120
    private const val FS = 30.0
    private const val VIS_MIN = 0.3
    /** Part name, first channel, channel count. */
    private val parts = listOf(Triple("face", 0, 956), Triple("pose", 956, 66), Triple("lh", 1022, 42), Triple("rh", 1064, 42))
    private val partIndex = parts.indices.associateBy { parts[it].first }
    private val stats = listOf("std", "vel_mean", "band_breath", "band_move", "band_tremor")
    private fun ch(ids: Iterable<Int>) = ids.flatMap { listOf(2*it, 2*it+1) }.toIntArray()
    private val browL = listOf(46, 53, 52, 65, 55, 70, 63, 105, 66, 107)
    private val browR = listOf(276, 283, 282, 295, 285, 300, 293, 334, 296, 336)
    private val eyeL = listOf(33, 246, 161, 160, 159, 158, 157, 173, 133, 155, 154, 153, 145, 144, 163, 7)
    private val eyeR = listOf(362, 398, 384, 385, 386, 387, 388, 466, 263, 249, 390, 373, 374, 380, 381, 382)
    private val lips = listOf(0, 13, 14, 17, 37, 39, 40, 61, 78, 80, 81, 82, 84, 87, 88, 91, 95, 146, 178, 181, 185, 191, 267, 269,
        270, 291, 308, 310, 311, 312, 314, 317, 318, 321, 324, 375, 402, 405, 409, 415)
    private val oval = listOf(10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377, 152, 148,
        176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109)
    val groups: List<Triple<String, String, IntArray>> = listOf(
        Triple("face_all", "face", ch(0 until 478)), Triple("face_brow_l", "face", ch(browL)), Triple("face_brow_r", "face", ch(browR)),
        Triple("face_eye_l", "face", ch(eyeL)), Triple("face_eye_r", "face", ch(eyeR)), Triple("face_iris", "face", ch(468 until 478)),
        Triple("face_lips", "face", ch(lips)), Triple("face_nose", "face", ch(listOf(1, 2, 4, 5, 6, 19, 94, 98, 168, 195, 197, 326, 327))),
        Triple("face_oval", "face", ch(oval)), Triple("pose_all", "pose", ch(0 until 33)), Triple("pose_head", "pose", ch(0 until 11)),
        Triple("pose_arm_l", "pose", ch(listOf(11, 13, 15, 17, 19, 21))), Triple("pose_arm_r", "pose", ch(listOf(12, 14, 16, 18, 20, 22))),
        Triple("pose_torso", "pose", ch(listOf(11, 12, 23, 24))), Triple("pose_leg_l", "pose", ch(listOf(23, 25, 27, 29, 31))),
        Triple("pose_leg_r", "pose", ch(listOf(24, 26, 28, 30, 32)))) +
        listOf("lh", "rh").flatMap { s -> listOf(Triple("${s}_all", s, ch(0 until 21)), Triple("${s}_thumb", s, ch(1..4)),
            Triple("${s}_index", s, ch(5..8)), Triple("${s}_middle", s, ch(9..12)), Triple("${s}_ring", s, ch(13..16)),
            Triple("${s}_pinky", s, ch(17..20)), Triple("${s}_palm", s, ch(listOf(0, 5, 9, 13, 17)))) }
    val names = groups.flatMap { g -> listOf("mean", "max").flatMap { agg -> stats.map { "p_${g.first}_${agg}_$it" } } }

    /** Column names in coords order, for converting dataset rows (tests and tools). */
    val columns: List<String> = (0 until 478).flatMap { listOf("face_${it}_x", "face_${it}_y") } +
        (0 until 33).flatMap { listOf("pose_${it}_x", "pose_${it}_y") } +
        listOf("left_hand", "right_hand").flatMap { s -> (0 until 21).flatMap { listOf("${s}_${it}_x", "${s}_${it}_y") } }
    fun fromRow(row: Map<String, Double>): Pair<FloatArray, FloatArray> =
        FloatArray(CHANNELS) { (row[columns[it]] ?: Double.NaN).toFloat() } to
        FloatArray(33) { (row["pose_${it}_visibility"] ?: Double.NaN).toFloat() }

    private val hann = DoubleArray(T) { .5-.5*cos(2*PI*it/(T-1)) }
    private val cosines = Array(60) { k -> DoubleArray(T) { cos(2*PI*(k+1)*it/T) } }
    private val sines = Array(60) { k -> DoubleArray(T) { sin(2*PI*(k+1)*it/T) } }

    /** common.interp_part: linear, endpoint-clamped; null when the part's first channel is too sparse. */
    private fun interpolate(inside: List<Observation>, start: Double, first: Int, count: Int): Array<DoubleArray>? {
        val ok = inside.indices.filter { inside[it].coords?.get(first)?.isNaN() == false }
        if (inside.size < 2 || ok.size < maxOf(2.0, .5*inside.size)) return null
        val tv = DoubleArray(ok.size) { inside[ok[it]].time }
        return Array(count) { c ->
            val values = DoubleArray(ok.size) { inside[ok[it]].coords!![first+c].toDouble() }
            DoubleArray(T) { i ->
                val q = start+i/FS
                var idx = 0; var lo = 0; var hi = tv.size
                while (lo < hi) { val m = (lo+hi) ushr 1; if (tv[m] < q) lo = m+1 else hi = m }; idx = lo
                val right = idx.coerceIn(0, tv.lastIndex); val left = (idx-1).coerceIn(0, tv.lastIndex)
                val dt = tv[right]-tv[left]
                val w = (if (dt > 0) (q-tv[left])/dt else 0.0).coerceIn(0.0, 1.0)
                values[left]*(1-w)+values[right]*w
            }
        }
    }
    /** common.channel_stats for one channel, or null when any sample is missing. */
    private fun channel(x: DoubleArray): DoubleArray? {
        if (x.any { !it.isFinite() }) return null
        val mean = x.sum()/T
        var variance = 0.0; for (v in x) variance += (v-mean)*(v-mean)
        var vel = 0.0; for (i in 1 until T) vel += abs(x[i]-x[i-1])
        val y = DoubleArray(T) { (x[it]-mean)*hann[it] }
        var total = 0.0; var breath = 0.0; var move = 0.0; var tremor = 0.0
        for (k in 0 until 60) {
            var re = 0.0; var im = 0.0
            for (i in 0 until T) { re += y[i]*cosines[k][i]; im -= y[i]*sines[k][i] }
            val p = re*re+im*im; val f = (k+1)*.25
            total += p
            if (f >= .15 && f < .8) breath += p else if (f >= .8 && f < 3.0) move += p else if (f >= 3.0 && f <= 9.0) tremor += p
        }
        fun frac(v: Double) = if (total > 0) v/total else Double.NaN
        return doubleArrayOf(sqrt(variance/T), vel/(T-1)*FS, frac(breath), frac(move), frac(tremor))
    }
    fun extract(inside: List<Observation>, start: Double): DoubleArray {
        val stats = arrayOfNulls<Array<DoubleArray?>>(parts.size)
        for ((p, part) in parts.withIndex()) {
            val w = interpolate(inside, start, part.second, part.third)
            if (w != null && part.first == "pose") {
                // Pose channels whose window-mean visibility is below 0.3 (or unknown) become missing.
                for (j in 0 until 33) {
                    var sum = 0f; var n = 0
                    for (o in inside) { val v = o.visibility?.get(j) ?: Float.NaN; if (!v.isNaN()) { sum += v; n++ } }
                    if (n == 0 || sum/n < VIS_MIN) { w[2*j].fill(Double.NaN); w[2*j+1].fill(Double.NaN) }
                }
            }
            stats[p] = if (w == null) arrayOfNulls(part.third) else Array(part.third) { channel(w[it]) }
        }
        val out = DoubleArray(names.size); var k = 0
        for ((_, part, idx) in groups) {
            val s = stats[partIndex[part]!!]!!
            for (agg in 0..1) for (st in 0 until 5) {
                var acc = if (agg == 0) 0.0 else Double.NEGATIVE_INFINITY; var n = 0
                for (c in idx) { val v = s[c]?.get(st) ?: continue; if (v.isNaN()) continue; n++; acc = if (agg == 0) acc+v else max(acc, v) }
                out[k++] = if (n == 0) Double.NaN else if (agg == 0) acc/n else acc
            }
        }
        return out
    }
}

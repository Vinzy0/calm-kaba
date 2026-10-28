package com.example.thesis_anxiety

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.test.platform.app.InstrumentationRegistry
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import kotlin.math.abs

/** Records why the MediaPipe rotation fast path is blocked for the current models. */
class RotationParityTest {
    @Test fun currentMediaPipeRotationChangesModelInputs() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val report = linkedMapOf<String, Any>()
        fun base(name: String) = BaseOptions.builder().setModelAssetPath("tracking/$name").build()
        fun face() = FaceLandmarker.createFromOptions(context, FaceLandmarker.FaceLandmarkerOptions.builder()
            .setBaseOptions(base("face_landmarker.task")).setRunningMode(RunningMode.VIDEO).setNumFaces(1)
            .setOutputFaceBlendshapes(true).setOutputFacialTransformationMatrixes(true).build())
        fun pose() = PoseLandmarker.createFromOptions(context, PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(base("pose_landmarker_lite.task")).setRunningMode(RunningMode.VIDEO).build())
        fun hands() = HandLandmarker.createFromOptions(context, HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(base("hand_landmarker.task")).setRunningMode(RunningMode.VIDEO).setNumHands(2).build())
        var worst = 0.0
        for (asset in listOf("portrait.jpg", "thumb_up.jpg")) for (rotation in listOf(90, 270)) {
            val upright = instrumentation.context.assets.open("parity/$asset").use { BitmapFactory.decodeStream(it) }
            val sensor = Bitmap.createBitmap(upright, 0, 0, upright.width, upright.height,
                Matrix().apply { postRotate(-rotation.toFloat()) }, true)
            val old = Bitmap.createBitmap(sensor, 0, 0, sensor.width, sensor.height,
                Matrix().apply { postRotate(rotation.toFloat()) }, true)
            val oldImage = BitmapImageBuilder(old).build()
            val sensorImage = BitmapImageBuilder(sensor).build()
            val options = ImageProcessingOptions.builder().setRotationDegrees(rotation).build()
            fun compare(name: String, expected: List<List<NormalizedLandmark>>, actual: List<List<NormalizedLandmark>>) {
                assertTrue("$asset/$rotation/$name must detect anatomy", expected.isNotEmpty())
                assertEquals("$asset/$rotation/$name detections", expected.size, actual.size)
                var rawError = 0.0; var uprightError = 0.0; var xyError = 0.0; var zError = 0.0
                for ((a, b) in expected.zip(actual)) {
                    assertEquals(a.size, b.size)
                    for ((p, q) in a.zip(b)) {
                        val x = if (rotation == 90) 1.0-q.y() else q.y().toDouble()
                        val y = if (rotation == 90) q.x().toDouble() else 1.0-q.x()
                        val z = q.z().toDouble()*sensor.width/sensor.height
                        rawError = maxOf(rawError, abs(p.x()-q.x()).toDouble(), abs(p.y()-q.y()).toDouble(), abs(p.z()-q.z()).toDouble())
                        uprightError = maxOf(uprightError, abs(p.x()-x), abs(p.y()-y), abs(p.z()-z))
                        xyError = maxOf(xyError, abs(p.x()-x), abs(p.y()-y))
                        zError = maxOf(zError, abs(p.z()-z))
                    }
                }
                report["$asset/$rotation/$name"] = mapOf("count" to expected.sumOf { it.size }, "rawMaxXYZ" to rawError, "uprightMaxXYZ" to uprightError, "uprightMaxXY" to xyError, "uprightMaxZ" to zError)
                worst = maxOf(worst, uprightError)
            }
            try {
                if (asset == "portrait.jpg") {
                    face().use { a -> face().use { b ->
                        val f = a.detectForVideo(oldImage, 0)
                        val g = b.detectForVideo(sensorImage, options, 0)
                        compare("face", f.faceLandmarks(), g.faceLandmarks())
                        report["$asset/$rotation/blendMax"] = f.faceBlendshapes().get()[0].zip(g.faceBlendshapes().get()[0]).maxOf { (p, q) -> abs(p.score()-q.score()).toDouble() }
                        report["$asset/$rotation/matrixMax"] = f.facialTransformationMatrixes().get()[0].zip(g.facialTransformationMatrixes().get()[0]).maxOf { (p, q) -> abs(p-q).toDouble() }
                        report["$asset/$rotation/matrixExpected"] = f.facialTransformationMatrixes().get()[0].toList()
                        report["$asset/$rotation/matrixActual"] = g.facialTransformationMatrixes().get()[0].toList()
                    } }
                    pose().use { a -> pose().use { b -> compare("pose", a.detectForVideo(oldImage, 0).landmarks(), b.detectForVideo(sensorImage, options, 0).landmarks()) } }
                } else {
                    hands().use { a -> hands().use { b -> compare("hands", a.detectForVideo(oldImage, 0).landmarks(), b.detectForVideo(sensorImage, options, 0).landmarks()) } }
                }
            } finally {
                oldImage.close(); sensorImage.close()
                if (old !== sensor) old.recycle()
                if (sensor !== upright) sensor.recycle()
                upright.recycle()
                File(context.filesDir, "rotation_parity.json").writeText(JSONObject().apply { report.forEach { (k, v) -> put(k, JSONObject.wrap(v)) } }.toString(2))
            }
        }
        // A future MediaPipe/model update that removes this incompatibility needs a fresh review.
        assertTrue("Revisit the blocked fast path: max upright XYZ error $worst", worst > .005)
    }
}

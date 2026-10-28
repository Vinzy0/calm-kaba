package com.example.thesis_anxiety

import android.graphics.BitmapFactory
import androidx.test.platform.app.InstrumentationRegistry
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import kotlin.math.abs

/** Run explicitly with -e class com.example.thesis_anxiety.DevicePipelineTest. */
class DevicePipelineTest {
    @Test fun androidNativeAndFeatureParity() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val testAssets = instrumentation.context.assets
        val root = File(context.cacheDir,"parity-check").apply { mkdirs() }
        fun copyFolder(path: String, target: File, test: Boolean = false) {
            val source = if (test) testAssets else context.assets
            target.mkdirs()
            for (name in source.list(path)!!) source.open("$path/$name").use { input -> File(target,name).outputStream().use { input.copyTo(it) } }
        }
        copyFolder("behavior",File(root,"assets/behavior"))
        copyFolder("parity",File(root,"fixtures"),true)
        val checks = PipelineParityTest().configure(File(root,"assets"),File(root,"fixtures"),root)
        checks.rawTaskResultsMatchDatasetExporter()
        checks.jniPredictionsMatchPythonWithMissingInputs()
        checks.recordedWindowsMatchPython()
        checks.windowsResetAndTrackingDoesNotBecomeZeroScore()
        for (name in listOf("adapter_pixel.json","jni_predictions.json","kotlin_features.json"))
            File(context.filesDir,"device_$name").writeBytes(File(root,name).readBytes())
    }

    @Test fun androidTasksPreserveRequiredOutputsOnReferenceImage() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val expected = JSONObject(instrumentation.context.assets.open("parity/portrait_reference.json").bufferedReader().use { it.readText() })
        val bitmap = instrumentation.context.assets.open("parity/portrait.jpg").use { BitmapFactory.decodeStream(it) }
        val image = BitmapImageBuilder(bitmap).build()
        fun base(name: String) = BaseOptions.builder().setModelAssetPath("tracking/$name").build()
        fun points(raw: List<NormalizedLandmark>) = raw.map { Point3(it.x().toDouble(),it.y().toDouble(),it.z().toDouble(),it.visibility().orElse(1f).toDouble(),it.presence().orElse(1f).toDouble()) }
        val bank = ModelBank { path -> context.assets.open(path).use { it.readBytes() } }
        val face = FaceLandmarker.createFromOptions(context,FaceLandmarker.FaceLandmarkerOptions.builder()
            .setBaseOptions(base("face_landmarker.task")).setRunningMode(RunningMode.VIDEO).setNumFaces(1)
            .setOutputFaceBlendshapes(true).setOutputFacialTransformationMatrixes(true).build())
        val pose = PoseLandmarker.createFromOptions(context,PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(base("pose_landmarker_lite.task")).setRunningMode(RunningMode.VIDEO).build())
        val hands = HandLandmarker.createFromOptions(context,HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(base("hand_landmarker.task")).setRunningMode(RunningMode.VIDEO).setNumHands(2).build())
        try {
            val f = face.detectForVideo(image,0); val p = pose.detectForVideo(image,0); val h = hands.detectForVideo(image,0)
            assertEquals(478,f.faceLandmarks().first().size)
            assertEquals(33,p.landmarks().first().size)
            assertEquals(52,f.faceBlendshapes().get().first().size)
            assertEquals(16,f.facialTransformationMatrixes().get().first().size)
            val observed = LandmarkAdapter.adapt(0.0,points(f.faceLandmarks().first()),p.landmarks().firstOrNull()?.let { points(it) } ?: emptyList(),
                h.landmarks().map { points(it) },f.faceBlendshapes().get().first().associate { it.categoryName().trimStart('_') to it.score().toDouble() },
                LandmarkAdapter.rowMajorMatrix(f.facialTransformationMatrixes().get().first()),bank.engine.bs,bank.engine.fm,
                bitmap.width,bitmap.height)
            var faceError = 0.0; var blendError = 0.0; var matrixError = 0.0
            val reference = expected.getJSONObject("row")
            // Landmark coordinates follow the dataset exporter (pixel space); other values the adapter row.
            val pixel = expected.getJSONObject("pixel_row")
            for (key in reference.keys()) {
                if (reference.isNull(key)) continue
                if (key.startsWith("face_") && !key.startsWith("face_matrix") && observed.row.containsKey(key)) {
                    faceError = maxOf(faceError,abs(observed.row[key]!!-pixel.getDouble(key))); continue
                }
                val actual = observed.row[key] ?: Double.NaN
                if (key.startsWith("face_matrix")) matrixError = maxOf(matrixError,abs(actual-reference.getDouble(key)))
                else if (key.startsWith("face_")) faceError = maxOf(faceError,abs(actual-reference.getDouble(key)))
                else if (key.startsWith("bs_")) blendError = maxOf(blendError,abs(actual-reference.getDouble(key)))
            }
            val report = JSONObject(mapOf("face_landmarks" to 478,"blendshapes" to 52,"matrix_entries" to 16,
                "max_face_adapter_difference" to faceError,"max_blendshape_difference" to blendError,"max_matrix_difference" to matrixError,
                "python_mediapipe" to expected.getString("mediapipe_version"),"android_mediapipe" to "0.10.33"))
            File(context.filesDir,"device_landmarks.json").writeText(report.toString(2))
            // Different MediaPipe runtimes may differ numerically. A transposed
            // matrix produces errors many orders larger than these bounds.
            assertTrue(report.toString(),faceError <= .005 && blendError <= .02 && matrixError <= .1)
            val handBitmap = instrumentation.context.assets.open("parity/thumb_up.jpg").use { BitmapFactory.decodeStream(it) }
            val handImage = BitmapImageBuilder(handBitmap).build()
            try {
                val detected = hands.detectForVideo(handImage,1)
                assertEquals(1,detected.landmarks().size)
                assertEquals(21,detected.landmarks().first().size)
                val referenceHand = JSONObject(instrumentation.context.assets.open("parity/hand_reference.json").bufferedReader().use { it.readText() })
                    .getJSONArray("landmarks").getJSONArray(0)
                var error = 0.0
                for ((i,point) in detected.landmarks().first().withIndex()) {
                    val xyz = doubleArrayOf(point.x().toDouble(),point.y().toDouble(),point.z().toDouble())
                    for (axis in 0..2) error = maxOf(error,abs(xyz[axis]-referenceHand.getJSONArray(i).getDouble(axis)))
                }
                File(context.filesDir,"device_hands.json").writeText(JSONObject(mapOf("hands" to 1,"landmarks" to 21,"max_xyz_difference" to error,"tolerance" to .005)).toString(2))
                assertTrue("Hand XYZ difference $error",error <= .005)
            } finally { handImage.close(); handBitmap.recycle() }
        } finally { face.close(); pose.close(); hands.close(); bank.close(); image.close(); bitmap.recycle() }
    }
}

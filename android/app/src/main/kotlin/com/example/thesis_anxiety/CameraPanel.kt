package com.example.thesis_anxiety

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.*
import android.os.Handler
import android.os.Looper
import android.util.Rational
import android.util.Log
import android.util.Size
import android.view.View
import android.widget.FrameLayout
import androidx.camera.core.*
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import io.flutter.plugin.platform.PlatformView
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/** CameraX owns a latest-frame buffer. One worker owns all task/model/window state. */
class CameraPanel(private val activity: MainActivity, private val emit: (Map<String, Any?>) -> Unit) : PlatformView {
    private val root = FrameLayout(activity)
    private val preview = PreviewView(activity).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FIT_CENTER
    }
    private val overlay = LandmarkOverlay(activity)
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val generation = AtomicInteger()
    private var provider: ProcessCameraProvider? = null
    private var analysis: ImageAnalysis? = null
    private var bank: ModelBank? = null
    private var face: FaceLandmarker? = null
    private var pose: PoseLandmarker? = null
    private var hands: HandLandmarker? = null
    private val window = LiveWindow()
    private var lastMs = -1L
    @Volatile private var disposed = false
    @Volatile private var running = false
    init { root.addView(preview,FrameLayout.LayoutParams(-1,-1)); root.addView(overlay,FrameLayout.LayoutParams(-1,-1)) }
    override fun getView(): View = root
    private fun event(id: Int, packet: Map<String, Any?>) { main.post { if (!disposed && generation.get() == id) emit(packet) } }
    fun start() {
        if (disposed || running) return
        if (ContextCompat.checkSelfPermission(activity,Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            activity.requestCameraPermission(); return
        }
        running = true
        val id = generation.incrementAndGet()
        event(id,mapOf("type" to "status", "message" to "Starting camera and landmark tracking"))
        worker.execute {
            try {
                if (generation.get() != id) return@execute
                bank = ModelBank { path -> activity.assets.open(path).use { it.readBytes() } }
                val sources = JSONObject(activity.assets.open("behavior/tracking_sources.json").bufferedReader().use { it.readText() })
                for (name in listOf("face_landmarker.task","pose_landmarker_lite.task","hand_landmarker.task")) {
                    val bytes = activity.assets.open("tracking/$name").use { it.readBytes() }
                    require(ModelBank.sha256(bytes) == sources.getJSONObject(name).getString("sha256")) { "Tracking asset checksum failed: $name" }
                }
                fun base(name: String) = BaseOptions.builder().setModelAssetPath("tracking/$name").build()
                face = FaceLandmarker.createFromOptions(activity,FaceLandmarker.FaceLandmarkerOptions.builder()
                    .setBaseOptions(base("face_landmarker.task")).setRunningMode(RunningMode.VIDEO).setNumFaces(1)
                    .setOutputFaceBlendshapes(true).setOutputFacialTransformationMatrixes(true).build())
                pose = PoseLandmarker.createFromOptions(activity,PoseLandmarker.PoseLandmarkerOptions.builder()
                    .setBaseOptions(base("pose_landmarker_lite.task")).setRunningMode(RunningMode.VIDEO).setNumPoses(1).build())
                hands = HandLandmarker.createFromOptions(activity,HandLandmarker.HandLandmarkerOptions.builder()
                    .setBaseOptions(base("hand_landmarker.task")).setRunningMode(RunningMode.VIDEO).setNumHands(2).build())
                window.reset(); lastMs = -1
                main.post { if (!disposed && generation.get() == id) bindCamera(id) }
            } catch (e: Throwable) { fail(id,e) }
        }
    }
    private fun fail(id: Int, error: Throwable) {
        Log.e("CalmCamera", "Camera detection failed", error)
        val cause = generateSequence(error) { it.cause }.last()
        main.post {
            if (!disposed && generation.get() == id) {
                stop()
                emit(mapOf("type" to "error", "message" to "Camera detection unavailable: ${cause.message ?: cause.javaClass.simpleName}. Stop and try again."))
            }
        }
    }
    private fun bindCamera(id: Int) {
        if (disposed || generation.get() != id) return
        if (preview.width == 0 || preview.height == 0) { preview.post { bindCamera(id) }; return }
        val future = ProcessCameraProvider.getInstance(activity)
        future.addListener({
            if (disposed || generation.get() != id) return@addListener
            try {
                val camera = future.get(); provider = camera
                val selector = if (camera.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA
                val mirrored = selector == CameraSelector.DEFAULT_FRONT_CAMERA
                val rotation = preview.display?.rotation ?: 0
                val resolution = ResolutionSelector.Builder().setResolutionStrategy(ResolutionStrategy(Size(640,480),ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER)).build()
                val usePreview = Preview.Builder().setTargetRotation(rotation).setResolutionSelector(resolution).build()
                usePreview.setSurfaceProvider(preview.surfaceProvider)
                val useAnalysis = ImageAnalysis.Builder().setTargetRotation(rotation).setResolutionSelector(resolution)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                analysis = useAnalysis
                useAnalysis.setAnalyzer(worker) { image ->
                    if (generation.get() != id || disposed) { image.close(); return@setAnalyzer }
                    try { process(image,id,mirrored) } catch (e: Throwable) { fail(id,e) } finally { image.close() }
                }
                // Shared ViewPort gives analysis the exact crop shown in the preview.
                val group = UseCaseGroup.Builder().addUseCase(usePreview).addUseCase(useAnalysis)
                    .setViewPort(ViewPort.Builder(Rational(preview.width.coerceAtLeast(1),preview.height.coerceAtLeast(1)),rotation)
                        .setScaleType(ViewPort.FILL_CENTER).build()).build()
                camera.unbindAll(); camera.bindToLifecycle(activity,selector,group)
                event(id,mapOf("type" to "status", "message" to "Settle for one second, then hold position for four seconds"))
            } catch (e: Throwable) { fail(id,e) }
        },ContextCompat.getMainExecutor(activity))
    }
    private fun points(raw: List<NormalizedLandmark>): List<Point3> = raw.map {
        Point3(it.x().toDouble(),it.y().toDouble(),it.z().toDouble(),it.visibility().orElse(1f).toDouble(),it.presence().orElse(1f).toDouble())
    }
    private fun process(image: ImageProxy, id: Int, mirrored: Boolean) {
        // toBitmap handles RGBA row stride; crop and rotate before all three tasks.
        // No front-camera reflection enters a MediaPipe/model input.
        val original = image.toBitmap()
        val crop = image.cropRect
        val rotated = Bitmap.createBitmap(original,crop.left,crop.top,crop.width(),crop.height(),
            Matrix().apply { postRotate(image.imageInfo.rotationDegrees.toFloat()) },true)
        val mpImage = BitmapImageBuilder(rotated).build()
        try {
            val ms = maxOf(lastMs+1,image.imageInfo.timestamp/1_000_000)
            val interrupted = lastMs >= 0 && ms-lastMs > 500
            lastMs = ms
            val f = face!!.detectForVideo(mpImage,ms)
            val p = pose!!.detectForVideo(mpImage,ms)
            val h = hands!!.detectForVideo(mpImage,ms)
            val fp = f.faceLandmarks().firstOrNull()?.let { points(it) } ?: emptyList()
            val pp = p.landmarks().firstOrNull()?.let { points(it) } ?: emptyList()
            val hh = h.landmarks().map { points(it) }
            val blend = f.faceBlendshapes().orElse(emptyList()).firstOrNull()?.associate { it.categoryName().trimStart('_') to it.score().toDouble() } ?: emptyMap()
            // Java exposes the column-major packed matrix. Python transposes that
            // storage into [row,column]; reconstruct row-major before adaptation.
            val packed = f.facialTransformationMatrixes().orElse(emptyList()).firstOrNull()
            val matrix = packed?.let { LandmarkAdapter.rowMajorMatrix(it) }
            val engine = bank!!.engine
            val observation = LandmarkAdapter.adapt(ms/1000.0,fp,pp,hh,blend,matrix,engine.bs,engine.fm)
            val snapshot = window.push(observation)
            val faceDraw = LandmarkAdapter.face.filter { it < fp.size }.map { fp[it] }
            val imageWidth = rotated.width; val imageHeight = rotated.height
            main.post { if (generation.get() == id && !disposed) overlay.update(faceDraw,pp,hh,imageWidth,imageHeight,mirrored) }
            event(id,mapOf("type" to "tracking", "tracking" to observation.tracking, "progress" to window.progress(), "interrupted" to interrupted))
            if (snapshot != null) event(id,bank!!.predict(snapshot.first,snapshot.second)+mapOf("type" to "prediction"))
        } finally {
            mpImage.close()
            if (rotated !== original) rotated.recycle()
            original.recycle()
        }
    }
    fun stop() {
        running = false; generation.incrementAndGet()
        analysis?.clearAnalyzer(); analysis = null
        provider?.unbindAll()
        overlay.update(emptyList(),emptyList(),emptyList(),1,1,false)
        if (!worker.isShutdown) worker.execute { closeModels() }
    }
    private fun closeModels() {
        face?.close(); face = null; pose?.close(); pose = null; hands?.close(); hands = null
        bank?.close(); bank = null; window.reset(); lastMs = -1
    }
    override fun dispose() {
        if (disposed) return
        disposed = true; stop(); worker.shutdown()
        activity.detachPanel(this)
    }
}

private class LandmarkOverlay(context: Context) : View(context) {
    private var face = emptyList<Point3>(); private var body = emptyList<Point3>(); private var hands = emptyList<List<Point3>>()
    private var imageWidth = 1; private var imageHeight = 1; private var mirror = false
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(170,255,204); strokeWidth = 2f }
    fun update(f: List<Point3>, p: List<Point3>, h: List<List<Point3>>, w: Int, height: Int, mirrored: Boolean) {
        face = f; body = p; hands = h; imageWidth = w; imageHeight = height; mirror = mirrored; invalidate()
    }
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val scale = minOf(width.toFloat()/imageWidth,height.toFloat()/imageHeight)
        val dx = (width-imageWidth*scale)/2; val dy = (height-imageHeight*scale)/2
        fun xy(p: Point3) = PointF(dx+(if (mirror) 1-p.x else p.x).toFloat()*imageWidth*scale,dy+p.y.toFloat()*imageHeight*scale)
        fun draw(points: List<Point3>, edges: List<Pair<Int,Int>>) {
            for ((a,b) in edges) if (a < points.size && b < points.size) {
                val x = xy(points[a]); val y = xy(points[b]); canvas.drawLine(x.x,x.y,y.x,y.y,paint)
            }
            for (p in points) if (p.x.isFinite() && p.y.isFinite() && p.visibility >= .5) {
                val q = xy(p); canvas.drawCircle(q.x,q.y,3.5f,paint)
            }
        }
        draw(face,emptyList())
        draw(body,listOf(11 to 12,11 to 13,13 to 15,12 to 14,14 to 16,11 to 23,12 to 24,23 to 24,23 to 25,25 to 27,24 to 26,26 to 28))
        val edges = listOf(0 to 1,1 to 2,2 to 3,3 to 4,0 to 5,5 to 6,6 to 7,7 to 8,5 to 9,9 to 10,10 to 11,11 to 12,9 to 13,13 to 14,14 to 15,15 to 16,13 to 17,17 to 18,18 to 19,19 to 20,0 to 17)
        hands.forEach { draw(it,edges) }
    }
}

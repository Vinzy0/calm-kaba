package com.example.thesis_anxiety

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.*
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.CaptureResult
import android.hardware.camera2.TotalCaptureResult
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.PowerManager
import android.os.SystemClock
import android.os.Looper
import android.util.Range
import android.util.Rational
import android.util.Log
import android.util.Size
import android.view.View
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.Camera2Interop
import androidx.camera.camera2.interop.ExperimentalCamera2Interop
import androidx.camera.core.*
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import io.flutter.plugin.platform.PlatformView
import org.json.JSONObject
import java.util.concurrent.Callable
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ExecutionException
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicInteger

/**
 * CameraX owns a latest-frame buffer. One worker owns model/window state; the three
 * tracking tasks run concurrently, each created, used and closed on its own thread.
 */
class CameraPanel(private val activity: MainActivity, private val emit: (Map<String, Any?>) -> Unit) : PlatformView {
    private val root = FrameLayout(activity)
    private val preview = PreviewView(activity).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FIT_CENTER
    }
    val diag = Diagnostics()
    private val overlay = LandmarkOverlay(activity) { ts -> diag.age(ts)?.let { diag.stage("overlayAge",it) } }
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val generation = AtomicInteger()
    private var provider: ProcessCameraProvider? = null
    private var analysis: ImageAnalysis? = null
    private var bank: ModelBank? = null
    private val faceThread = Executors.newSingleThreadExecutor()
    private val poseThread = Executors.newSingleThreadExecutor()
    private val handThread = Executors.newSingleThreadExecutor()
    private fun <T> on(thread: ExecutorService, block: () -> T) = thread.submit(Callable(block))
    @Volatile private var face: FaceLandmarker? = null
    @Volatile private var pose: PoseLandmarker? = null
    @Volatile private var hands: HandLandmarker? = null
    private val window = LiveWindow()
    private var lastMs = -1L
    @Volatile private var disposed = false
    @Volatile private var running = false
    /** Model bundle for the next start: "behavior" (822, vs everything) or "behavior_v6" (lead, 1,122, vs control). */
    @Volatile var modelFolder = "behavior"
    /** Keep the camera at 30 fps in dim light (shorter exposure: darker, noisier frames). */
    @Volatile var lockFps30 = true
    private var startedAt = 0L
    private var frameCount = 0
    private val rgbaBuffer = RgbaFrameBuffer()
    /** Phone state that changes speed: battery, power saving, heat. Read once per diagnostics packet. */
    private fun deviceInfo(): Map<String, Any?> {
        val power = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
        val battery = activity.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val thermal = if (Build.VERSION.SDK_INT >= 29) listOf("none","light","moderate","severe","critical","emergency","shutdown")
            .getOrNull(power.currentThermalStatus) else "n/a"
        return mapOf("phone" to "${Build.MANUFACTURER} ${Build.MODEL}", "android" to Build.VERSION.RELEASE,
            "chip" to if (Build.VERSION.SDK_INT >= 31) Build.SOC_MODEL else Build.HARDWARE,
            "app" to activity.packageManager.getPackageInfo(activity.packageName,0).versionName,
            "battery%" to battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY),
            "charging" to battery.isCharging, "batterySaver" to power.isPowerSaveMode,
            "heat" to thermal, "heatHeadroom" to if (Build.VERSION.SDK_INT >= 30) power.getThermalHeadroom(10).takeIf { it.isFinite() } else null,
            "scanSeconds" to if (startedAt > 0) (SystemClock.elapsedRealtime()-startedAt)/1000 else 0)
    }
    /** Requested MediaPipe delegate for the next start ("CPU" or "GPU"). */
    @Volatile var requestedDelegate = "CPU"
    /** "GPU" for all tasks, or a comma list of tasks that should try GPU, e.g. "hands,pose". */
    private fun wantsGpu(task: String) = requestedDelegate == "GPU" || requestedDelegate.split(',').contains(task)
    private val activeDelegate = java.util.concurrent.ConcurrentHashMap<String, String>()
    private val fallback = java.util.concurrent.ConcurrentHashMap<String, String>()
    @Volatile private var modelsLabel = ""
    private fun publishDelegates() {
        diag.delegates = mapOf("requested" to requestedDelegate, "face" to activeDelegate["face"], "pose" to activeDelegate["pose"],
            "hands" to activeDelegate["hands"], "fallback" to fallback.entries.joinToString("; ") { "${it.key}: ${it.value}" },
            "models" to modelsLabel)
    }
    @Volatile var diagnosticsEnabled = false
        set(value) { field = value; if (value && running) scheduleDiagnostics(generation.get()) }
    private fun scheduleDiagnostics(id: Int) {
        main.postDelayed({
            if (disposed || !running || !diagnosticsEnabled || generation.get() != id) return@postDelayed
            diag.device = deviceInfo()
            val packet = diag.snapshot()
            Log.i("CalmDiag", JSONObject(packet).toString())
            emit(packet)
            scheduleDiagnostics(id)
        }, 1000)
    }
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
        diag.reset(); startedAt = SystemClock.elapsedRealtime(); frameCount = 0
        activeDelegate.clear(); fallback.clear(); publishDelegates()
        if (diagnosticsEnabled) scheduleDiagnostics(id)
        event(id,mapOf("type" to "status", "message" to "Starting camera and landmark tracking"))
        worker.execute {
            try {
                if (generation.get() != id) return@execute
                bank = ModelBank(modelFolder) { path -> activity.assets.open(path).use { it.readBytes() } }
                modelsLabel = "${bank!!.runId} (${bank!!.engine.names.size} features)"; publishDelegates()
                val sources = JSONObject(activity.assets.open("behavior/tracking_sources.json").bufferedReader().use { it.readText() })
                for (name in listOf("face_landmarker.task","pose_landmarker_lite.task","hand_landmarker.task")) {
                    val bytes = activity.assets.open("tracking/$name").use { it.readBytes() }
                    require(ModelBank.sha256(bytes) == sources.getJSONObject(name).getString("sha256")) { "Tracking asset checksum failed: $name" }
                }
                val f = on(faceThread) { face = createFace(wantsGpu("face")) }
                val p = on(poseThread) { pose = createPose(wantsGpu("pose")) }
                val h = on(handThread) { hands = createHands(wantsGpu("hands")) }
                f.get(); p.get(); h.get()
                window.reset(); lastMs = -1
                main.post { if (!disposed && generation.get() == id) bindCamera(id) }
            } catch (e: Throwable) { fail(id,e) }
        }
    }
    private fun base(name: String, gpu: Boolean) = BaseOptions.builder().setModelAssetPath("tracking/$name")
        .setDelegate(if (gpu) Delegate.GPU else Delegate.CPU).build()
    /** Try GPU on the calling (task) thread; fall back to CPU and record why. */
    private fun <T> withFallback(task: String, gpu: Boolean, create: (Boolean) -> T): T {
        if (gpu) try { return create(true).also { activeDelegate[task] = "GPU"; publishDelegates() } } catch (e: Throwable) {
            Log.w("CalmCamera", "$task GPU delegate unavailable; using CPU", e)
            fallback[task] = "create: ${e.javaClass.simpleName}: ${e.message?.take(120)}"
        }
        return create(false).also { activeDelegate[task] = "CPU"; publishDelegates() }
    }
    private fun createFace(gpu: Boolean) = withFallback("face", gpu) { g -> FaceLandmarker.createFromOptions(activity,FaceLandmarker.FaceLandmarkerOptions.builder()
        .setBaseOptions(base("face_landmarker.task",g)).setRunningMode(RunningMode.VIDEO).setNumFaces(1)
        .setOutputFaceBlendshapes(true).setOutputFacialTransformationMatrixes(true).build()) }
    private fun createPose(gpu: Boolean) = withFallback("pose", gpu) { g -> PoseLandmarker.createFromOptions(activity,PoseLandmarker.PoseLandmarkerOptions.builder()
        .setBaseOptions(base("pose_landmarker_lite.task",g)).setRunningMode(RunningMode.VIDEO).setNumPoses(1).build()) }
    private fun createHands(gpu: Boolean) = withFallback("hands", gpu) { g -> HandLandmarker.createFromOptions(activity,HandLandmarker.HandLandmarkerOptions.builder()
        .setBaseOptions(base("hand_landmarker.task",g)).setRunningMode(RunningMode.VIDEO).setNumHands(2).build()) }
    /** A GPU task that fails at inference is replaced by a CPU task on the same thread. */
    private fun <T, R> runOrFallback(task: String, current: () -> T?, replace: () -> T, run: (T) -> R): R = try { run(current()!!) } catch (e: Throwable) {
        if (activeDelegate[task] != "GPU") throw e
        Log.w("CalmCamera", "$task GPU inference failed; switching to CPU", e)
        fallback[task] = "inference: ${e.javaClass.simpleName}: ${e.message?.take(120)}"
        // Closing a failed GPU graph rethrows its error; the CPU replacement must still start.
        runCatching { (current() as? AutoCloseable)?.close() }
        run(replace())
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
    @OptIn(ExperimentalCamera2Interop::class)
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
                val previewBuilder = Preview.Builder().setTargetRotation(rotation).setResolutionSelector(resolution)
                // Camera frame rate: the phone may stretch exposure in dim light (e.g. [10, 30] -> 17 fps).
                val ranges = selector.filter(camera.availableCameraInfos).firstOrNull()?.let {
                    Camera2CameraInfo.from(it).getCameraCharacteristic(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
                }?.toList() ?: emptyList()
                val locked: Range<Int>? = if (lockFps30) ranges.filter { it.upper == 30 }.maxByOrNull { it.lower } else null
                diag.camera = mapOf("fpsLockRequested" to lockFps30, "fpsRangeSet" to (locked?.toString() ?: "camera default"),
                    "fpsRangesAvailable" to ranges.joinToString(" "))
                // The session callback sees every repeating capture (preview + analysis surfaces).
                Camera2Interop.Extender(previewBuilder).setSessionCaptureCallback(object : CameraCaptureSession.CaptureCallback() {
                    private var n = 0
                    override fun onCaptureCompleted(session: CameraCaptureSession, request: CaptureRequest, result: TotalCaptureResult) {
                        diag.captured.tick()
                        if (n++ % 30 == 0) diag.exposure = mapOf(
                            "aeFpsRange" to result.get(CaptureResult.CONTROL_AE_TARGET_FPS_RANGE)?.toString(),
                            "exposureMs" to result.get(CaptureResult.SENSOR_EXPOSURE_TIME)?.let { it/1e6 },
                            "iso" to result.get(CaptureResult.SENSOR_SENSITIVITY),
                            "frameDurationMs" to result.get(CaptureResult.SENSOR_FRAME_DURATION)?.let { it/1e6 })
                    }
                })
                if (locked != null) Camera2Interop.Extender(previewBuilder).setCaptureRequestOption(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, locked)
                val usePreview = previewBuilder.build()
                usePreview.setSurfaceProvider(preview.surfaceProvider)
                val analysisBuilder = ImageAnalysis.Builder().setTargetRotation(rotation).setResolutionSelector(resolution)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                if (locked != null) Camera2Interop.Extender(analysisBuilder).setCaptureRequestOption(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, locked)
                val useAnalysis = analysisBuilder.build()
                analysis = useAnalysis
                useAnalysis.setAnalyzer(worker) { image ->
                    diag.delivered.tick()
                    if (generation.get() != id || disposed) { diag.skipped.tick(); image.close(); return@setAnalyzer }
                    try { process(image,id,mirrored) } catch (e: Throwable) { fail(id,e) } finally { image.close() }
                }
                // Shared ViewPort gives analysis the exact crop shown in the preview.
                val group = UseCaseGroup.Builder().addUseCase(usePreview).addUseCase(useAnalysis)
                    .setViewPort(ViewPort.Builder(Rational(preview.width.coerceAtLeast(1),preview.height.coerceAtLeast(1)),rotation)
                        .setScaleType(ViewPort.FILL_CENTER).build()).build()
                camera.unbindAll()
                val bound = camera.bindToLifecycle(activity,selector,group)
                diag.realtimeClock = try {
                    Camera2CameraInfo.from(bound.cameraInfo).getCameraCharacteristic(CameraCharacteristics.SENSOR_INFO_TIMESTAMP_SOURCE) ==
                        CameraCharacteristics.SENSOR_INFO_TIMESTAMP_SOURCE_REALTIME
                } catch (e: Throwable) { null }
                event(id,mapOf("type" to "status", "message" to "Settle for one second, then hold position for four seconds"))
            } catch (e: Throwable) { fail(id,e) }
        },ContextCompat.getMainExecutor(activity))
    }
    /** Average luma (0-255) from a 32x24 sample grid; dark frames track worse. */
    private fun meanBrightness(b: Bitmap): Int {
        var sum = 0L
        for (j in 0 until 32) for (i in 0 until 24) {
            val c = b.getPixel(i*b.width/24, j*b.height/32)
            sum += (299*Color.red(c)+587*Color.green(c)+114*Color.blue(c))/1000
        }
        return (sum/(32*24)).toInt()
    }
    private fun points(raw: List<NormalizedLandmark>): List<Point3> = raw.map {
        Point3(it.x().toDouble(),it.y().toDouble(),it.z().toDouble(),it.visibility().orElse(1f).toDouble(),it.presence().orElse(1f).toDouble())
    }
    private fun process(image: ImageProxy, id: Int, mirrored: Boolean) {
        val begin = System.nanoTime()
        val sensorNs = image.imageInfo.timestamp
        diag.age(sensorNs)?.let { diag.stage("captureToAnalyzer",it) }
        // Padded RGBA rows still use CameraX's conversion; crop/rotation is unchanged.
        // No front-camera reflection enters a MediaPipe/model input.
        val original = rgbaBuffer.copy(image)
        val converted = System.nanoTime(); diag.stage("convert",converted-begin)
        val crop = image.cropRect
        val rotated = Bitmap.createBitmap(original,crop.left,crop.top,crop.width(),crop.height(),
            Matrix().apply { postRotate(image.imageInfo.rotationDegrees.toFloat()) },true)
        val mpImage = if (rotated === rgbaBuffer.bitmap) rgbaBuffer.image!! else BitmapImageBuilder(rotated).build()
        val readers = ArrayList<Future<*>>(3)
        var mark = System.nanoTime(); diag.stage("cropRotate",mark-converted)
        if (frameCount++ % 15 == 0) diag.brightness = meanBrightness(rotated)
        fun lap(name: String) { val now = System.nanoTime(); diag.stage(name,now-mark); mark = now }
        if (diag.input.isEmpty()) diag.input = mapOf("analysis" to "${image.width}x${image.height}",
            "crop" to "${crop.width()}x${crop.height()}", "modelInput" to "${rotated.width}x${rotated.height}",
            "rotation" to image.imageInfo.rotationDegrees, "format" to "RGBA_8888", "camera" to if (mirrored) "front" else "back",
            "bitmapReuse" to (original === rgbaBuffer.bitmap), "rowStride" to image.planes.firstOrNull()?.rowStride)
        try {
            val ms = maxOf(lastMs+1,image.imageInfo.timestamp/1_000_000)
            val interrupted = lastMs >= 0 && ms-lastMs > 500
            lastMs = ms
            // The tasks only read the shared input image.
            fun <T> timed(name: String, block: () -> T): T { val t = System.nanoTime(); return block().also { diag.stage(name,System.nanoTime()-t) } }
            val ff = on(faceThread) { timed("face") { runOrFallback("face",{ face },{ createFace(false).also { face = it } }) { it.detectForVideo(mpImage,ms) } } }.also { readers.add(it) }
            val pf = on(poseThread) { timed("pose") { runOrFallback("pose",{ pose },{ createPose(false).also { pose = it } }) { it.detectForVideo(mpImage,ms) } } }.also { readers.add(it) }
            val hf = on(handThread) { timed("hands") { runOrFallback("hands",{ hands },{ createHands(false).also { hands = it } }) { it.detectForVideo(mpImage,ms) } } }.also { readers.add(it) }
            val f = ff.get(); val p = pf.get(); val h = hf.get(); lap("tracking")
            val fp = f.faceLandmarks().firstOrNull()?.let { points(it) } ?: emptyList()
            val pp = p.landmarks().firstOrNull()?.let { points(it) } ?: emptyList()
            val hh = h.landmarks().map { points(it) }
            val blend = f.faceBlendshapes().orElse(emptyList()).firstOrNull()?.associate { it.categoryName().trimStart('_') to it.score().toDouble() } ?: emptyMap()
            // Java exposes the column-major packed matrix. Python transposes that
            // storage into [row,column]; reconstruct row-major before adaptation.
            val packed = f.facialTransformationMatrixes().orElse(emptyList()).firstOrNull()
            val matrix = packed?.let { LandmarkAdapter.rowMajorMatrix(it) }
            val engine = bank!!.engine
            val observation = LandmarkAdapter.adapt(ms/1000.0,fp,pp,hh,blend,matrix,engine.bs,engine.fm,rotated.width,rotated.height)
            val snapshot = window.push(observation)
            lap("adaptWindow")
            val faceDraw = LandmarkAdapter.face.filter { it < fp.size }.map { fp[it] }
            val imageWidth = rotated.width; val imageHeight = rotated.height
            main.post { if (generation.get() == id && !disposed) overlay.update(faceDraw,pp,hh,imageWidth,imageHeight,mirrored,sensorNs) }
            event(id,mapOf("type" to "tracking", "tracking" to observation.tracking, "progress" to window.progress(), "interrupted" to interrupted))
            if (snapshot != null) {
                val packet = bank!!.predict(snapshot.first,snapshot.second) { name, ns -> diag.stage(name,ns) }
                diag.predictions.tick()
                // The newest frame ends the window; this age shows how stale a prediction is.
                diag.age(sensorNs)?.let { diag.stage("windowAge",it) }
                event(id,packet+mapOf("type" to "prediction"))
            }
            val end = System.nanoTime()
            diag.stage("total",end-begin); diag.processed.tick(end); diag.tracking(observation.tracking,end)
            diag.age(sensorNs)?.let { diag.stage("captureToResult",it) }
        } finally {
            // A failed tracker must still wait for the other image readers.
            awaitTrackerReaders(readers)
            // Closing MPImage recycles its bitmap; keep the reusable wrapper alive too.
            if (mpImage !== rgbaBuffer.image) mpImage.close()
            if (original !== rgbaBuffer.bitmap && original !== rotated) original.recycle()
        }
    }
    fun stop() {
        running = false; generation.incrementAndGet()
        analysis?.clearAnalyzer(); analysis = null
        provider?.unbindAll()
        overlay.update(emptyList(),emptyList(),emptyList(),1,1,false,0)
        if (!worker.isShutdown) worker.execute { closeModels() }
    }
    private fun closeModels() {
        val closing = listOf(on(faceThread) { runCatching { face?.close() }; face = null }, on(poseThread) { runCatching { pose?.close() }; pose = null },
            on(handThread) { runCatching { hands?.close() }; hands = null })
        closing.forEach { runCatching { it.get() } }
        rgbaBuffer.close()
        bank?.close(); bank = null; window.reset(); lastMs = -1
    }
    override fun dispose() {
        if (disposed) return
        disposed = true; stop()
        worker.execute { listOf(faceThread,poseThread,handThread).forEach { it.shutdown() } }
        worker.shutdown()
        activity.detachPanel(this)
    }
}

/** Owned by the single analysis worker, including resize and stop/dispose cleanup. */
internal class RgbaFrameBuffer : AutoCloseable {
    var bitmap: Bitmap? = null; private set
    var image: MPImage? = null; private set
    fun copy(frame: ImageProxy): Bitmap {
        val plane = frame.planes.firstOrNull()
        if (frame.format != PixelFormat.RGBA_8888 || plane == null || plane.pixelStride != 4 || plane.rowStride != frame.width*4)
            return frame.toBitmap()
        if (bitmap?.width != frame.width || bitmap?.height != frame.height) {
            close()
            bitmap = Bitmap.createBitmap(frame.width, frame.height, Bitmap.Config.ARGB_8888)
            image = BitmapImageBuilder(bitmap!!).build()
        }
        bitmap!!.copyPixelsFromBuffer(plane.buffer.duplicate().apply { rewind() })
        return bitmap!!
    }
    override fun close() {
        image?.close(); image = null; bitmap = null
    }
}

/** Drain every reader even after a failure or interruption, before recycling its image. */
internal fun awaitTrackerReaders(readers: List<Future<*>>) {
    var interrupted = false
    for (reader in readers) while (true) {
        try { reader.get(); break }
        catch (e: InterruptedException) { interrupted = true }
        catch (e: ExecutionException) { break }
    }
    if (interrupted) Thread.currentThread().interrupt()
}

private class LandmarkOverlay(context: Context, private val drawn: (Long) -> Unit) : View(context) {
    private var face = emptyList<Point3>(); private var body = emptyList<Point3>(); private var hands = emptyList<List<Point3>>()
    private var imageWidth = 1; private var imageHeight = 1; private var mirror = false; private var sourceNs = 0L
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(170,255,204); strokeWidth = 2f }
    fun update(f: List<Point3>, p: List<Point3>, h: List<List<Point3>>, w: Int, height: Int, mirrored: Boolean, sensorNs: Long) {
        face = f; body = p; hands = h; imageWidth = w; imageHeight = height; mirror = mirrored; sourceNs = sensorNs; invalidate()
    }
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        // Age of the source camera frame when its landmarks are first drawn.
        if (sourceNs > 0) { drawn(sourceNs); sourceNs = 0 }
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

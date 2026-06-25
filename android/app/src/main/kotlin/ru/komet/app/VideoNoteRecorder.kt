package ru.komet.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.params.StreamConfigurationMap
import android.media.MediaRecorder
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.Matrix
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.util.Size
import android.view.Surface
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

// Нативная запись видео-кружка через GL-конвейер: камера выдаёт стандартный
// кадр в SurfaceTexture (OES), шейдер кропает по центру в квадрат и рендерит
// одновременно в превью (Flutter Texture) и в MediaRecorder (480×480, H.264,
// framework MediaMuxer). Так делает официальный клиент через CameraX — выход
// проходит серверный валидатор (media3-перекод его НЕ проходит).
class VideoNoteRecorder(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
) {
    private val tag = "VideoNoteRecorder"
    private val edge = 480
    private val bitrate = 1_024_000
    private val fps = 30

    private var cameraId = ""
    private var lensFacing = CameraCharacteristics.LENS_FACING_FRONT
    private var sensorOrientation = 270
    private var camSize = Size(1280, 720)

    private var cameraDevice: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var recorder: MediaRecorder? = null
    private var outputPath: String? = null

    private var camThread: HandlerThread? = null
    private var camHandler: Handler? = null
    private var glThread: HandlerThread? = null
    private var glHandler: Handler? = null

    private var flutterEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var previewSurface: Surface? = null
    private var recorderSurface: Surface? = null

    // GL state (живёт на glThread)
    private var egl: EglCore? = null
    private var previewWindow: WindowSurface? = null
    private var recordWindow: WindowSurface? = null
    private var oesTexId = 0
    private var camTexture: SurfaceTexture? = null
    private var camInputSurface: Surface? = null
    private var program: OesProgram? = null
    private val stMatrix = FloatArray(16)

    @Volatile private var recording = false
    @Volatile private var glReady = false

    private fun manager() =
        context.getSystemService(Context.CAMERA_SERVICE) as CameraManager

    private fun selectCamera(facing: Int): Boolean {
        val mgr = manager()
        for (id in mgr.cameraIdList) {
            val ch = mgr.getCameraCharacteristics(id)
            if (ch.get(CameraCharacteristics.LENS_FACING) == facing) {
                cameraId = id
                lensFacing = facing
                sensorOrientation =
                    ch.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 270
                val map = ch.get(
                    CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP,
                )
                camSize = pickCamSize(map)
                return true
            }
        }
        return false
    }

    // Поддерживаемый камерой размер вывода (для SurfaceTexture), близкий к 720p.
    private fun pickCamSize(map: StreamConfigurationMap?): Size {
        val sizes = map?.getOutputSizes(SurfaceTexture::class.java)
            ?: return Size(1280, 720)
        var best = sizes.firstOrNull() ?: Size(1280, 720)
        var bestScore = Int.MAX_VALUE
        for (s in sizes) {
            val longSide = maxOf(s.width, s.height)
            val shortSide = minOf(s.width, s.height)
            if (shortSide < edge) continue
            val score = kotlin.math.abs(longSide - 1280) + kotlin.math.abs(shortSide - 720)
            if (score < bestScore) {
                bestScore = score
                best = s
            }
        }
        return best
    }

    fun init(facingFront: Boolean, rawResult: MethodChannel.Result) {
        val result = OnceResult(rawResult)
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("NO_PERMISSION", "camera permission required", null)
            return
        }
        try {
            val facing = if (facingFront) {
                CameraCharacteristics.LENS_FACING_FRONT
            } else {
                CameraCharacteristics.LENS_FACING_BACK
            }
            if (!selectCamera(facing) &&
                !selectCamera(CameraCharacteristics.LENS_FACING_BACK)
            ) {
                result.error("NO_CAMERA", "no camera found", null)
                return
            }
            camThread = HandlerThread("VideoNoteCam").also { it.start() }
            camHandler = Handler(camThread!!.looper)
            glThread = HandlerThread("VideoNoteGL").also { it.start() }
            glHandler = Handler(glThread!!.looper)

            val entry = textureRegistry.createSurfaceTexture()
            flutterEntry = entry
            entry.surfaceTexture().setDefaultBufferSize(edge, edge)
            previewSurface = Surface(entry.surfaceTexture())

            glHandler!!.post {
                try {
                    setupGl()
                    glReady = true
                    openCamera(result, entry.id())
                } catch (e: Exception) {
                    Log.e(tag, "GL setup failed", e)
                    result.error("GL_FAILED", e.message, null)
                }
            }
        } catch (e: Exception) {
            Log.e(tag, "init failed", e)
            result.error("INIT_FAILED", e.message, null)
        }
    }

    // === GL (на glThread) ===
    private fun setupGl() {
        val core = EglCore()
        egl = core
        previewWindow = WindowSurface(core, previewSurface!!, core.displayConfig)
            .also { it.makeCurrent() }
        program = OesProgram()
        oesTexId = program!!.createOesTexture()
        val st = SurfaceTexture(oesTexId)
        st.setDefaultBufferSize(camSize.width, camSize.height)
        st.setOnFrameAvailableListener({ onFrame() }, glHandler)
        camTexture = st
        camInputSurface = Surface(st)
        Log.i(tag, "GL setup ok cam=$camSize")
    }

    private var frameCount = 0

    private fun onFrame() {
        val st = camTexture ?: return
        val prog = program ?: return
        val w = previewWindow ?: return
        try {
            w.makeCurrent()
            st.updateTexImage()
            st.getTransformMatrix(stMatrix)
        } catch (e: Exception) {
            Log.w(tag, "onFrame update: ${e.message}")
            return
        }
        run {
            GLES20.glViewport(0, 0, edge, edge)
            prog.draw(oesTexId, stMatrix, camSize, lensFacing, true)
            w.swap()
        }
        if (frameCount == 0) {
            Log.i(
                tag,
                "first frame cam=$camSize orient=$sensorOrientation " +
                    "facing=$lensFacing st=[${stMatrix.joinToString(",") { "%.2f".format(it) }}]",
            )
        }
        frameCount++
        if (recording) {
            recordWindow?.let { w ->
                w.makeCurrent()
                GLES20.glViewport(0, 0, edge, edge)
                prog.draw(oesTexId, stMatrix, camSize, lensFacing, false)
                w.setPresentationTime(System.nanoTime())
                w.swap()
            }
        }
    }

    @Suppress("MissingPermission")
    private fun openCamera(result: MethodChannel.Result, textureId: Long) {
        manager().openCamera(
            cameraId,
            object : CameraDevice.StateCallback() {
                override fun onOpened(device: CameraDevice) {
                    Log.i(tag, "camera opened $cameraId")
                    cameraDevice = device
                    startPreviewSession(result, textureId)
                }

                override fun onDisconnected(device: CameraDevice) {
                    device.close(); cameraDevice = null
                }

                override fun onError(device: CameraDevice, error: Int) {
                    device.close(); cameraDevice = null
                    result.error("CAMERA_ERROR", "code $error", null)
                }
            },
            camHandler,
        )
    }

    private fun startPreviewSession(result: MethodChannel.Result, textureId: Long) {
        val device = cameraDevice ?: return
        val camSurface = camInputSurface ?: return
        try {
            createSession(listOf(camSurface)) { s ->
                session = s
                val req = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
                req.addTarget(camSurface)
                s.setRepeatingRequest(req.build(), null, camHandler)
                Log.i(tag, "preview session configured")
                result.success(mapOf("textureId" to textureId, "size" to edge))
            }
        } catch (e: Exception) {
            Log.e(tag, "preview session failed", e)
            result.error("PREVIEW_FAILED", e.message, null)
        }
    }

    private fun setupRecorder(path: String) {
        val rec = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION") MediaRecorder()
        }
        rec.setAudioSource(MediaRecorder.AudioSource.MIC)
        rec.setVideoSource(MediaRecorder.VideoSource.SURFACE)
        rec.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        rec.setVideoEncoder(MediaRecorder.VideoEncoder.H264)
        rec.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        rec.setVideoSize(edge, edge)
        rec.setVideoEncodingBitRate(bitrate)
        rec.setVideoFrameRate(fps)
        rec.setAudioChannels(1)
        rec.setAudioSamplingRate(48000)
        rec.setAudioEncodingBitRate(96000)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                rec.setVideoEncodingProfileLevel(
                    android.media.MediaCodecInfo.CodecProfileLevel.AVCProfileHigh,
                    android.media.MediaCodecInfo.CodecProfileLevel.AVCLevel3,
                )
            } catch (e: Exception) {
                Log.w(tag, "profile level: ${e.message}")
            }
        }
        rec.setOutputFile(path)
        rec.prepare()
        recorder = rec
        recorderSurface = rec.surface
    }

    fun start(result: MethodChannel.Result) {
        if (cameraDevice == null || !glReady) {
            result.error("NOT_READY", "camera not initialized", null); return
        }
        try {
            val path = File(context.cacheDir, "note_${System.nanoTime()}.mp4").absolutePath
            outputPath = path
            setupRecorder(path)
            val recSurface = recorderSurface!!
            glHandler!!.post {
                try {
                    recordWindow = WindowSurface(egl!!, recSurface, egl!!.recordConfig)
                    recorder?.start()
                    recording = true
                    result.success(null)
                } catch (e: Exception) {
                    Log.e(tag, "record window failed", e)
                    result.error("START_FAILED", e.message, null)
                }
            }
        } catch (e: Exception) {
            Log.e(tag, "start failed", e)
            result.error("START_FAILED", e.message, null)
        }
    }

    fun stop(result: MethodChannel.Result) {
        if (!recording) {
            result.error("NOT_RECORDING", "no active recording", null); return
        }
        recording = false
        glHandler!!.post {
            try {
                recordWindow?.release()
                recordWindow = null
            } catch (_: Exception) {}
            try {
                try {
                    recorder?.stop()
                } catch (e: Exception) {
                    Log.w(tag, "recorder.stop: ${e.message}")
                }
                recorder?.reset(); recorder?.release(); recorder = null
                recorderSurface = null
                outputPath?.let { stripVideoEditList(it) }
                result.success(outputPath)
            } catch (e: Exception) {
                Log.e(tag, "stop failed", e)
                result.error("STOP_FAILED", e.message, null)
            }
        }
    }

    // MediaRecorder добавляет на видео-трек edit list (edts/elst) из-за
    // B-кадров — серверный валидатор такие файлы отвергает (у клиента видео без
    // edit list). Переименовываем бокс edts→free (тот же размер, ничего не
    // сдвигается, парсеры пропускают free) — edit list исчезает без перекода.
    private fun stripVideoEditList(path: String) {
        try {
            val f = java.io.RandomAccessFile(path, "rw")
            val scan = minOf(f.length(), 65536L).toInt()
            val buf = ByteArray(scan)
            f.seek(0); f.readFully(buf)
            var i = 0
            while (i + 8 <= scan) {
                if (buf[i] == 0x65.toByte() && buf[i + 1] == 0x64.toByte() &&
                    buf[i + 2] == 0x74.toByte() && buf[i + 3] == 0x73.toByte()
                ) {
                    f.seek(i.toLong())
                    f.write(byteArrayOf(0x66, 0x72, 0x65, 0x65))
                    Log.i(tag, "stripped video edit list at $i")
                }
                i++
            }
            f.close()
        } catch (e: Exception) {
            Log.w(tag, "stripEditList: ${e.message}")
        }
    }

    fun dispose() {
        recording = false
        try { session?.close() } catch (_: Exception) {}
        session = null
        glHandler?.post {
            try { recordWindow?.release() } catch (_: Exception) {}
            try { recorder?.reset(); recorder?.release() } catch (_: Exception) {}
            recorder = null
            try { camTexture?.release() } catch (_: Exception) {}
            try { camInputSurface?.release() } catch (_: Exception) {}
            try { previewWindow?.release() } catch (_: Exception) {}
            try { program?.release() } catch (_: Exception) {}
            try { egl?.release() } catch (_: Exception) {}
        }
        cameraDevice?.close(); cameraDevice = null
        previewSurface?.release(); previewSurface = null
        flutterEntry?.release(); flutterEntry = null
        glThread?.quitSafely(); glThread = null; glHandler = null
        camThread?.quitSafely(); camThread = null; camHandler = null
    }

    @Suppress("DEPRECATION")
    private fun createSession(
        surfaces: List<Surface>,
        onReady: (CameraCaptureSession) -> Unit,
    ) {
        val device = cameraDevice ?: return
        device.createCaptureSession(
            surfaces,
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(s: CameraCaptureSession) = onReady(s)
                override fun onConfigureFailed(s: CameraCaptureSession) {
                    Log.e(tag, "session config failed")
                }
            },
            camHandler,
        )
    }
}

private class OnceResult(private val inner: MethodChannel.Result) : MethodChannel.Result {
    private val done = java.util.concurrent.atomic.AtomicBoolean(false)
    override fun success(result: Any?) {
        if (done.compareAndSet(false, true)) inner.success(result)
    }
    override fun error(code: String, message: String?, details: Any?) {
        if (done.compareAndSet(false, true)) inner.error(code, message, details)
    }
    override fun notImplemented() {
        if (done.compareAndSet(false, true)) inner.notImplemented()
    }
}

// ── Минимальный EGL/GL под рендер OES-текстуры в квадратные surface ──

private class EglCore {
    val display: EGLDisplay
    val displayConfig: EGLConfig // без recordable — семплируется Flutter-текстурой
    val recordConfig: EGLConfig  // с recordable — для MediaRecorder-surface
    val eglContext: EGLContext

    init {
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val ver = IntArray(2)
        EGL14.eglInitialize(display, ver, 0, ver, 1)
        // Два конфига: превью (Flutter Texture) НЕ должно иметь
        // EGL_RECORDABLE_ANDROID — иначе буферы получают video-encoder usage
        // и не семплируются как картинка (чёрное превью). А encoder-surface
        // MediaRecorder, наоборот, требует recordable.
        displayConfig = chooseConfig(false)
        recordConfig = chooseConfig(true)
        val ctxAttribs = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE)
        eglContext = EGL14.eglCreateContext(
            display, displayConfig, EGL14.EGL_NO_CONTEXT, ctxAttribs, 0,
        )
    }

    private fun chooseConfig(recordable: Boolean): EGLConfig {
        val attribs = if (recordable) {
            intArrayOf(
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                0x3142, 1, EGL14.EGL_NONE,
            )
        } else {
            intArrayOf(
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_NONE,
            )
        }
        val configs = arrayOfNulls<EGLConfig>(1)
        val num = IntArray(1)
        EGL14.eglChooseConfig(display, attribs, 0, configs, 0, 1, num, 0)
        return configs[0]!!
    }

    fun release() {
        EGL14.eglMakeCurrent(
            display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT,
        )
        EGL14.eglDestroyContext(display, eglContext)
        EGL14.eglReleaseThread()
        EGL14.eglTerminate(display)
    }
}

private class WindowSurface(
    private val core: EglCore,
    surface: Surface,
    config: EGLConfig,
) {
    private var eglSurface: EGLSurface =
        EGL14.eglCreateWindowSurface(
            core.display, config, surface, intArrayOf(EGL14.EGL_NONE), 0,
        ).also {
            if (it == EGL14.EGL_NO_SURFACE) {
                Log.w("VideoNoteRecorder", "eglCreateWindowSurface FAILED err=${EGL14.eglGetError()}")
            }
        }

    fun makeCurrent() {
        EGL14.eglMakeCurrent(core.display, eglSurface, eglSurface, core.eglContext)
    }

    fun swap() {
        EGL14.eglSwapBuffers(core.display, eglSurface)
    }

    fun setPresentationTime(ns: Long) {
        EGLExt14.setPresentationTime(core.display, eglSurface, ns)
    }

    fun release() {
        EGL14.eglDestroySurface(core.display, eglSurface)
    }
}

private object EGLExt14 {
    fun setPresentationTime(display: EGLDisplay, surface: EGLSurface, ns: Long) {
        android.opengl.EGLExt.eglPresentationTimeANDROID(display, surface, ns)
    }
}

// Рисует OES-текстуру камеры в текущий квадратный surface, кропая центральный
// квадрат и учитывая ориентацию сенсора + зеркало фронталки.
private class OesProgram {
    private val vertexShader = """
        attribute vec4 aPosition;
        attribute vec4 aTexCoord;
        uniform mat4 uTexMatrix;
        varying vec2 vTex;
        void main() {
            gl_Position = aPosition;
            vTex = (uTexMatrix * aTexCoord).xy;
        }
    """
    private val fragmentShader = """
        #extension GL_OES_EGL_image_external : require
        precision mediump float;
        varying vec2 vTex;
        uniform samplerExternalOES sTexture;
        void main() {
            gl_FragColor = vec4(texture2D(sTexture, vTex).rgb, 1.0);
        }
    """

    private val program: Int
    private val aPosition: Int
    private val aTexCoord: Int
    private val uTexMatrix: Int
    private val uTexture: Int
    private val quad: FloatBuffer
    private val tex: FloatBuffer
    private val mirrorM = FloatArray(16)
    private val cropM = FloatArray(16)
    private val stMirrorM = FloatArray(16)
    private val fullM = FloatArray(16)

    init {
        program = buildProgram(vertexShader, fragmentShader)
        aPosition = GLES20.glGetAttribLocation(program, "aPosition")
        aTexCoord = GLES20.glGetAttribLocation(program, "aTexCoord")
        uTexMatrix = GLES20.glGetUniformLocation(program, "uTexMatrix")
        uTexture = GLES20.glGetUniformLocation(program, "sTexture")
        quad = floatBuf(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f))
        tex = floatBuf(floatArrayOf(0f, 0f, 1f, 0f, 0f, 1f, 1f, 1f))
    }

    fun createOesTexture(): Int {
        val ids = IntArray(1)
        GLES20.glGenTextures(1, ids, 0)
        val id = ids[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, id)
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE,
        )
        return id
    }

    fun draw(
        texId: Int,
        st: FloatArray,
        camSize: Size,
        lensFacing: Int,
        mirror: Boolean,
    ) {
        Matrix.setIdentityM(mirrorM, 0)
        if (mirror && lensFacing == CameraCharacteristics.LENS_FACING_FRONT) {
            Matrix.translateM(mirrorM, 0, 0.5f, 0.5f, 0f)
            Matrix.scaleM(mirrorM, 0, -1f, 1f, 1f)
            Matrix.translateM(mirrorM, 0, -0.5f, -0.5f, 0f)
        }
        val w = camSize.width.toFloat()
        val h = camSize.height.toFloat()
        Matrix.setIdentityM(cropM, 0)
        Matrix.translateM(cropM, 0, 0.5f, 0.5f, 0f)
        if (w >= h) {
            Matrix.scaleM(cropM, 0, h / w, 1f, 1f)
        } else {
            Matrix.scaleM(cropM, 0, 1f, w / h, 1f)
        }
        Matrix.translateM(cropM, 0, -0.5f, -0.5f, 0f)
        Matrix.multiplyMM(stMirrorM, 0, st, 0, mirrorM, 0)
        Matrix.multiplyMM(fullM, 0, cropM, 0, stMirrorM, 0)

        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(program)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texId)
        GLES20.glUniform1i(uTexture, 0)
        GLES20.glUniformMatrix4fv(uTexMatrix, 1, false, fullM, 0)
        GLES20.glEnableVertexAttribArray(aPosition)
        GLES20.glVertexAttribPointer(aPosition, 2, GLES20.GL_FLOAT, false, 0, quad)
        GLES20.glEnableVertexAttribArray(aTexCoord)
        GLES20.glVertexAttribPointer(aTexCoord, 2, GLES20.GL_FLOAT, false, 0, tex)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(aPosition)
        GLES20.glDisableVertexAttribArray(aTexCoord)
    }

    fun release() {
        GLES20.glDeleteProgram(program)
    }

    private fun floatBuf(data: FloatArray): FloatBuffer {
        val bb = ByteBuffer.allocateDirect(data.size * 4).order(ByteOrder.nativeOrder())
        val fb = bb.asFloatBuffer()
        fb.put(data).position(0)
        return fb
    }

    private fun buildProgram(vs: String, fs: String): Int {
        val v = compile(GLES20.GL_VERTEX_SHADER, vs)
        val f = compile(GLES20.GL_FRAGMENT_SHADER, fs)
        val p = GLES20.glCreateProgram()
        GLES20.glAttachShader(p, v)
        GLES20.glAttachShader(p, f)
        GLES20.glLinkProgram(p)
        val status = IntArray(1)
        GLES20.glGetProgramiv(p, GLES20.GL_LINK_STATUS, status, 0)
        if (status[0] == 0) {
            val log = GLES20.glGetProgramInfoLog(p)
            GLES20.glDeleteProgram(p)
            throw RuntimeException("link failed: $log")
        }
        return p
    }

    private fun compile(type: Int, src: String): Int {
        val s = GLES20.glCreateShader(type)
        GLES20.glShaderSource(s, src)
        GLES20.glCompileShader(s)
        val status = IntArray(1)
        GLES20.glGetShaderiv(s, GLES20.GL_COMPILE_STATUS, status, 0)
        if (status[0] == 0) {
            val log = GLES20.glGetShaderInfoLog(s)
            GLES20.glDeleteShader(s)
            throw RuntimeException("compile failed: $log")
        }
        return s
    }
}

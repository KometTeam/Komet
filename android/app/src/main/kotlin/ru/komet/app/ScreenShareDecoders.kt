package ru.komet.app

import android.graphics.SurfaceTexture
import android.media.MediaCodec
import android.media.MediaFormat
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import android.view.Surface
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class ScreenShareDecoders(private val textures: TextureRegistry) : MethodChannel.MethodCallHandler {
    private val decoders = HashMap<Long, ScreenShareDecoder>()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> {
                val mime = if (call.argument<String>("codec") == "vp9") {
                    MediaFormat.MIMETYPE_VIDEO_VP9
                } else {
                    MediaFormat.MIMETYPE_VIDEO_VP8
                }
                val decoder = ScreenShareDecoder(textures.createSurfaceProducer(), mime)
                decoders[decoder.id] = decoder
                result.success(decoder.id)
            }
            "decode" -> {
                val decoder = decoders[idOf(call)]
                val data = call.argument<ByteArray>("data")
                if (decoder == null || data == null) {
                    result.success(null)
                } else {
                    decoder.decode(data, call.argument<Boolean>("key") == true) { result.success(it) }
                }
            }
            "release" -> {
                decoders.remove(idOf(call))?.release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun releaseAll() {
        decoders.values.forEach { it.release() }
        decoders.clear()
    }

    private fun idOf(call: MethodCall): Long = (call.argument<Any>("id") as? Number)?.toLong() ?: -1L
}

private class ScreenShareDecoder(
    private val producer: TextureRegistry.SurfaceProducer,
    private val mime: String,
) {
    val id: Long = producer.id()

    private val thread = HandlerThread("ScreenShareDecoder").apply { start() }
    private val handler = Handler(thread.looper)
    private val main = Handler(Looper.getMainLooper())
    private val parkingTexture = SurfaceTexture(0)
    private val parking = Surface(parkingTexture)

    private var codec: MediaCodec? = null
    private var visible = true
    private var width = 0
    private var height = 0
    private var presentationUs = 0L

    init {
        producer.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
            override fun onSurfaceAvailable() {
                handler.post {
                    visible = true
                    retarget(producer.surface)
                }
            }

            override fun onSurfaceCleanup() {
                val parked = CountDownLatch(1)
                handler.post {
                    visible = false
                    retarget(parking)
                    parked.countDown()
                }
                parked.await(CLEANUP_WAIT_MS, TimeUnit.MILLISECONDS)
            }
        })
    }

    fun decode(data: ByteArray, key: Boolean, reply: (Map<String, Int>?) -> Unit) {
        handler.post {
            val size = try {
                feed(data, key)
            } catch (e: Exception) {
                Log.w(TAG, "decode failed", e)
                releaseCodec()
                mapOf("needKey" to 1)
            }
            main.post { reply(size) }
        }
    }

    fun release() {
        handler.post {
            releaseCodec()
            parking.release()
            parkingTexture.release()
            thread.quitSafely()
            main.post { producer.release() }
        }
    }

    private fun feed(data: ByteArray, key: Boolean): Map<String, Int>? {
        val active = codec ?: if (key) start() else return mapOf("needKey" to 1)
        val index = active.dequeueInputBuffer(INPUT_TIMEOUT_US)
        if (index < 0) return null
        val input = active.getInputBuffer(index) ?: return null
        input.clear()
        input.put(data)
        presentationUs += FRAME_STEP_US
        active.queueInputBuffer(index, 0, data.size, presentationUs, 0)
        drain(active)
        return if (width > 0 && height > 0) mapOf("width" to width, "height" to height) else null
    }

    private fun start(): MediaCodec {
        producer.setSize(INITIAL_WIDTH, INITIAL_HEIGHT)
        val format = MediaFormat.createVideoFormat(mime, INITIAL_WIDTH, INITIAL_HEIGHT)
        val created = MediaCodec.createDecoderByType(mime)
        created.configure(format, if (visible) producer.surface else parking, null, 0)
        created.start()
        Log.i(TAG, "$mime decoder ${created.name}")
        codec = created
        return created
    }

    private fun drain(active: MediaCodec) {
        val info = MediaCodec.BufferInfo()
        var timeoutUs = OUTPUT_TIMEOUT_US
        while (true) {
            val index = active.dequeueOutputBuffer(info, timeoutUs)
            when {
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> resize(active, active.outputFormat)
                index >= 0 -> {
                    timeoutUs = 0
                    active.releaseOutputBuffer(index, visible && info.size > 0)
                }
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> return
            }
        }
    }

    private fun resize(active: MediaCodec, format: MediaFormat) {
        val cropWidth = cropSize(format, "crop-left", "crop-right")
        val cropHeight = cropSize(format, "crop-top", "crop-bottom")
        val newWidth = cropWidth ?: format.getInteger(MediaFormat.KEY_WIDTH)
        val newHeight = cropHeight ?: format.getInteger(MediaFormat.KEY_HEIGHT)
        if (newWidth == width && newHeight == height) return
        width = newWidth
        height = newHeight
        producer.setSize(width, height)
        if (visible) active.setOutputSurface(producer.surface)
    }

    private fun retarget(surface: Surface) {
        try {
            codec?.setOutputSurface(surface)
        } catch (e: Exception) {
            Log.w(TAG, "setOutputSurface failed", e)
            releaseCodec()
        }
    }

    private fun releaseCodec() {
        val active = codec ?: return
        codec = null
        width = 0
        height = 0
        try {
            active.stop()
        } catch (_: IllegalStateException) {
        }
        active.release()
    }

    private companion object {
        const val TAG = "ScreenShareDecoder"
        const val INITIAL_WIDTH = 1280
        const val INITIAL_HEIGHT = 720
        const val INPUT_TIMEOUT_US = 20_000L
        const val OUTPUT_TIMEOUT_US = 30_000L
        const val FRAME_STEP_US = 100_000L
        const val CLEANUP_WAIT_MS = 500L

        fun cropSize(format: MediaFormat, start: String, end: String): Int? =
            if (format.containsKey(start) && format.containsKey(end)) {
                format.getInteger(end) - format.getInteger(start) + 1
            } else {
                null
            }
    }
}

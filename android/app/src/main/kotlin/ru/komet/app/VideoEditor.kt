package ru.komet.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.Crop
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.RgbMatrix
import androidx.media3.effect.ScaleAndRotateTransformation
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

@UnstableApi
object VideoEditor {
    private const val LOG_TAG = "VideoEditor"

    private val main = Handler(Looper.getMainLooper())
    private val progressHolder = ProgressHolder()

    private var transformer: Transformer? = null
    private var overlayBitmap: Bitmap? = null
    private var pending: MethodChannel.Result? = null

    private class ColorMatrixEffect(private val values: FloatArray) : RgbMatrix {
        override fun getMatrix(presentationTimeUs: Long, useHdr: Boolean) = values
    }

    fun probe(input: String, result: MethodChannel.Result) {
        Thread {
            val data = try {
                readInfo(input)
            } catch (e: Exception) {
                Log.w(LOG_TAG, "probe failed: ${e.message}")
                null
            }
            main.post { result.success(data) }
        }.start()
    }

    private fun readInfo(input: String): Map<String, Any?>? {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(input)
            val rotation = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
            val rawWidth = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                ?.toIntOrNull() ?: 0
            val rawHeight = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                ?.toIntOrNull() ?: 0
            val duration = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
            if (rawWidth <= 0 || rawHeight <= 0) return null
            val swap = rotation % 180 != 0
            val track = readTrackInfo(input)
            return mapOf(
                "width" to if (swap) rawHeight else rawWidth,
                "height" to if (swap) rawWidth else rawHeight,
                "durationMs" to duration,
                "fps" to track.first,
                "hasAudio" to track.second,
            )
        } finally {
            retriever.release()
        }
    }

    private fun readTrackInfo(input: String): Pair<Double, Boolean> {
        val extractor = MediaExtractor()
        var fps = 30.0
        var hasAudio = false
        try {
            extractor.setDataSource(input)
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) hasAudio = true
                if (mime.startsWith("video/") &&
                    format.containsKey(MediaFormat.KEY_FRAME_RATE)
                ) {
                    fps = try {
                        format.getInteger(MediaFormat.KEY_FRAME_RATE).toDouble()
                    } catch (_: ClassCastException) {
                        format.getFloat(MediaFormat.KEY_FRAME_RATE).toDouble()
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(LOG_TAG, "track info failed: ${e.message}")
        } finally {
            extractor.release()
        }
        return Pair(if (fps > 0) fps else 30.0, hasAudio)
    }

    fun frames(
        input: String,
        times: List<Int>,
        size: Int,
        precise: Boolean,
        result: MethodChannel.Result,
    ) {
        Thread {
            val out = ArrayList<ByteArray?>(times.size)
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(input)
                for (ms in times) {
                    out.add(grabFrame(retriever, ms.toLong(), size, precise))
                }
            } catch (e: Exception) {
                Log.w(LOG_TAG, "frames failed: ${e.message}")
                while (out.size < times.size) out.add(null)
            } finally {
                retriever.release()
            }
            main.post { result.success(out) }
        }.start()
    }

    private fun grabFrame(
        retriever: MediaMetadataRetriever,
        timeMs: Long,
        size: Int,
        precise: Boolean,
    ): ByteArray? {
        val us = timeMs * 1000L
        val option = if (precise) {
            MediaMetadataRetriever.OPTION_CLOSEST
        } else {
            MediaMetadataRetriever.OPTION_CLOSEST_SYNC
        }
        val bitmap = (
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    retriever.getScaledFrameAtTime(us, option, size, size)
                } else {
                    retriever.getFrameAtTime(us, option)
                }
            } catch (e: Exception) {
                Log.w(LOG_TAG, "frame at $timeMs failed: ${e.message}")
                null
            }
            ) ?: return null
        return try {
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 82, stream)
            stream.toByteArray()
        } finally {
            bitmap.recycle()
        }
    }

    fun edit(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val input = call.argument<String>("input")
        val output = call.argument<String>("output")
        if (input == null || output == null) {
            result.error("BAD_ARGS", "input/output required", null)
            return
        }
        release()
        pending = result
        try {
            val effects = buildEffects(call)
            val item = MediaItem.Builder()
                .setUri(Uri.fromFile(File(input)))
                .setClippingConfiguration(buildClipping(call))
                .build()
            val edited = EditedMediaItem.Builder(item)
                .setRemoveAudio(call.argument<Boolean>("removeAudio") == true)
                .setEffects(Effects(emptyList(), effects))
                .build()

            val builder = Transformer.Builder(context)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(
                        composition: Composition,
                        exportResult: ExportResult,
                    ) = finish(true)

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException,
                    ) {
                        Log.w(LOG_TAG, "export failed: ${exportException.message}")
                        finish(false)
                    }
                })
            val bitrate = call.argument<Int>("bitrate")
            if (bitrate != null && bitrate > 0) {
                builder.setEncoderFactory(
                    DefaultEncoderFactory.Builder(context)
                        .setRequestedVideoEncoderSettings(
                            VideoEncoderSettings.Builder()
                                .setBitrate(bitrate)
                                .setBitrateMode(
                                    MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR,
                                )
                                .build(),
                        )
                        .build(),
                )
            }
            val transformer = builder.build()
            this.transformer = transformer
            transformer.start(edited, output)
        } catch (e: Exception) {
            Log.w(LOG_TAG, "export start failed: ${e.message}")
            finish(false)
        }
    }

    private fun finish(ok: Boolean) {
        val result = pending
        pending = null
        release()
        result?.success(ok)
    }

    private fun buildClipping(call: MethodCall): MediaItem.ClippingConfiguration {
        val builder = MediaItem.ClippingConfiguration.Builder()
        val start = call.argument<Number>("startMs")?.toLong()
        val end = call.argument<Number>("endMs")?.toLong()
        if (start != null && start > 0) builder.setStartPositionMs(start)
        if (end != null && end > 0) builder.setEndPositionMs(end)
        return builder.build()
    }

    private fun buildEffects(call: MethodCall): List<Effect> {
        val effects = mutableListOf<Effect>()
        val rotation = call.argument<Number>("rotationDegrees")?.toFloat() ?: 0f
        val flipH = call.argument<Boolean>("flipH") == true
        if (flipH || kotlin.math.abs(rotation) > 0.01f) {
            effects.add(
                ScaleAndRotateTransformation.Builder()
                    .setScale(if (flipH) -1f else 1f, 1f)
                    .setRotationDegrees(rotation)
                    .build(),
            )
        }
        val crop = call.argument<List<Double>>("crop")
        if (crop != null && crop.size == 4) {
            effects.add(
                Crop(
                    crop[0].toFloat(),
                    crop[1].toFloat(),
                    crop[2].toFloat(),
                    crop[3].toFloat(),
                ),
            )
        }
        val width = call.argument<Int>("outWidth") ?: 0
        val height = call.argument<Int>("outHeight") ?: 0
        if (width > 0 && height > 0) {
            effects.add(
                Presentation.createForWidthAndHeight(
                    width,
                    height,
                    Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP,
                ),
            )
        }
        val matrix = call.argument<List<Double>>("rgbMatrix")
        if (matrix != null && matrix.size == 16) {
            effects.add(
                ColorMatrixEffect(FloatArray(16) { matrix[it].toFloat() }),
            )
        }
        val overlay = call.argument<String>("overlay")
        if (overlay != null) {
            val bitmap = BitmapFactory.decodeFile(overlay)
            if (bitmap != null) {
                overlayBitmap = bitmap
                effects.add(
                    OverlayEffect(
                        listOf<TextureOverlay>(
                            BitmapOverlay.createStaticBitmapOverlay(bitmap),
                        ),
                    ),
                )
            }
        }
        return effects
    }

    fun progress(result: MethodChannel.Result) {
        val active = transformer
        if (active == null) {
            result.success(-1)
            return
        }
        val state = try {
            active.getProgress(progressHolder)
        } catch (_: IllegalStateException) {
            result.success(-1)
            return
        }
        result.success(
            if (state == Transformer.PROGRESS_STATE_AVAILABLE) {
                progressHolder.progress
            } else {
                -1
            },
        )
    }

    fun cancel(result: MethodChannel.Result) {
        try {
            transformer?.cancel()
        } catch (e: Exception) {
            Log.w(LOG_TAG, "cancel failed: ${e.message}")
        }
        finish(false)
        result.success(null)
    }

    private fun release() {
        transformer = null
        overlayBitmap?.recycle()
        overlayBitmap = null
    }
}

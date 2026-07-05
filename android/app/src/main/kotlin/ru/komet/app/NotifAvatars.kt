package ru.komet.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Shader
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.abs
import kotlin.math.min

object NotifAvatars {

    private val PALETTE = intArrayOf(
        0xFF5B8DEF.toInt(), 0xFFEF5B8D.toInt(), 0xFF3FB950.toInt(),
        0xFFE3883A.toInt(), 0xFF9B72F0.toInt(), 0xFF2AA9B5.toInt(),
    )

    fun load(ctx: Context, senderId: String, name: String): Bitmap {
        val url = avatarUrl(ctx, senderId)
        val raw = if (url != null) downloadBitmap(url) else null
        return if (raw != null) circleCrop(raw) else initialsBitmap(name)
    }

    private fun avatarUrl(ctx: Context, senderId: String): String? {
        if (senderId.isEmpty()) return null
        return try {
            val prefs =
                ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.contact_cache_v1", null) ?: return null
            val entry = JSONObject(raw).optJSONObject(senderId) ?: return null
            entry.optString("a", "").ifEmpty { null }
        } catch (e: Exception) {
            null
        }
    }

    private fun downloadBitmap(url: String): Bitmap? {
        return try {
            val conn = URL(url).openConnection() as HttpURLConnection
            conn.connectTimeout = 4000
            conn.readTimeout = 5000
            conn.doInput = true
            conn.connect()
            val bmp = BitmapFactory.decodeStream(conn.inputStream)
            conn.disconnect()
            bmp
        } catch (e: Exception) {
            null
        }
    }

    private fun circleCrop(src: Bitmap): Bitmap {
        val size = min(src.width, src.height)
        val squared = Bitmap.createBitmap(
            src, (src.width - size) / 2, (src.height - size) / 2, size, size,
        )
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val paint = Paint().apply {
            isAntiAlias = true
            shader = BitmapShader(squared, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        }
        val r = size / 2f
        Canvas(output).drawCircle(r, r, r, paint)
        return output
    }

    private fun initialsBitmap(name: String): Bitmap {
        val size = 256
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val bg = Paint().apply {
            isAntiAlias = true
            color = PALETTE[if (name.isEmpty()) 0 else abs(name.hashCode()) % PALETTE.size]
        }
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, bg)
        val tp = Paint().apply {
            isAntiAlias = true
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
            textSize = size * 0.42f
            isFakeBoldText = true
        }
        val fm = tp.fontMetrics
        canvas.drawText(initialsOf(name), size / 2f, size / 2f - (fm.ascent + fm.descent) / 2, tp)
        return output
    }

    private fun initialsOf(name: String): String {
        val parts = name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
        return when {
            parts.isEmpty() -> "?"
            parts.size == 1 -> parts[0].substring(0, 1).uppercase()
            else -> (parts[0].substring(0, 1) + parts[1].substring(0, 1)).uppercase()
        }
    }
}

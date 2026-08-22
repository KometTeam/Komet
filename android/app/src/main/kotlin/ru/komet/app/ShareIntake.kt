package ru.komet.app

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.util.concurrent.atomic.AtomicLong

object ShareIntake {

    private const val TAG = "ShareIntake"
    private const val CACHE_DIR = "shared_in"
    private const val MAX_FILES = 30

    private val seq = AtomicLong(0L)

    @Volatile
    var sink: EventChannel.EventSink? = null

    fun isShare(intent: Intent?): Boolean {
        val action = intent?.action ?: return false
        return action == Intent.ACTION_SEND || action == Intent.ACTION_SEND_MULTIPLE
    }

    class Snapshot(
        val uris: List<Uri>,
        val text: String?,
        val subject: String?,
        val intentType: String?,
    )

    fun snapshot(intent: Intent): Snapshot? {
        val uris = collectUris(intent).take(MAX_FILES)
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        if (uris.isEmpty() && text.isNullOrBlank()) return null
        return Snapshot(uris, text, subject, intent.type)
    }

    fun materialize(context: Context, snapshot: Snapshot): Map<String, Any?>? {
        val files = ArrayList<Map<String, Any?>>()
        for (uri in snapshot.uris) {
            val copied = copyToCache(context, uri, snapshot.intentType)
            if (copied != null) files.add(copied)
        }

        if (files.isEmpty() && snapshot.text.isNullOrBlank()) return null

        return mapOf(
            "files" to files,
            "text" to snapshot.text,
            "subject" to snapshot.subject,
        )
    }

    fun clearCache(context: Context) {
        try {
            val dir = File(context.cacheDir, CACHE_DIR)
            if (!dir.isDirectory) return
            dir.listFiles()?.forEach { it.delete() }
        } catch (e: Exception) {
            Log.w(TAG, "cache cleanup failed: $e")
        }
    }

    private fun collectUris(intent: Intent): List<Uri> {
        if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            val list = if (android.os.Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            }
            return list?.filterNotNull() ?: emptyList()
        }
        val single = if (android.os.Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        }
        return if (single != null) listOf(single) else emptyList()
    }

    private fun copyToCache(context: Context, uri: Uri, intentType: String?): Map<String, Any?>? {
        val resolver = context.contentResolver
        val mime = resolveMime(resolver, uri, intentType)
        val displayName = queryDisplayName(resolver, uri) ?: fallbackName(uri, mime)

        return try {
            val dir = File(context.cacheDir, CACHE_DIR).apply { mkdirs() }
            val target = File(dir, "${System.currentTimeMillis()}_${seq.incrementAndGet()}_${sanitize(displayName)}")
            resolver.openInputStream(uri).use { input ->
                if (input == null) return null
                target.outputStream().use { output -> input.copyTo(output) }
            }
            if (target.length() <= 0L) {
                target.delete()
                return null
            }
            mapOf(
                "path" to target.absolutePath,
                "name" to displayName,
                "mime" to mime,
                "size" to target.length(),
            )
        } catch (e: Exception) {
            Log.w(TAG, "cannot read $uri: $e")
            null
        }
    }

    private fun resolveMime(resolver: ContentResolver, uri: Uri, intentType: String?): String {
        val fromResolver = resolver.getType(uri)
        if (!fromResolver.isNullOrBlank() && fromResolver != "*/*") return fromResolver
        val ext = MimeTypeMap.getFileExtensionFromUrl(uri.toString())
        if (!ext.isNullOrBlank()) {
            val guessed = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext.lowercase())
            if (!guessed.isNullOrBlank()) return guessed
        }
        if (!intentType.isNullOrBlank() && intentType != "*/*") return intentType
        return "application/octet-stream"
    }

    private fun queryDisplayName(resolver: ContentResolver, uri: Uri): String? {
        if (uri.scheme == ContentResolver.SCHEME_FILE) return uri.lastPathSegment
        return try {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
            }
        } catch (e: Exception) {
            Log.w(TAG, "display name for $uri: $e")
            null
        }
    }

    private fun fallbackName(uri: Uri, mime: String): String {
        val last = uri.lastPathSegment?.substringAfterLast('/')
        if (!last.isNullOrBlank() && last.contains('.')) return last
        val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "bin"
        return "shared_${System.currentTimeMillis()}.$ext"
    }

    private fun sanitize(name: String): String {
        val cleaned = name.replace(Regex("[^A-Za-z0-9._-]"), "_")
        return if (cleaned.length <= 64) cleaned else cleaned.takeLast(64)
    }
}

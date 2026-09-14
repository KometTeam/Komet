package ru.komet.app

import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong

object ClipboardMedia {

    private const val TAG = "ClipboardMedia"
    private const val CHANNEL = "ru.komet.app/clipboard"
    private const val CACHE_DIR = "clipboard_in"
    private const val MAX_ITEMS = 20
    private const val RETENTION_MS = 24L * 60L * 60L * 1000L
    private const val MAX_NAME = 96

    private val textualTypes = setOf(
        ClipDescription.MIMETYPE_TEXT_PLAIN,
        ClipDescription.MIMETYPE_TEXT_HTML,
        ClipDescription.MIMETYPE_TEXT_URILIST,
        ClipDescription.MIMETYPE_TEXT_INTENT,
    )

    private val executor = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())
    private val seq = AtomicLong(0L)

    fun attach(engine: FlutterEngine, context: Context) {
        val app = context.applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasMedia" -> result.success(hasMedia(app))
                    "read" -> read(app, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun clipboard(context: Context): ClipboardManager? =
        context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager

    private fun hasMedia(context: Context): Boolean {
        val description = try {
            clipboard(context)?.primaryClipDescription
        } catch (e: Exception) {
            Log.w(TAG, "clipboard description unavailable: $e")
            null
        } ?: return false
        for (index in 0 until description.mimeTypeCount) {
            if (description.getMimeType(index) !in textualTypes) return true
        }
        return false
    }

    private fun read(context: Context, result: MethodChannel.Result) {
        val clip = try {
            clipboard(context)?.primaryClip
        } catch (e: Exception) {
            Log.w(TAG, "clipboard unavailable: $e")
            null
        }
        if (clip == null || clip.itemCount == 0) {
            result.success(null)
            return
        }

        val uris = ArrayList<Uri>(clip.itemCount)
        for (index in 0 until minOf(clip.itemCount, MAX_ITEMS)) {
            val uri = clip.getItemAt(index).uri ?: continue
            if (uri.scheme != ContentResolver.SCHEME_CONTENT &&
                uri.scheme != ContentResolver.SCHEME_FILE
            ) {
                continue
            }
            uris.add(uri)
        }
        if (uris.isEmpty()) {
            result.success(null)
            return
        }

        val declaredMime = clip.description?.getMimeType(0)
        executor.execute {
            val paths = materialize(context, uris, declaredMime)
            handler.post { result.success(if (paths.isEmpty()) null else mapOf("files" to paths)) }
        }
    }

    private fun materialize(context: Context, uris: List<Uri>, declaredMime: String?): List<String> {
        val root = File(context.cacheDir, CACHE_DIR)
        prune(root)
        val paths = ArrayList<String>(uris.size)
        for (uri in uris) {
            val copied = copyToCache(context, root, uri, declaredMime) ?: continue
            paths.add(copied)
        }
        return paths
    }

    private fun copyToCache(
        context: Context,
        root: File,
        uri: Uri,
        declaredMime: String?,
    ): String? {
        val resolver = context.contentResolver
        val mime = resolveMime(resolver, uri, declaredMime)
        val dir = File(root, "${System.currentTimeMillis()}_${seq.incrementAndGet()}")
        return try {
            dir.mkdirs()
            val target = File(dir, fileName(resolver, uri, mime))
            resolver.openInputStream(uri).use { input ->
                if (input == null) {
                    dir.deleteRecursively()
                    return null
                }
                target.outputStream().use { output -> input.copyTo(output) }
            }
            if (target.length() <= 0L) {
                dir.deleteRecursively()
                null
            } else {
                target.absolutePath
            }
        } catch (e: Exception) {
            Log.w(TAG, "cannot read $uri: $e")
            dir.deleteRecursively()
            null
        }
    }

    private fun resolveMime(resolver: ContentResolver, uri: Uri, declaredMime: String?): String {
        val fromResolver = resolver.getType(uri)
        if (!fromResolver.isNullOrBlank() && fromResolver != "*/*") return fromResolver
        val extension = MimeTypeMap.getFileExtensionFromUrl(uri.toString())
        if (!extension.isNullOrBlank()) {
            val guessed = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.lowercase())
            if (!guessed.isNullOrBlank()) return guessed
        }
        if (!declaredMime.isNullOrBlank() && declaredMime != "*/*") return declaredMime
        return "application/octet-stream"
    }

    private fun fileName(resolver: ContentResolver, uri: Uri, mime: String): String {
        val declared = queryDisplayName(resolver, uri)
            ?: uri.lastPathSegment?.substringAfterLast('/')
        val base = sanitize(declared.orEmpty())
            .ifEmpty { "paste_${System.currentTimeMillis()}" }
        val current = base.substringAfterLast('.', "")
        if (current.length in 1..5 && current.all { it.isLetterOrDigit() }) return base
        val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime)
        return if (extension.isNullOrBlank()) "$base.bin" else "$base.$extension"
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

    private fun sanitize(name: String): String {
        val cleaned = name
            .replace(Regex("[\\\\/:*?\"<>|\\x00-\\x1F]"), "_")
            .trim()
            .trimStart('.')
        return if (cleaned.length <= MAX_NAME) cleaned else cleaned.takeLast(MAX_NAME)
    }

    private fun prune(root: File) {
        try {
            if (!root.isDirectory) {
                root.mkdirs()
                return
            }
            val cutoff = System.currentTimeMillis() - RETENTION_MS
            root.listFiles()?.forEach { entry ->
                if (entry.lastModified() < cutoff) entry.deleteRecursively()
            }
        } catch (e: Exception) {
            Log.w(TAG, "cache cleanup failed: $e")
        }
    }
}

package ru.komet.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

object MediaExport {
    private const val TAG = "MediaExport"
    private const val CHANNEL = "ru.komet.app/media_export"
    private const val FALLBACK_MIME = "application/octet-stream"
    private const val BUFFER_SIZE = 256 * 1024
    private const val CREATE_DOCUMENT_REQUEST = 7714

    private class PendingExport(val source: File, val result: MethodChannel.Result)

    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: PendingExport? = null

    fun attach(engine: FlutterEngine, activity: Activity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveAs" -> saveAs(
                        activity,
                        call.argument<String>("path"),
                        call.argument<String>("name"),
                        result,
                    )
                    "publishAudio" -> publishAudio(
                        activity.applicationContext,
                        call.argument<String>("path"),
                        call.argument<String>("name"),
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    fun onActivityResult(context: Context, requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != CREATE_DOCUMENT_REQUEST) return
        val export = pending ?: return
        pending = null
        val target = data?.data
        if (resultCode != Activity.RESULT_OK || target == null) {
            export.result.success(null)
            return
        }
        val app = context.applicationContext
        worker.execute {
            try {
                copy(app, export.source, target)
                main.post { export.result.success(target.toString()) }
            } catch (e: Exception) {
                Log.w(TAG, "export to $target failed: $e")
                discard(app, target)
                main.post { export.result.error("WRITE_FAILED", e.message, null) }
            }
        }
    }

    private fun saveAs(
        activity: Activity,
        path: String?,
        name: String?,
        result: MethodChannel.Result,
    ) {
        if (path.isNullOrEmpty() || name.isNullOrEmpty()) {
            result.error("BAD_ARGS", "path and name required", null)
            return
        }
        val source = File(path)
        if (!source.isFile) {
            result.error("NO_SOURCE", "source file missing", null)
            return
        }
        pending?.result?.success(null)
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeFor(name)
            putExtra(Intent.EXTRA_TITLE, name)
        }
        pending = PendingExport(source, result)
        try {
            activity.startActivityForResult(intent, CREATE_DOCUMENT_REQUEST)
        } catch (e: ActivityNotFoundException) {
            pending = null
            result.error("NO_PICKER", e.message, null)
        }
    }

    private fun publishAudio(
        context: Context,
        path: String?,
        name: String?,
        result: MethodChannel.Result,
    ) {
        if (path.isNullOrEmpty() || name.isNullOrEmpty()) {
            result.error("BAD_ARGS", "path and name required", null)
            return
        }
        val source = File(path)
        if (!source.isFile) {
            result.error("NO_SOURCE", "source file missing", null)
            return
        }
        worker.execute {
            try {
                val folder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    insertAudio(context, source, name)
                } else {
                    writeLegacyAudio(context, source, name)
                }
                main.post { result.success(folder) }
            } catch (e: Exception) {
                Log.w(TAG, "publish audio $name failed: $e")
                main.post { result.error("WRITE_FAILED", e.message, null) }
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun insertAudio(context: Context, source: File, name: String): String {
        val resolver = context.contentResolver
        val folder = "${audioRoot()}/${appFolder(context)}"
        val pending = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeFor(name))
            put(MediaStore.MediaColumns.RELATIVE_PATH, folder)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val target = resolver.insert(collection, pending)
            ?: throw IOException("MediaStore refused $name")
        try {
            copy(context, source, target)
            val published = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            resolver.update(target, published, null, null)
        } catch (e: Exception) {
            discardMedia(context, target)
            throw e
        }
        return folder
    }

    private fun audioRoot(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Environment.DIRECTORY_RECORDINGS
        } else {
            Environment.DIRECTORY_MUSIC
        }

    @Suppress("DEPRECATION")
    private fun writeLegacyAudio(context: Context, source: File, name: String): String {
        val folder = appFolder(context)
        val root = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC)
        val directory = File(root, folder)
        if (!directory.isDirectory && !directory.mkdirs()) {
            throw IOException("cannot create $directory")
        }
        val target = availableFile(directory, name)
        try {
            source.copyTo(target, bufferSize = BUFFER_SIZE)
        } catch (e: Exception) {
            target.delete()
            throw e
        }
        MediaScannerConnection.scanFile(
            context,
            arrayOf(target.path),
            arrayOf(mimeFor(name)),
            null,
        )
        return "${Environment.DIRECTORY_MUSIC}/$folder"
    }

    private fun availableFile(directory: File, name: String): File {
        var target = File(directory, name)
        if (!target.exists()) return target
        val stem = name.substringBeforeLast('.')
        val extension = name.substringAfterLast('.', "")
        val suffix = if (extension.isEmpty()) "" else ".$extension"
        var index = 2
        while (target.exists()) {
            target = File(directory, "$stem ($index)$suffix")
            index++
        }
        return target
    }

    private fun appFolder(context: Context): String =
        context.applicationInfo.loadLabel(context.packageManager).toString()

    private fun mimeFor(name: String): String {
        val extension = name.substringAfterLast('.', "").lowercase()
        if (extension.isEmpty()) return FALLBACK_MIME
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: FALLBACK_MIME
    }

    private fun copy(context: Context, source: File, target: Uri) {
        val output = context.contentResolver.openOutputStream(target, "w")
            ?: throw IOException("cannot open $target")
        output.use { sink ->
            source.inputStream().use { it.copyTo(sink, BUFFER_SIZE) }
        }
    }

    private fun discardMedia(context: Context, target: Uri) {
        try {
            context.contentResolver.delete(target, null, null)
        } catch (e: Exception) {
            Log.w(TAG, "cannot remove pending media $target: $e")
        }
    }

    private fun discard(context: Context, target: Uri) {
        try {
            DocumentsContract.deleteDocument(context.contentResolver, target)
        } catch (e: Exception) {
            Log.w(TAG, "cannot remove partial export $target: $e")
        }
    }
}

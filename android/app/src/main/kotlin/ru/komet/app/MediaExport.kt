package ru.komet.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.util.Log
import android.webkit.MimeTypeMap
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

    private fun discard(context: Context, target: Uri) {
        try {
            DocumentsContract.deleteDocument(context.contentResolver, target)
        } catch (e: Exception) {
            Log.w(TAG, "cannot remove partial export $target: $e")
        }
    }
}

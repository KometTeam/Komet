package ru.komet.app

import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

object LauncherBadge {
    private const val NAME = "ru.komet.app/launcher_badge"
    private const val TAG = "LauncherBadge"
    private const val PREFS = "komet_badge"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_COUNT = "count"
    private const val KEY_BY_CHATS = "by_chats"
    private const val KEY_CHATS = "chats"
    private val AUTHORITIES = listOf(
        "com.huawei.android.launcher.settings",
        "com.hihonor.android.launcher.settings",
    )

    private val worker = Executors.newSingleThreadExecutor()
    private var channel: MethodChannel? = null

    @Volatile
    private var live = false

    @Volatile
    private var resolvedAuthority: String? = null

    @Volatile
    private var resolved = false

    fun attach(engine: FlutterEngine, ctx: Context) {
        val app = ctx.applicationContext
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, NAME)
        channel = ch
        live = true
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(authority(app) != null)
                "sync" -> {
                    val chats = call.argument<List<Number>>("chats").orEmpty()
                    sync(
                        app,
                        enabled = call.argument<Boolean>("enabled") ?: false,
                        count = call.argument<Int>("count") ?: 0,
                        byChats = call.argument<Boolean>("byChats") ?: false,
                        chats = chats.map { it.toLong().toString() }.toSet(),
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        live = false
    }

    fun countPush(ctx: Context, chatId: Long) {
        if (live || chatId == 0L) return
        worker.execute {
            val p = prefs(ctx)
            if (!p.getBoolean(KEY_ENABLED, true)) return@execute
            val count = p.getInt(KEY_COUNT, 0)
            val edit = p.edit()
            if (p.getBoolean(KEY_BY_CHATS, false)) {
                val chats = p.getStringSet(KEY_CHATS, null).orEmpty()
                val key = chatId.toString()
                if (key in chats) return@execute
                edit.putStringSet(KEY_CHATS, chats + key)
            }
            edit.putInt(KEY_COUNT, count + 1).commit()
            show(ctx, count + 1, launcherClass(ctx))
        }
    }

    fun reapply(ctx: Context, launcherClass: String) {
        val app = ctx.applicationContext
        worker.execute { show(app, prefs(app).getInt(KEY_COUNT, 0), launcherClass) }
    }

    private fun sync(
        ctx: Context,
        enabled: Boolean,
        count: Int,
        byChats: Boolean,
        chats: Set<String>,
    ) {
        worker.execute {
            prefs(ctx).edit()
                .putBoolean(KEY_ENABLED, enabled)
                .putInt(KEY_COUNT, count)
                .putBoolean(KEY_BY_CHATS, byChats)
                .putStringSet(KEY_CHATS, chats)
                .commit()
            show(ctx, count, launcherClass(ctx))
        }
    }

    private fun show(ctx: Context, count: Int, launcherClass: String?) {
        val authority = authority(ctx) ?: return
        if (launcherClass == null) return
        val extras = Bundle().apply {
            putString("package", ctx.packageName)
            putString("class", launcherClass)
            putInt("badgenumber", count)
        }
        try {
            ctx.contentResolver.call(
                Uri.parse("content://$authority/badge/"),
                "change_badge",
                null,
                extras,
            )
        } catch (e: Exception) {
            Log.w(TAG, "change_badge failed: ${e.message}")
        }
    }

    private fun authority(ctx: Context): String? {
        if (!resolved) {
            resolvedAuthority = AUTHORITIES.firstOrNull { providerExists(ctx, it) }
            resolved = true
        }
        return resolvedAuthority
    }

    private fun providerExists(ctx: Context, authority: String): Boolean {
        val pm = ctx.packageManager
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.resolveContentProvider(authority, PackageManager.ComponentInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.resolveContentProvider(authority, 0)
        }
        return info != null
    }

    private fun launcherClass(ctx: Context): String? =
        ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.component?.className

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

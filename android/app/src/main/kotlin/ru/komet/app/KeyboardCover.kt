package ru.komet.app

import android.app.Activity
import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.accessibility.AccessibilityManager
import android.widget.FrameLayout
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import io.flutter.embedding.android.FlutterImageView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.renderer.RenderSurface
import io.flutter.plugin.common.MethodChannel

// Шторка поверх клавиатуры, как в телеграме. Дочернее окно без фокуса Android кладёт
// выше IME, поэтому на время шторки Flutter рисует в него, а клавиатура остаётся
// открытой под ним и видна там, где Flutter оставил пиксели прозрачными.
object KeyboardCover {
    private const val TAG = "KeyboardCover"
    private const val CHANNEL = "ru.komet.app/keyboard_cover"
    private const val SURFACE_TIMEOUT_MS = 500L

    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var engine: FlutterEngine? = null
    private var cover: Cover? = null
    private var backCallback: Any? = null

    fun attach(engine: FlutterEngine, activity: Activity) {
        this.engine = engine
        this.activity = activity
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "engage" -> engage(result)
                    "restore" -> {
                        cover?.restore()
                        result.success(null)
                    }
                    "dismiss" -> {
                        dismiss()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun detach(activity: Activity) {
        if (this.activity !== activity) return
        dismiss()
        this.activity = null
    }

    fun forceRelease() {
        if (cover == null) return
        dismiss()
        channel?.invokeMethod("lost", null)
    }

    private fun engage(result: MethodChannel.Result) {
        if (cover != null) {
            result.success(true)
            return
        }
        val host = activity
        val flutterEngine = engine
        if (host == null || flutterEngine == null || !canCover(host)) {
            result.success(false)
            return
        }
        val view = findFlutterView(host.window.decorView)
        val surface = view?.let(::activeRenderSurface)
        if (view == null || surface == null || !view.isAttachedToWindow) {
            result.success(false)
            return
        }
        val next = Cover(host, view, surface, flutterEngine)
        cover = next
        next.open { ready ->
            if (ready && cover === next) {
                watchBack(host)
                result.success(true)
            } else {
                if (cover === next) cover = null
                result.success(false)
            }
        }
    }

    private fun dismiss() {
        val current = cover ?: return
        cover = null
        unwatchBack()
        current.close()
    }

    private fun canCover(host: Activity): Boolean {
        if (host.isFinishing || host.isDestroyed) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && host.isInMultiWindowMode) {
            return false
        }
        val accessibility =
            host.getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
        return accessibility?.isTouchExplorationEnabled != true
    }

    // Пока платформенный вид переключил FlutterView на FlutterImageView,
    // поверхность уже подменена движком, вторую подмену не устраиваем.
    private fun activeRenderSurface(view: FlutterView): RenderSurface? {
        var candidate: RenderSurface? = null
        for (i in 0 until view.childCount) {
            val child = view.getChildAt(i)
            if (child is FlutterImageView) {
                if (child.attachedRenderer != null) return null
                continue
            }
            if (child is RenderSurface && child.attachedRenderer != null) candidate = child
        }
        return candidate
    }

    private fun watchBack(host: Activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val callback = OnBackInvokedCallback { popRoute() }
        host.onBackInvokedDispatcher.registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_OVERLAY,
            callback,
        )
        backCallback = callback
    }

    private fun unwatchBack() {
        val callback = backCallback ?: return
        backCallback = null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        activity?.onBackInvokedDispatcher?.unregisterOnBackInvokedCallback(
            callback as OnBackInvokedCallback,
        )
    }

    private fun popRoute() {
        engine?.navigationChannel?.popRoute()
    }

    // До Android 13 «назад» приходит клавишей, и открытая под шторкой клавиатура
    // забрала бы её раньше Flutter; FlutterHostFrame отдаёт клавишу сюда до IME.
    fun interceptBack(event: KeyEvent): Boolean {
        if (cover == null || event.keyCode != KeyEvent.KEYCODE_BACK) return false
        if (event.action == KeyEvent.ACTION_UP && !event.isCanceled) popRoute()
        return true
    }

    private class TouchRelay(context: Context, private val target: View) : FrameLayout(context) {
        override fun dispatchTouchEvent(event: MotionEvent): Boolean =
            target.dispatchTouchEvent(event)

        override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean =
            target.dispatchGenericMotionEvent(event)
    }

    private class Cover(
        private val activity: Activity,
        private val flutterView: FlutterView,
        private val renderSurface: RenderSurface,
        private val engine: FlutterEngine,
    ) : SurfaceHolder.Callback, View.OnLayoutChangeListener {
        private val windowManager = activity.windowManager
        private val relay = TouchRelay(activity, flutterView)
        private val canvas = SurfaceView(activity)
        private var onReady: ((Boolean) -> Unit)? = null
        private var rendering = false
        private var added = false
        private val timeout = Runnable { finishOpen(false) }

        fun open(ready: (Boolean) -> Unit) {
            onReady = ready
            canvas.setZOrderOnTop(true)
            canvas.holder.setFormat(PixelFormat.TRANSLUCENT)
            canvas.holder.addCallback(this)
            relay.addView(
                canvas,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
            try {
                windowManager.addView(relay, layoutParams())
                added = true
            } catch (e: Exception) {
                Log.w(TAG, "cover window refused: $e")
                finishOpen(false)
                return
            }
            main.postDelayed(timeout, SURFACE_TIMEOUT_MS)
        }

        private fun layoutParams(): WindowManager.LayoutParams {
            val location = IntArray(2)
            flutterView.getLocationOnScreen(location)
            val secure = activity.window.attributes.flags and
                WindowManager.LayoutParams.FLAG_SECURE
            return WindowManager.LayoutParams(
                flutterView.width,
                flutterView.height,
                WindowManager.LayoutParams.TYPE_APPLICATION_PANEL,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or
                    secure,
                PixelFormat.TRANSLUCENT,
            ).apply {
                token = flutterView.windowToken
                gravity = Gravity.TOP or Gravity.START
                x = location[0]
                y = location[1]
                windowAnimations = 0
                title = TAG
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    layoutInDisplayCutoutMode =
                        WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                    fitInsetsTypes = 0
                    fitInsetsSides = 0
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    layoutInDisplayCutoutMode =
                        WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            }
        }

        override fun surfaceCreated(holder: SurfaceHolder) {}

        override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
            if (onReady == null) return
            if (width != flutterView.width || height != flutterView.height) return
            if (!alignedWithFlutterView()) {
                finishOpen(false)
                return
            }
            renderSurface.pause()
            engine.renderer.swapSurface(holder.surface)
            rendering = true
            flutterView.addOnLayoutChangeListener(this)
            finishOpen(true)
        }

        override fun surfaceDestroyed(holder: SurfaceHolder) {
            if (!rendering) return
            restore()
            val own = (renderSurface as? SurfaceView)?.holder?.surface
            if (own == null || !own.isValid) engine.renderer.stopRenderingToSurface()
            main.post { KeyboardCover.forceRelease() }
        }

        override fun onLayoutChange(
            v: View,
            left: Int,
            top: Int,
            right: Int,
            bottom: Int,
            oldLeft: Int,
            oldTop: Int,
            oldRight: Int,
            oldBottom: Int,
        ) {
            if (right - left == oldRight - oldLeft && bottom - top == oldBottom - oldTop) return
            main.post { KeyboardCover.forceRelease() }
        }

        private fun alignedWithFlutterView(): Boolean {
            val cover = IntArray(2)
            val target = IntArray(2)
            relay.getLocationOnScreen(cover)
            flutterView.getLocationOnScreen(target)
            return cover.contentEquals(target)
        }

        private fun finishOpen(ok: Boolean) {
            main.removeCallbacks(timeout)
            val callback = onReady ?: return
            onReady = null
            if (!ok) close()
            callback(ok)
        }

        fun restore() {
            if (!rendering) return
            rendering = false
            flutterView.removeOnLayoutChangeListener(this)
            renderSurface.resume()
        }

        fun close() {
            restore()
            main.removeCallbacks(timeout)
            canvas.holder.removeCallback(this)
            if (!added) return
            added = false
            try {
                windowManager.removeViewImmediate(relay)
            } catch (e: Exception) {
                Log.w(TAG, "cover window already gone: $e")
            }
        }
    }
}

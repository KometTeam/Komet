package ru.komet.app

import android.app.Activity
import android.content.Context
import android.os.Build
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsAnimation
import android.widget.FrameLayout
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterView

internal fun findFlutterView(root: View): FlutterView? {
    if (root is FlutterView) return root
    if (root !is ViewGroup) return null
    for (i in 0 until root.childCount) {
        findFlutterView(root.getChildAt(i))?.let { return it }
    }
    return null
}

// Рамка над контейнером FlutterFragment, ставится, пока он ещё пуст.
// Ловит «назад» раньше IME, пока шторка накрывает клавиатуру, и возвращает Flutter
// настоящие insets окна: встроенный колбэк IME копит их до onEnd анимации
// клавиатуры, а при наложении анимаций (flutter/flutter#118761) или без onEnd на
// части прошивок экран остаётся поднятым на высоту уже закрытой клавиатуры.
class FlutterHostFrame private constructor(context: Context) : FrameLayout(context) {
    companion object {
        private const val SETTLE_MS = 150L
        private const val STUCK_MS = 1000L

        fun install(activity: Activity) {
            val content = activity.findViewById<ViewGroup>(android.R.id.content) ?: return
            if (content.childCount != 1) return
            val container = content.getChildAt(0)
            if (container is FlutterHostFrame) return
            val params = container.layoutParams
            content.removeView(container)
            val host = FlutterHostFrame(activity)
            host.addView(
                container,
                LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT),
            )
            content.addView(host, params)
        }
    }

    private var lastInsets: WindowInsets? = null
    private var imeAnimating = false
    private val resync = Runnable { resyncInsets() }

    init {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) watchImeAnimation()
    }

    override fun dispatchKeyEventPreIme(event: KeyEvent): Boolean =
        KeyboardCover.interceptBack(event) || super.dispatchKeyEventPreIme(event)

    override fun dispatchApplyWindowInsets(insets: WindowInsets): WindowInsets {
        val result = super.dispatchApplyWindowInsets(insets)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            lastInsets = insets
            if (!imeAnimating) scheduleResync(SETTLE_MS)
        }
        return result
    }

    override fun onDetachedFromWindow() {
        removeCallbacks(resync)
        super.onDetachedFromWindow()
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun watchImeAnimation() {
        setWindowInsetsAnimationCallback(
            object : WindowInsetsAnimation.Callback(DISPATCH_MODE_CONTINUE_ON_SUBTREE) {
                override fun onPrepare(animation: WindowInsetsAnimation) {
                    if (!animation.movesIme()) return
                    imeAnimating = true
                    scheduleResync(STUCK_MS)
                }

                override fun onProgress(
                    insets: WindowInsets,
                    runningAnimations: MutableList<WindowInsetsAnimation>,
                ): WindowInsets = insets

                override fun onEnd(animation: WindowInsetsAnimation) {
                    if (!animation.movesIme()) return
                    imeAnimating = false
                    scheduleResync(SETTLE_MS)
                }
            },
        )
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun WindowInsetsAnimation.movesIme(): Boolean =
        typeMask and WindowInsets.Type.ime() != 0

    private fun scheduleResync(delayMs: Long) {
        removeCallbacks(resync)
        postDelayed(resync, delayMs)
    }

    // Повтор тех же insets Flutter не перестраивает, так что лишний вызов бесплатен.
    private fun resyncInsets() {
        imeAnimating = false
        val insets = lastInsets ?: return
        findFlutterView(this)?.onApplyWindowInsets(insets)
    }
}

package ru.komet.app

import android.content.Context
import android.content.Intent

object LaunchIntents {
    fun app(ctx: Context): Intent {
        val launcher = ctx.packageManager
            .getLaunchIntentForPackage(ctx.packageName)?.component
        return if (launcher != null) {
            Intent().setComponent(launcher)
        } else {
            Intent(ctx, MainActivity::class.java)
        }
    }
}

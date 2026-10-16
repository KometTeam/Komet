package ru.komet.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat

object LauncherShortcuts {
    private data class Action(
        val id: String,
        val route: String,
        val label: Int,
        val icon: Int,
    )

    private val actions = listOf(
        Action(
            id = "action_saved_messages",
            route = ":saved-messages",
            label = R.string.shortcut_saved_messages,
            icon = R.drawable.ic_shortcut_saved,
        ),
        Action(
            id = "action_search",
            route = ":chats-search",
            label = R.string.shortcut_search,
            icon = R.drawable.ic_shortcut_search,
        ),
    )

    val conversationRank: Int get() = actions.size

    fun publish(ctx: Context) {
        actions.forEachIndexed { rank, action ->
            try {
                val label = ctx.getString(action.label)
                val shortcut = ShortcutInfoCompat.Builder(ctx, action.id)
                    .setShortLabel(label)
                    .setLongLabel(label)
                    .setIcon(IconCompat.createWithResource(ctx, action.icon))
                    .setIntent(routeIntent(ctx, action.route))
                    .setRank(rank)
                    .build()
                ShortcutManagerCompat.pushDynamicShortcut(ctx, shortcut)
            } catch (e: Exception) {
                Log.w(TAG, "${action.id} publish failed: $e")
            }
        }
    }

    private fun routeIntent(ctx: Context, route: String): Intent =
        LaunchIntents.app(ctx)
            .setAction(Intent.ACTION_VIEW)
            .setData(Uri.parse("komet://max.ru/$route"))
            .addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )

    private const val TAG = "LauncherShortcuts"
}

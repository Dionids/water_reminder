package com.example.untitled1.wear

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * BroadcastReceiver на стороне часов.
 * Срабатывает по алярму, запланированному в DataListenerService,
 * и показывает уведомление-напоминание выпить воду.
 */
class WaterReminderReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "WaterReminderReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val glassIndex   = intent.getIntExtra(DataListenerService.EXTRA_GLASS_INDEX, 1)
        val totalGlasses = intent.getIntExtra(DataListenerService.EXTRA_TOTAL_GLASSES, 1)
        val remaining    = (totalGlasses - glassIndex).coerceAtLeast(0)

        Log.d(TAG, "Water reminder fired: glass $glassIndex / $totalGlasses")

        val openIntent = Intent(context, MainActivity::class.java)
        val pendingOpen = PendingIntent.getActivity(
            context, glassIndex, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, DataListenerService.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("💧 Выпей стакан воды")
            .setContentText("Стакан $glassIndex из $totalGlasses · осталось $remaining")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingOpen)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 200, 100, 200))
            .build()

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(glassIndex, notification)

        // Обновляем Tile — пользователь выпил стакан
        AquaTileService.requestUpdate(context)
    }
}

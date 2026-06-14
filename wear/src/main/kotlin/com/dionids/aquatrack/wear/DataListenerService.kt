package com.dionids.aquatrack.wear

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService

class DataListenerService : WearableListenerService() {

    companion object {
        private const val TAG = "DataListenerService"
        const val CHANNEL_ID          = "aqua_reminders"
        const val CHANNEL_NAME        = "Напоминания о воде"
        const val EXTRA_GLASS_INDEX   = "glass_index"
        const val EXTRA_TOTAL_GLASSES = "total_glasses"
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        dataEvents.forEach { event ->
            val path = event.dataItem.uri.path ?: return@forEach
            Log.d(TAG, "Data changed: $path")

            when {
                path == "/aquatrack/sync" -> {
                    val dataMap   = DataMapItem.fromDataItem(event.dataItem).dataMap
                    val currentMl = dataMap.getInt("current_ml", -1)
                    val goalMl    = dataMap.getInt("goal_ml", -1)
                    if (currentMl >= 0 && goalMl > 0) {
                        WaterDataStore.saveWaterData(this, currentMl, goalMl)
                        AquaTileService.requestUpdate(this)
                    }
                }

                path.startsWith("/aquatrack/reminder/") -> {
                    val dataMap      = DataMapItem.fromDataItem(event.dataItem).dataMap
                    val scheduledAt  = dataMap.getLong("scheduled_at", 0L)
                    val glassIndex   = dataMap.getInt("glass_index", 1)
                    val totalGlasses = dataMap.getInt("total_glasses", 1)
                    if (scheduledAt > System.currentTimeMillis()) {
                        scheduleLocalAlarm(scheduledAt, glassIndex, totalGlasses)
                        Log.d(TAG, "Reminder $glassIndex/$totalGlasses scheduled at $scheduledAt")
                    }
                }
            }
        }
    }

    private fun scheduleLocalAlarm(scheduledAt: Long, glassIndex: Int, totalGlasses: Int) {
        ensureNotificationChannel()

        val intent = Intent(this, WaterReminderReceiver::class.java).apply {
            putExtra(EXTRA_GLASS_INDEX,   glassIndex)
            putExtra(EXTRA_TOTAL_GLASSES, totalGlasses)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this, glassIndex, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            alarmManager.set(AlarmManager.RTC_WAKEUP, scheduledAt, pendingIntent)
        } else {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, scheduledAt, pendingIntent)
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH)
                )
            }
        }
    }
}

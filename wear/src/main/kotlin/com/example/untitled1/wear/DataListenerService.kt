package com.example.untitled1.wear

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

/**
 * Слушает изменения данных от телефона через DataClient.
 *
 * Обрабатывает два типа путей:
 *  - /aquatrack/sync          — обновление прогресса воды (currentMl / goalMl)
 *  - /aquatrack/reminder/{n}  — запланированное напоминание выпить стакан воды
 */
class DataListenerService : WearableListenerService() {

    companion object {
        private const val TAG = "DataListenerService"
        const val CHANNEL_ID   = "aqua_reminders"
        const val CHANNEL_NAME = "Напоминания о воде"
        const val EXTRA_GLASS_INDEX   = "glass_index"
        const val EXTRA_TOTAL_GLASSES = "total_glasses"
    }

    override fun onD
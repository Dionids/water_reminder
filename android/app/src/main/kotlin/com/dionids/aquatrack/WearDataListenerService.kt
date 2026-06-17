package com.dionids.aquatrack

import android.content.Intent
import android.util.Log
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Слушает данные от часов на стороне телефона.
 *
 * Когда пользователь нажал + на часах, часы отправляют новое значение
 * через DataClient в /aquatrack/add_water. Этот сервис:
 *  1. Принимает новое значение currentMl и added_ml
 *  2. Отправляет broadcast — WearSyncChannel пробрасывает его в Flutter EventChannel
 *  3. Flutter вызывает _addWater(addedMl) и пишет в Hive
 */
class WearDataListenerService : WearableListenerService() {

    companion object {
        const val ACTION_WATER_FROM_WEAR = "com.dionids.aquatrack.WATER_FROM_WEAR"
        const val EXTRA_CURRENT_ML = "current_ml"
        const val EXTRA_GOAL_ML    = "goal_ml"
        const val EXTRA_ADDED_ML   = "added_ml"
        private const val TAG = "WearDataListener"
        private const val DEFAULT_GLASS_ML = 250
    }

    // MessageClient — прямой BT канал, работает без Google аккаунта
    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path == "/aquatrack/add_water") {
            val parts    = String(messageEvent.data).split(",")
            val currentMl = parts.getOrNull(0)?.toIntOrNull() ?: -1
            val goalMl    = parts.getOrNull(1)?.toIntOrNull() ?: -1
            val addedMl   = parts.getOrNull(2)?.toIntOrNull() ?: DEFAULT_GLASS_ML

            if (currentMl >= 0 && goalMl > 0) {
                Log.d(TAG, "Message from watch: +$addedMl ml → $currentMl/$goalMl")
                val intent = Intent(ACTION_WATER_FROM_WEAR).apply {
                    putExtra(EXTRA_CURRENT_ML, currentMl)
                    putExtra(EXTRA_GOAL_ML,    goalMl)
                    putExtra(EXTRA_ADDED_ML,   addedMl)
                    putExtra("added_ml",       addedMl)
                    setPackage(packageName)
                }
                sendBroadcast(intent)
            }
        }
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        dataEvents.forEach { event ->
            val path = event.dataItem.uri.path ?: return@forEach
            Log.d(TAG, "Data changed: $path")

            if (path == "/aquatrack/add_water") {
                val dataMap   = DataMapItem.fromDataItem(event.dataItem).dataMap
                val currentMl = dataMap.getInt("current_ml", -1)
                val goalMl    = dataMap.getInt("goal_ml", -1)
                val addedMl   = dataMap.getInt("added_ml", DEFAULT_GLASS_ML)

                if (currentMl >= 0 && goalMl > 0) {
                    Log.d(TAG, "Received from watch: +$addedMl ml → total $currentMl/$goalMl ml")

                    val intent = Intent(ACTION_WATER_FROM_WEAR).apply {
                        putExtra(EXTRA_CURRENT_ML, currentMl)
                        putExtra(EXTRA_GOAL_ML,    goalMl)
                        putExtra(EXTRA_ADDED_ML,   addedMl)
                        putExtra("added_ml",       addedMl)   // для WearSyncChannel.BroadcastReceiver
                        setPackage(packageName)
                    }
                    sendBroadcast(intent)
                }
            }
        }
    }
}

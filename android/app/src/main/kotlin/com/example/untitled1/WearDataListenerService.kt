package com.example.untitled1

import android.content.Intent
import android.util.Log
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService

/**
 * Слушает данные от часов на стороне телефона.
 *
 * Когда пользователь нажал + на часах, часы отправляют новое значение
 * через DataClient в /aquatrack/add_water. Этот сервис:
 *  1. Принимает новое значение currentMl
 *  2. Сохраняет локально через Hive (через broadcast)
 *  3. Запускает фоновую синхронизацию на сервер
 *
 * Регистрация в AndroidManifest.xml уже выполнена ниже в комментарии.
 */
class WearDataListenerService : WearableListenerService() {

    companion object {
        const val ACTION_WATER_FROM_WEAR = "com.example.untitled1.WATER_FROM_WEAR"
        const val EXTRA_CURRENT_ML = "current_ml"
        const val EXTRA_GOAL_ML = "goal_ml"
        private const val TAG = "WearDataListener"
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        dataEvents.forEach { event ->
            val path = event.dataItem.uri.path ?: return@forEach
            Log.d(TAG, "Data changed: $path")

            if (path == "/aquatrack/add_water") {
                val dataMap = DataMapItem.fromDataItem(event.dataItem).dataMap
                val currentMl = dataMap.getInt("current_ml", -1)
                val goalMl    = dataMap.getInt("goal_ml", -1)
                val timestamp = dataMap.getLong("timestamp", 0L)

                if (currentMl >= 0 && goalMl > 0) {
                    Log.d(TAG, "Received from watch: $currentMl ml / $goalMl ml")

                    // Отправить broadcast — Flutter слушает через MethodChannel или
                    // можно обработать нативно через SharedPreferences + home_widget
                    val intent = Intent(ACTION_WATER_FROM_WEAR).apply {
                        putExtra(EXTRA_CURRENT_ML, currentMl)
                        putExtra(EXTRA_GOAL_ML, goalMl)
                        setPackage(packageName)
                    }
                    sendBroadcast(intent)
                }
            }
        }
    }
}

/*
 * Добавить в android/app/src/main/AndroidManifest.xml внутрь <application>:
 *
 * <service
 *     android:name=".WearDataListenerService"
 *     android:exported="true">
 *     <intent-filter>
 *         <action android:name="com.google.android.gms.wearable.DATA_CHANGED" />
 *         <data
 *             android:host="*"
 *             android:pathPrefix="/aquatrack"
 *             android:scheme="wear" />
 *     </intent-filter>
 * </service>
 */

package com.example.untitled1.wear

import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService

/**
 * Слушает изменения данных от телефона.
 * Телефон пишет в /aquatrack/sync при каждом добавлении воды или пересчёте нормы.
 */
class DataListenerService : WearableListenerService() {

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        dataEvents.forEach { event ->
            val path = event.dataItem.uri.path ?: return@forEach

            if (path.startsWith("/aquatrack")) {
                val dataMap = DataMapItem.fromDataItem(event.dataItem).dataMap
                val currentMl = dataMap.getInt("current_ml", -1)
                val goalMl    = dataMap.getInt("goal_ml", -1)

                if (currentMl >= 0 && goalMl > 0) {
                    WaterDataStore.saveWaterData(this, currentMl, goalMl)

                    // Обновить Tile если он активен
                    AquaTileService.requestUpdate(this)
                }
            }
        }
    }
}

package com.example.untitled1.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.wear.tiles.TileService
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

class MainActivity : ComponentActivity() {

    private lateinit var waterFace: WaterFaceCanvas
    private lateinit var dataClient: DataClient

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        dataClient = Wearable.getDataClient(this)

        waterFace = WaterFaceCanvas(this)
        setContentView(waterFace)

        refreshData()
        requestTileAddOnce()

        waterFace.setOnClickListener {
            addGlassAndSync()
        }
    }

    override fun onResume() {
        super.onResume()
        refreshData()
    }

    private fun refreshData() {
        val pct  = WaterDataStore.getPercent(this)
        val ml   = WaterDataStore.getCurrentMl(this)
        val goal = WaterDataStore.getGoalMl(this)

        waterFace.setTarget(pct)
        waterFace.currentMl = ml
        waterFace.goalMl = goal
    }

    private fun addGlassAndSync() {
        val newMl = WaterDataStore.addGlass(this, glassML = 200)
        val goal  = WaterDataStore.getGoalMl(this)
        val pct   = WaterDataStore.getPercent(this)

        waterFace.setTarget(pct)
        waterFace.currentMl = newMl
        waterFace.goalMl = goal

        syncToPhone(newMl, goal)
    }

    /**
     * При первом запуске показывает системный диалог:
     * "Добавить карточку AquaTrack?" → пользователь жмёт Добавить.
     * Повторно не показывается благодаря флагу tile_requested.
     */
    private fun requestTileAddOnce() {
        val prefs = getSharedPreferences("aquatrack_wear", MODE_PRIVATE)
        if (prefs.getBoolean("tile_requested", false)) return

        TileService.getUpdater(this)
            .requestTileAdd(AquaTileService::class.java)
            .addOnCompleteListener {
                // Сохраняем флаг независимо от того, согласился пользователь или нет
                prefs.edit().putBoolean("tile_requested", true).apply()
            }
    }

    /**
     * Отправляем новое значение воды на телефон через Wearable DataClient.
     * Телефон получит это в WearDataListenerService и запишет в Hive.
     */
    private fun syncToPhone(currentMl: Int, goalMl: Int) {
        val request = PutDataMapRequest.create("/aquatrack/add_water").apply {
            dataMap.putInt("current_ml", currentMl)
            dataMap.putInt("goal_ml", goalMl)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        dataClient.putDataItem(request)
            .addOnSuccessListener { /* sync ok */ }
            .addOnFailureListener { /* телефон недоступен — данные сохранены локально */ }
    }
}

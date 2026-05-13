package com.example.untitled1.wear

import android.content.ComponentName
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.wear.tiles.TileService
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

class MainActivity : ComponentActivity() {

    private lateinit var waterFace: WaterFaceCanvas
    private lateinit var dataClient: DataClient

    companion object {
        private const val TAG = "WearMainActivity"
        private const val PREF_TILE_REQUESTED = "tile_add_requested"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        dataClient = Wearable.getDataClient(this)

        waterFace = WaterFaceCanvas(this)
        setContentView(waterFace)

        refreshData()

        waterFace.setOnClickListener {
            addGlassAndSync()
        }

        // Предлагаем добавить Tile при первом запуске
        requestTileAddIfNeeded()
    }

    override fun onResume() {
        super.onResume()
        refreshData()
    }

    /**
     * Показывает системный диалог «Добавить карточку AquaTrack?» один раз.
     * TileService.requestTileAdd() появился в wear.tiles:1.2.0+.
     * Результаты: RESULT_ACCEPTED / RESULT_REJECTED / RESULT_ALREADY_ADDED / RESULT_UNAVAILABLE.
     */
    private fun requestTileAddIfNeeded() {
        val prefs = getSharedPreferences(WaterDataStore.PREFS_NAME_CONST, MODE_PRIVATE)
        if (prefs.getBoolean(PREF_TILE_REQUESTED, false)) return

        val component = ComponentName(this, AquaTileService::class.java)
        TileService.requestTileAdd(this, component)
            .addOnSuccessListener { result ->
                Log.d(TAG, "requestTileAdd result: $result")
                // Запоминаем что уже спрашивали — не надоедаем снова
                prefs.edit().putBoolean(PREF_TILE_REQUESTED, true).apply()
            }
            .addOnFailureListener { e ->
                Log.w(TAG, "requestTileAdd failed: ${e.message}")
            }
    }

    private fun refreshData() {
        val pct  = WaterDataStore.getPercent(this)
        val ml   = WaterDataStore.getCurrentMl(this)
        val goal = WaterDataStore.getGoalMl(this)

        waterFace.setTarget(pct)
        waterFace.currentMl = ml
        waterFace.goalMl    = goal
    }

    private fun addGlassAndSync() {
        val newMl = WaterDataStore.addGlass(this, glassML = WaterDataStore.GLASS_ML)
        val goal  = WaterDataStore.getGoalMl(this)
        val pct   = WaterDataStore.getPercent(this)

        waterFace.setTarget(pct)
        waterFace.currentMl = newMl
        waterFace.goalMl    = goal

        syncToPhone(newMl, goal)
    }

    private fun syncToPhone(currentMl: Int, goalMl: Int) {
        val request = PutDataMapRequest.create("/aquatrack/add_water").apply {
            dataMap.putInt("current_ml", currentMl)
            dataMap.putInt("goal_ml",    goalMl)
            dataMap.putInt("added_ml",   WaterDataStore.GLASS_ML)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        dataClient.putDataItem(request)
            .addOnSuccessListener { Log.d(TAG, "Synced to phone: $currentMl/$goalMl ml") }
            .addOnFailureListener { Log.w(TAG, "Phone not reachable: ${it.message}") }
    }
}

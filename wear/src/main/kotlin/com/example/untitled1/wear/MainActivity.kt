package com.example.untitled1.wear

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.wear.tiles.TileService
import android.content.ComponentName
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

class MainActivity : ComponentActivity() {

    private lateinit var waterFace: WaterFaceCanvas
    private lateinit var dataClient: DataClient

    companion object {
        private const val TAG = "WearMainActivity"
        private const val PREF_TILE_REQUESTED = "tile_add_requested"
        const val ACTION_ADD_WATER = "add_water"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        dataClient = Wearable.getDataClient(this)

        waterFace = WaterFaceCanvas(this)
        setContentView(waterFace)

        // Запрашиваем разрешение на уведомления (Android 13+ / Wear OS 4+)
        requestNotificationPermission()

        refreshData()

        waterFace.setOnClickListener {
            addGlassAndSync()
        }

        // Обработка запуска с действием add_water (из Tile кнопки)
        handleIntent(intent)

        // Предлагаем добавить Tile при первом запуске
        requestTileAddIfNeeded()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
        refreshData()
    }

    override fun onResume() {
        super.onResume()
        refreshData()
    }

    /**
     * Если запущено с action=add_water (например, из Tile кнопки) — сразу добавляем стакан.
     */
    private fun handleIntent(intent: Intent?) {
        if (intent?.getStringExtra("action") == ACTION_ADD_WATER) {
            Log.d(TAG, "Tile button: adding glass from intent")
            addGlassAndSync()
        }
    }

    /**
     * Runtime-запрос разрешения на уведомления.
     * Без этого на Wear OS 4 (Android 13+) уведомления не появляются.
     */
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this, Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    1001,
                )
                Log.d(TAG, "POST_NOTIFICATIONS permission requested")
            }
        }
    }

    /**
     * Показывает системный диалог «Добавить карточку AquaTrack?» один раз.
     */
    private fun requestTileAddIfNeeded() {
        val prefs = getSharedPreferences(WaterDataStore.PREFS_NAME_CONST, MODE_PRIVATE)
        if (prefs.getBoolean(PREF_TILE_REQUESTED, false)) return

        val component = ComponentName(this, AquaTileService::class.java)
        TileService.requestTileAdd(this, component)
            .addOnSuccessListener { result ->
                Log.d(TAG, "requestTileAdd result: $result")
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

    fun addGlassAndSync() {
        val newMl = WaterDataStore.addGlass(this, glassML = WaterDataStore.GLASS_ML)
        val goal  = WaterDataStore.getGoalMl(this)
        val pct   = WaterDataStore.getPercent(this)

        waterFace.setTarget(pct)
        waterFace.currentMl = newMl
        waterFace.goalMl    = goal

        AquaTileService.requestUpdate(this)

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

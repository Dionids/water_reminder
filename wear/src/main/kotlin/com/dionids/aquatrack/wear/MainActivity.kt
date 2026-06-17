package com.dionids.aquatrack.wear

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

class MainActivity : ComponentActivity() {

    private lateinit var waterFace: WaterFaceCanvas
    private lateinit var dataClient: DataClient

    companion object {
        private const val TAG = "WearMainActivity"
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
    private var launchedFromTile = false

    private fun handleIntent(intent: Intent?) {
        if (intent?.getStringExtra("action") == ACTION_ADD_WATER) {
            Log.d(TAG, "Tile button: adding glass")
            launchedFromTile = true
            addGlassAndSync()
            // finish() вызывается ПОСЛЕ отправки сообщения в syncToPhone()
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
        // Плитка автоматически появляется в списке добавления на часах
        // после установки приложения — ручной вызов requestTileAdd не нужен.
        Log.d(TAG, "Tile available via + button on watch")
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
        // Отправляем ОБОИМИ каналами параллельно для максимальной надёжности:
        // 1. MessageClient — мгновенная доставка когда приложение открыто (BT/Wi-Fi)
        // 2. DataClient —persistent доставка даже когда приложение закрыто
        syncViaMessage(currentMl, goalMl)
        syncViaDataLayer(currentMl, goalMl)
    }

    private fun syncViaMessage(currentMl: Int, goalMl: Int) {
        val messageClient = com.google.android.gms.wearable.Wearable.getMessageClient(this)
        val nodeClient    = com.google.android.gms.wearable.Wearable.getNodeClient(this)
        val payload = "$currentMl,$goalMl,${WaterDataStore.GLASS_ML}".toByteArray()

        nodeClient.connectedNodes.addOnSuccessListener { nodes ->
            if (nodes.isEmpty()) {
                Log.w(TAG, "No connected nodes via MessageClient")
                finishIfFromTile()
                return@addOnSuccessListener
            }
            var pending = nodes.size
            for (node in nodes) {
                messageClient.sendMessage(node.id, "/aquatrack/add_water", payload)
                    .addOnSuccessListener {
                        Log.d(TAG, "Message sent to ${node.displayName}: $currentMl/$goalMl")
                        if (--pending == 0) finishIfFromTile()
                    }
                    .addOnFailureListener {
                        Log.w(TAG, "Message failed: ${it.message}")
                        if (--pending == 0) finishIfFromTile()
                    }
            }
        }.addOnFailureListener {
            Log.w(TAG, "NodeClient failed: ${it.message}")
            finishIfFromTile()
        }
    }

    private fun finishIfFromTile() {
        if (launchedFromTile) {
            // небольшая задержка чтобы сообщение точно ушло
            waterFace.postDelayed({ finish() }, 300)
        }
    }

    private fun syncViaDataLayer(currentMl: Int, goalMl: Int) {
        try {
            val request = PutDataMapRequest.create("/aquatrack/add_water").apply {
                dataMap.putInt("current_ml", currentMl)
                dataMap.putInt("goal_ml",    goalMl)
                dataMap.putInt("added_ml",   WaterDataStore.GLASS_ML)
                dataMap.putLong("timestamp", System.currentTimeMillis())
            }.asPutDataRequest().setUrgent()
            dataClient.putDataItem(request)
                .addOnSuccessListener { Log.d(TAG, "DataLayer fallback: $currentMl/$goalMl") }
                .addOnFailureListener { Log.w(TAG, "DataLayer also failed: ${it.message}") }
        } catch (e: Exception) {
            Log.w(TAG, "DataLayer error: $e")
        }
    }
}

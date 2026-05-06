package com.example.untitled1

import android.content.SharedPreferences
import android.graphics.drawable.Icon
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.R

/**
 * Quick Settings Tile — появляется в шторке Android (там где Wi-Fi, фонарик).
 * Нажатие → добавляет 200 мл воды и обновляет плитку.
 * Долгое нажатие → открывает приложение.
 *
 * Пользователь добавляет плитку: шторка → карандаш (редактировать) →
 * найти AquaTrack → перетащить в активные плитки.
 */
class AquaQuickTile : TileService() {

    private val prefs: SharedPreferences
        get() = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)

    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()
        addGlass()
        updateTile()
    }

    private fun addGlass() {
        val current = prefs.getFloat("flutter.widget_current_ml", 0f)
        val goal    = prefs.getFloat("flutter.widget_goal_ml", 2000f)
        val newVal  = (current + 200f).coerceAtMost(goal)
        prefs.edit().putFloat("flutter.widget_current_ml", newVal).apply()

        // Обновить home screen виджет если он есть
        updateHomeWidget()
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        val current = prefs.getFloat("flutter.widget_current_ml", 0f).toInt()
        val goal    = prefs.getFloat("flutter.widget_goal_ml", 2000f).toInt()
        val pct     = if (goal > 0) (current * 100 / goal).coerceIn(0, 100) else 0

        tile.label     = "Вода $pct%"
        tile.subtitle  = "$current / $goal мл"
        tile.state     = if (pct >= 100) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.updateTile()
    }

    private fun updateHomeWidget() {
        try {
            val intent = android.content.Intent(this, widget.AquaWidgetReceiver::class.java).apply {
                action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val ids = android.appwidget.AppWidgetManager.getInstance(this@AquaQuickTile)
                    .getAppWidgetIds(
                        android.content.ComponentName(this@AquaQuickTile, widget.AquaWidgetReceiver::class.java)
                    )
                putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            sendBroadcast(intent)
        } catch (_: Exception) {}
    }
}

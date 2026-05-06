package com.example.untitled1

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.example.untitled1.widget.AquaWidgetReceiver

class AquaQuickTile : TileService() {

    private val prefs get() =
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)

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
        refreshHomeWidget()
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        val current = prefs.getFloat("flutter.widget_current_ml", 0f).toInt()
        val goal    = prefs.getFloat("flutter.widget_goal_ml", 2000f).toInt()
        val pct     = if (goal > 0) (current * 100 / goal).coerceIn(0, 100) else 0

        tile.label    = "Вода $pct%"
        tile.subtitle = "$current / $goal мл"
        tile.state    = if (pct >= 100) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.updateTile()
    }

    private fun refreshHomeWidget() {
        try {
            val manager = AppWidgetManager.getInstance(this)
            val ids = manager.getAppWidgetIds(
                ComponentName(this, AquaWidgetReceiver::class.java)
            )
            val intent = Intent(this, AquaWidgetReceiver::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            sendBroadcast(intent)
        } catch (_: Exception) {}
    }
}

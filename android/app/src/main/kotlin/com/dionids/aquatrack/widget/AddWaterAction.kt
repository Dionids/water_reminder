package com.dionids.aquatrack.widget

import android.content.Context
import android.content.Intent
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import com.dionids.aquatrack.WearDataListenerService

class AddWaterAction : ActionCallback {

    companion object {
        const val GLASS_ML = 250
    }

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val prefs   = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val current = AquaWidget.readInt(prefs, "widget_current_ml", 0)
        val goal    = AquaWidget.readInt(prefs, "widget_goal_ml", 2000)
        val newVal  = (current + GLASS_ML).coerceAtMost(goal)

        // Сохраняем как Int — совместимо с Flutter SharedPreferences.setInt()
        prefs.edit()
            .putInt("flutter.widget_current_ml", newVal)
            .apply()

        // Уведомить Flutter-приложение (если открыто)
        val intent = Intent(WearDataListenerService.ACTION_WATER_FROM_WEAR).apply {
            putExtra(WearDataListenerService.EXTRA_CURRENT_ML, newVal)
            putExtra(WearDataListenerService.EXTRA_GOAL_ML, goal)
            putExtra("added_ml", GLASS_ML)
            setPackage(context.packageName)
        }
        context.sendBroadcast(intent)

        AquaWidget().update(context, glanceId)
    }
}

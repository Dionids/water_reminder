package com.example.untitled1.widget

import android.content.Context
import android.content.Intent
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import com.example.untitled1.WearDataListenerService

class AddWaterAction : ActionCallback {

    companion object {
        const val GLASS_ML = 250
    }

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val current = prefs.getFloat("flutter.widget_current_ml", 0f)
        val goal    = prefs.getFloat("flutter.widget_goal_ml", 2000f)
        val newVal  = (current + GLASS_ML).coerceAtMost(goal)

        prefs.edit()
            .putFloat("flutter.widget_current_ml", newVal)
            .apply()

        // Уведомить Flutter-приложение об изменении (если оно открыто)
        // WearSyncChannel.BroadcastReceiver поймает это и передаст в EventChannel
        val intent = Intent(WearDataListenerService.ACTION_WATER_FROM_WEAR).apply {
            putExtra(WearDataListenerService.EXTRA_CURRENT_ML, newVal.toInt())
            putExtra(WearDataListenerService.EXTRA_GOAL_ML, goal.toInt())
            putExtra("added_ml", GLASS_ML)
            setPackage(context.packageName)
        }
        context.sendBroadcast(intent)

        // Обновить виджет
        AquaWidget().update(context, glanceId)
    }
}

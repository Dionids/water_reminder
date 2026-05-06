package com.example.untitled1.widget

import android.content.Context
import android.content.SharedPreferences
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.appwidget.GlanceAppWidgetManager

class AddWaterAction : ActionCallback {

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val current = prefs.getFloat("flutter.widget_current_ml", 0f)
        val goal    = prefs.getFloat("flutter.widget_goal_ml", 2000f)
        val newVal  = (current + 200f).coerceAtMost(goal)

        prefs.edit()
            .putFloat("flutter.widget_current_ml", newVal)
            .apply()

        // Обновляем виджет сразу
        AquaWidget().update(context, glanceId)
    }
}

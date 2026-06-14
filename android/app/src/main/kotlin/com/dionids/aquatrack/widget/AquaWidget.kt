package com.dionids.aquatrack.widget

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider
import com.dionids.aquatrack.MainActivity

class AquaWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        // Flutter SharedPreferences хранит Int под ключом "flutter.<key>"
        // home_widget_service.dart записывает через SharedPreferences.setInt()
        val prefs     = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val currentMl = readInt(prefs, "widget_current_ml", 0)
        val goalMl    = readInt(prefs, "widget_goal_ml", 2000)
        val pct       = if (goalMl > 0) (currentMl * 100 / goalMl).coerceIn(0, 100) else 0
        val remaining = (goalMl - currentMl).coerceAtLeast(0)

        provideContent {
            AquaWidgetContent(currentMl = currentMl, goalMl = goalMl,
                              pct = pct, remaining = remaining)
        }
    }

    companion object {
        /**
         * Flutter SharedPreferences.setInt() сохраняет значение как Int под ключом "flutter.<key>".
         * Fallback на getFloat — на случай если ранее было сохранено как Float.
         */
        fun readInt(prefs: SharedPreferences, key: String, default: Int): Int {
            val fullKey = "flutter.$key"
            // Пробуем Int (основной формат после нашего фикса)
            if (prefs.contains(fullKey)) {
                return try {
                    prefs.getInt(fullKey, default)
                } catch (_: ClassCastException) {
                    // Fallback: сохранено как Float (старый формат)
                    try {
                        prefs.getFloat(fullKey, default.toFloat()).toInt()
                    } catch (_: ClassCastException) {
                        // Fallback: сохранено как String (home_widget default)
                        prefs.getString(fullKey, null)?.toDoubleOrNull()?.toInt() ?: default
                    }
                }
            }
            return default
        }
    }
}

@Composable
fun AquaWidgetContent(currentMl: Int, goalMl: Int, pct: Int, remaining: Int) {
    val size        = LocalSize.current
    val totalHeight = size.height.value
    val fillHeight  = (totalHeight * pct / 100f).dp.coerceAtLeast(0.dp)
    val emptyHeight = (totalHeight - fillHeight.value).dp.coerceAtLeast(0.dp)

    val bgDark     = ColorProvider(Color(0xFF05080F))
    val waterDeep  = ColorProvider(when {
        pct >= 80 -> Color(0xFF1565C0)
        pct >= 50 -> Color(0xFF0D4080)
        else      -> Color(0xFF071F45)
    })
    val waterCrest = ColorProvider(when {
        pct >= 80 -> Color(0xFF1E88E5)
        pct >= 50 -> Color(0xFF1256A8)
        else      -> Color(0xFF0D3060)
    })
    val white      = ColorProvider(Color.White)
    val subColor   = ColorProvider(Color(0xFF8AC4E8))
    val accentColor= ColorProvider(Color(0xFF5AB4F0))
    val btnBg      = ColorProvider(Color(0xFF1565C0))

    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(bgDark)
            .cornerRadius(20.dp)
            .clickable(actionStartActivity<MainActivity>()),
        contentAlignment = Alignment.Center,
    ) {
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Box(modifier = GlanceModifier.fillMaxWidth().height(emptyHeight)) {}
            if (pct in 2..99) {
                Box(modifier = GlanceModifier.fillMaxWidth().height(3.dp).background(waterCrest)) {}
            }
            Box(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .fillMaxHeight()
                    .background(waterDeep)
                    .cornerRadius(20.dp),
            ) {}
        }

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(horizontal = 10.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment   = Alignment.CenterVertically,
        ) {
            Text(
                text  = "$pct%",
                style = TextStyle(color = white, fontSize = 38.sp, fontWeight = FontWeight.Bold),
            )
            Spacer(modifier = GlanceModifier.height(2.dp))
            Text(
                text  = "$currentMl / $goalMl мл",
                style = TextStyle(color = subColor, fontSize = 11.sp),
            )
            Spacer(modifier = GlanceModifier.height(2.dp))
            Text(
                text  = if (remaining == 0) "выполнено! 🎉" else "ещё $remaining мл",
                style = TextStyle(color = accentColor, fontSize = 11.sp),
            )
            Spacer(modifier = GlanceModifier.height(10.dp))
            Box(
                modifier = GlanceModifier
                    .background(btnBg)
                    .cornerRadius(16.dp)
                    .padding(horizontal = 14.dp, vertical = 7.dp)
                    .clickable(actionRunCallback<AddWaterAction>()),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text  = "+250 мл",
                    style = TextStyle(color = white, fontSize = 12.sp, fontWeight = FontWeight.Medium),
                )
            }
        }
    }
}

class AquaWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = AquaWidget()
}

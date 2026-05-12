package com.example.untitled1.widget

import android.content.Context
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
import com.example.untitled1.MainActivity

class AquaWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs     = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val currentMl = prefs.getFloat("flutter.widget_current_ml", 0f).toInt()
        val goalMl    = prefs.getFloat("flutter.widget_goal_ml", 2000f).toInt()
        val pct       = if (goalMl > 0) (currentMl * 100 / goalMl).coerceIn(0, 100) else 0
        val remaining = (goalMl - currentMl).coerceAtLeast(0)

        provideContent {
            AquaWidgetContent(
                currentMl = currentMl,
                goalMl    = goalMl,
                pct       = pct,
                remaining = remaining,
            )
        }
    }
}

@Composable
fun AquaWidgetContent(currentMl: Int, goalMl: Int, pct: Int, remaining: Int) {
    val bgDark    = ColorProvider(Color(0xFF05080F))
    val waterFill = ColorProvider(
        when {
            pct >= 80 -> Color(0xFF1256A8)
            pct >= 50 -> Color(0xFF0D4080)
            else      -> Color(0xFF071F45)
        }
    )
    val white  = ColorProvider(Color.White)
    val sub    = ColorProvider(Color(0xFF8AC4E8))
    val accent = ColorProvider(Color(0xFF5AB4F0))
    val btnBg  = ColorProvider(Color(0xFF0A2040))

    // Имитируем заполнение водой через Column с defaultWeight:
    // верхний spacer занимает (100 - pct) частей, нижний fill — pct частей
    val topWeight  = (100 - pct).toFloat().coerceAtLeast(0.1f)
    val fillWeight = pct.toFloat().coerceAtLeast(0.1f)

    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(bgDark)
            .cornerRadius(20.dp)
            .clickable(actionStartActivity<MainActivity>()),
        contentAlignment = Alignment.Center,
    ) {
        // Слой заполнения воды (снизу вверх)
        Column(modifier = GlanceModifier.fillMaxSize()) {
            // Пустое пространство сверху
            Box(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .defaultWeight(topWeight),
            ) {}
            // Синий блок воды снизу
            Box(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .defaultWeight(fillWeight)
                    .background(waterFill)
                    .cornerRadius(20.dp),
            ) {}
        }

        // Контент поверх заполнения
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(horizontal = 10.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment   = Alignment.CenterVertically,
        ) {
            // Большой процент
            Text(
                text  = "$pct%",
                style = TextStyle(
                    color      = white,
                    fontSize   = 36.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
            Spacer(modifier = GlanceModifier.height(2.dp))

            // Выпито / норма
            Text(
                text  = "$currentMl / $goalMl мл",
                style = TextStyle(color = sub, fontSize = 11.sp),
            )
            Spacer(modifier = GlanceModifier.height(2.dp))

            // Осталось
            val remainText = if (remaining == 0) "выполнено!" else "ещё $remaining мл"
            Text(
                text  = remainText,
                style = TextStyle(color = accent, fontSize = 11.sp),
            )
            Spacer(modifier = GlanceModifier.height(10.dp))

            // Кнопка
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
                    style = TextStyle(
                        color      = accent,
                        fontSize   = 12.sp,
                        fontWeight = FontWeight.Medium,
                    ),
                )
            }
        }
    }
}

class AquaWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = AquaWidget()
}

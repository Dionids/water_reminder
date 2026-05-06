package com.example.untitled1.widget

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
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider
import com.example.untitled1.MainActivity

class AquaWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val currentMl = prefs.getFloat("flutter.widget_current_ml", 0f).toInt()
        val goalMl    = prefs.getFloat("flutter.widget_goal_ml", 2000f).toInt()
        val pct       = if (goalMl > 0) (currentMl * 100 / goalMl).coerceIn(0, 100) else 0

        provideContent {
            AquaWidgetContent(currentMl = currentMl, goalMl = goalMl, pct = pct)
        }
    }
}

@Composable
fun AquaWidgetContent(currentMl: Int, goalMl: Int, pct: Int) {
    val bgDark   = ColorProvider(Color(0xFF05080F))
    val blue     = ColorProvider(Color(0xFF3B8BD4))
    val blueDim  = ColorProvider(Color(0xFF1A2840))
    val white    = ColorProvider(Color.White)
    val subColor = ColorProvider(Color(0xFF8AC4E8))
    val btnColor = ColorProvider(Color(0xFF0A2040))

    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(bgDark)
            .cornerRadius(24.dp)
            .clickable(actionStartActivity<MainActivity>()),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = GlanceModifier.fillMaxSize().padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Процент
            Text(
                text = "$pct%",
                style = TextStyle(
                    color = white,
                    fontSize = 36.sp,
                    fontWeight = FontWeight.Bold
                )
            )

            Spacer(modifier = GlanceModifier.height(4.dp))

            // мл / норма
            Text(
                text = "$currentMl / $goalMl мл",
                style = TextStyle(color = subColor, fontSize = 13.sp)
            )

            Spacer(modifier = GlanceModifier.height(12.dp))

            // Прогресс-бар
            Box(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .background(blueDim)
                    .cornerRadius(3.dp)
            ) {
                Box(
                    modifier = GlanceModifier
                        .fillMaxHeight()
                        .background(blue)
                        .cornerRadius(3.dp)
                ) {}
            }

            Spacer(modifier = GlanceModifier.height(14.dp))

            // Кнопка + стакан
            Box(
                modifier = GlanceModifier
                    .background(btnColor)
                    .cornerRadius(20.dp)
                    .padding(horizontal = 20.dp, vertical = 8.dp)
                    .clickable(actionRunCallback<AddWaterAction>()),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "+ стакан",
                    style = TextStyle(
                        color = ColorProvider(Color(0xFF5AB4F0)),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium
                    )
                )
            }
        }
    }
}

class AquaWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = AquaWidget()
}

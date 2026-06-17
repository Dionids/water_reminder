package com.dionids.aquatrack.wear

import android.content.Context
import androidx.wear.protolayout.*
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.DimensionBuilders.*
import androidx.wear.protolayout.LayoutElementBuilders.*
import androidx.wear.protolayout.ModifiersBuilders.*
import androidx.wear.protolayout.ResourceBuilders.*
import androidx.wear.protolayout.TimelineBuilders.*
import androidx.wear.tiles.RequestBuilders.*
import androidx.wear.tiles.TileBuilders.Tile
import com.google.android.horologist.annotations.ExperimentalHorologistApi
import com.google.android.horologist.tiles.SuspendingTileService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Wear OS Tile — компактная карточка, доступная свайпом влево от циферблата.
 * Кнопка +250 мл запускает MainActivity с action=add_water, который сразу добавляет стакан.
 */
@OptIn(ExperimentalHorologistApi::class)
class AquaTileService : SuspendingTileService() {

    companion object {
        fun requestUpdate(context: Context) {
            getUpdater(context).requestUpdate(AquaTileService::class.java)
        }
    }

    override suspend fun resourcesRequest(requestParams: ResourcesRequest): Resources =
        Resources.Builder().setVersion("1").build()

    override suspend fun tileRequest(requestParams: TileRequest): Tile =
        withContext(Dispatchers.IO) {
            val pct     = WaterDataStore.getPercent(this@AquaTileService)
            val current = WaterDataStore.getCurrentMl(this@AquaTileService)
            val goal    = WaterDataStore.getGoalMl(this@AquaTileService)
            buildTile(pct, current, goal)
        }

    private fun buildTile(pct: Int, currentMl: Int, goalMl: Int): Tile {
        val remainMl = (goalMl - currentMl).coerceAtLeast(0)

        val layout = Layout.Builder()
            .setRoot(buildRoot(pct, currentMl, goalMl, remainMl))
            .build()

        return Tile.Builder()
            .setResourcesVersion("1")
            .setTileTimeline(
                Timeline.Builder()
                    .addTimelineEntry(
                        TimelineEntry.Builder().setLayout(layout).build()
                    ).build()
            ).build()
    }

    private fun buildRoot(
        pct: Int, currentMl: Int, goalMl: Int, remainMl: Int
    ): LayoutElement {
        val waterColor   = argb(0xFF3B8BD4.toInt())
        val dimColor     = argb(0xFF1A2840.toInt())
        val white        = argb(0xFFFFFFFF.toInt())
        val subColor     = argb(0xFF8AC4E8.toInt())
        val btnColor     = argb(0xFF1565C0.toInt())
        val btnTextColor = argb(0xFFFFFFFF.toInt())

        // Кнопка +250 мл: открывает MainActivity с action=add_water
        val addWaterClickable = Clickable.Builder()
            .setOnClick(
                ActionBuilders.LaunchAction.Builder()
                    .setAndroidActivity(
                        ActionBuilders.AndroidActivity.Builder()
                            .setPackageName(packageName)
                            .setClassName("$packageName.MainActivity")
                            .addKeyToExtraMapping(
                                "action",
                                ActionBuilders.AndroidStringExtra.Builder()
                                    .setValue(MainActivity.ACTION_ADD_WATER)
                                    .build()
                            )
                            .build()
                    ).build()
            ).build()

        return Box.Builder()
            .setWidth(expand())
            .setHeight(expand())
            .setVerticalAlignment(VERTICAL_ALIGN_CENTER)
            .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
            .addContent(
                Column.Builder()
                    .setHorizontalAlignment(HORIZONTAL_ALIGN_CENTER)
                    .setWidth(expand())
                    .addContent(
                        // Процент
                        Text.Builder()
                            .setText("$pct%")
                            .setFontStyle(
                                FontStyle.Builder()
                                    .setSize(sp(40f))
                                    .setWeight(FONT_WEIGHT_BOLD)
                                    .setColor(white)
                                    .build()
                            ).build()
                    )
                    .addContent(
                        // мл из мл
                        Text.Builder()
                            .setText("${fmt(currentMl)} / ${fmt(goalMl)} мл")
                            .setFontStyle(
                                FontStyle.Builder()
                                    .setSize(sp(14f))
                                    .setColor(subColor)
                                    .build()
                            ).build()
                    )
                    .addContent(spacer(8))
                    .addContent(
                        // Прогресс-бар
                        Box.Builder()
                            .setWidth(dp(150f))
                            .setHeight(dp(6f))
                            .setModifiers(
                                Modifiers.Builder()
                                    .setBackground(
                                        Background.Builder()
                                            .setColor(dimColor)
                                            .setCorner(Corner.Builder().setRadius(dp(3f)).build())
                                            .build()
                                    ).build()
                            )
                            .addContent(
                                Box.Builder()
                                    .setWidth(dp((150f * pct / 100f).coerceAtLeast(0f)))
                                    .setHeight(dp(6f))
                                    .setHorizontalAlignment(HORIZONTAL_ALIGN_START)
                                    .setModifiers(
                                        Modifiers.Builder()
                                            .setBackground(
                                                Background.Builder()
                                                    .setColor(waterColor)
                                                    .setCorner(Corner.Builder().setRadius(dp(3f)).build())
                                                    .build()
                                            ).build()
                                    ).build()
                            ).build()
                    )
                    .addContent(spacer(6))
                    .addContent(
                        // Осталось
                        Text.Builder()
                            .setText(if (remainMl == 0) "норма выполнена!" else "осталось ${fmt(remainMl)} мл")
                            .setFontStyle(
                                FontStyle.Builder()
                                    .setSize(sp(11f))
                                    .setColor(argb(0xFF4A7AAA.toInt()))
                                    .build()
                            ).build()
                    )
                    .addContent(spacer(10))
                    .addContent(
                        // Кнопка +250 мл — реально добавляет воду
                        Text.Builder()
                            .setText("+250 мл")
                            .setFontStyle(
                                FontStyle.Builder()
                                    .setSize(sp(13f))
                                    .setColor(btnTextColor)
                                    .build()
                            )
                            .setModifiers(
                                Modifiers.Builder()
                                    .setBackground(
                                        Background.Builder()
                                            .setColor(btnColor)
                                            .setCorner(Corner.Builder().setRadius(dp(20f)).build())
                                            .build()
                                    )
                                    .setPadding(
                                        Padding.Builder()
                                            .setTop(dp(8f)).setBottom(dp(8f))
                                            .setStart(dp(20f)).setEnd(dp(20f))
                                            .build()
                                    )
                                    .setClickable(addWaterClickable)
                                    .build()
                            ).build()
                    ).build()
            ).build()
    }

    private fun spacer(dp: Int) = Spacer.Builder().setHeight(dp(dp.toFloat())).build()

    private fun fmt(ml: Int): String = ml.toString()
}

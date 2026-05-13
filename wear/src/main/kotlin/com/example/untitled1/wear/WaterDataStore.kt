package com.example.untitled1.wear

import android.content.Context
import android.content.SharedPreferences

/**
 * Простое хранилище данных о воде на часах.
 * Данные пишет DataListenerService (с телефона) и MainActivity (кнопка +).
 */
object WaterDataStore {

    private const val PREFS_NAME    = "aquatrack_wear"
    const val PREFS_NAME_CONST    = "aquatrack_wear"  // public для MainActivity
    private const val KEY_CURRENT_ML = "current_ml"
    private const val KEY_GOAL_ML    = "goal_ml"
    private const val KEY_LAST_SYNC  = "last_sync"

    const val GLASS_ML = 250   // стакан 250 мл

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getCurrentMl(context: Context): Int =
        prefs(context).getInt(KEY_CURRENT_ML, 0)

    fun getGoalMl(context: Context): Int =
        prefs(context).getInt(KEY_GOAL_ML, 2000)

    fun getLastSync(context: Context): Long =
        prefs(context).getLong(KEY_LAST_SYNC, 0L)

    fun saveWaterData(context: Context, currentMl: Int, goalMl: Int) {
        prefs(context).edit()
            .putInt(KEY_CURRENT_ML, currentMl)
            .putInt(KEY_GOAL_ML, goalMl)
            .putLong(KEY_LAST_SYNC, System.currentTimeMillis())
            .apply()
    }

    /** Добавить стакан воды локально на часах и вернуть новое значение */
    fun addGlass(context: Context, glassML: Int = GLASS_ML): Int {
        val current = getCurrentMl(context)
        val goal    = getGoalMl(context)
        val newVal  = (current + glassML).coerceAtMost(goal)
        saveWaterData(context, newVal, goal)
        return newVal
    }

    fun getPercent(context: Context): Int {
        val goal = getGoalMl(context)
        if (goal == 0) return 0
        return (getCurrentMl(context) * 100 / goal).coerceIn(0, 100)
    }
}

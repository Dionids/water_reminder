package com.example.untitled1

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Регистрирует MethodChannel и EventChannel для связи Flutter ↔ Wear OS.
 *
 * Вызывать из MainActivity.configureFlutterEngine():
 *   WearSyncChannel.register(context, flutterEngine)
 */
object WearSyncChannel {

    private const val METHOD_CHANNEL = "com.example.untitled1/wear_sync"
    private const val EVENT_CHANNEL  = "com.example.untitled1/wear_events"
    private const val TAG = "WearSyncChannel"

    private var eventSink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null

    fun register(context: Context, flutterEngine: FlutterEngine) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // MethodChannel: Flutter → Wear (отправить данные на часы)
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncToWatch" -> {
                    val currentMl = call.argument<Int>("current_ml") ?: 0
                    val goalMl    = call.argument<Int>("goal_ml") ?: 2000
                    val timestamp = call.argument<Long>("timestamp") ?: 0L
                    sendDataToWatch(context, currentMl, goalMl, timestamp)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // EventChannel: Wear → Flutter (нажатие + на часах)
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
                registerBroadcastReceiver(context)
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                unregisterReceiver(context)
            }
        })
    }

    private fun sendDataToWatch(context: Context, currentMl: Int, goalMl: Int, timestamp: Long) {
        val request = PutDataMapRequest.create("/aquatrack/sync").apply {
            dataMap.putInt("current_ml", currentMl)
            dataMap.putInt("goal_ml", goalMl)
            dataMap.putLong("timestamp", timestamp)
        }.asPutDataRequest().setUrgent()

        Wearable.getDataClient(context)
            .putDataItem(request)
            .addOnSuccessListener { Log.d(TAG, "Data sent to watch: $currentMl/$goalMl ml") }
            .addOnFailureListener { Log.w(TAG, "Watch not connected: ${it.message}") }
    }

    private fun registerBroadcastReceiver(context: Context) {
        receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent?.action == WearDataListenerService.ACTION_WATER_FROM_WEAR) {
                    val addedMl = 200 // всегда стакан 200мл с часов
                    eventSink?.success(mapOf("added_ml" to addedMl))
                }
            }
        }
        val filter = IntentFilter(WearDataListenerService.ACTION_WATER_FROM_WEAR)
        context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
    }

    private fun unregisterReceiver(context: Context) {
        receiver?.let {
            try { context.unregisterReceiver(it) } catch (_: Exception) {}
        }
        receiver = null
    }
}

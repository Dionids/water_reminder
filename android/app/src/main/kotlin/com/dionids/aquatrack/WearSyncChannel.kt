package com.dionids.aquatrack

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

object WearSyncChannel {

    private const val METHOD_CHANNEL = "com.dionids.aquatrack/wear_sync"
    private const val EVENT_CHANNEL  = "com.dionids.aquatrack/wear_events"
    private const val TAG = "WearSyncChannel"

    private var eventSink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null
    private var messageListener: MessageClient.OnMessageReceivedListener? = null

    fun register(context: Context, flutterEngine: FlutterEngine) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncToWatch" -> {
                    val currentMl = call.argument<Int>("current_ml") ?: 0
                    val goalMl    = call.argument<Int>("goal_ml") ?: 2000
                    val timestamp = call.argument<Long>("timestamp") ?: 0L
                    sendDataToWatch(context, currentMl, goalMl, timestamp)
                    result.success(null)
                }
                "scheduleWatchReminder" -> {
                    val scheduledAt  = call.argument<Long>("scheduled_at") ?: 0L
                    val glassIndex   = call.argument<Int>("glass_index") ?: 1
                    val totalGlasses = call.argument<Int>("total_glasses") ?: 1
                    scheduleReminderOnWatch(context, scheduledAt, glassIndex, totalGlasses)
                    result.success(null)
                }
                "pullFromWatch" -> {
                    // Запрашиваем актуальные данные с часов через MessageClient
                    requestDataFromWatch(context, result)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
                registerBroadcastReceiver(context)
                registerMessageListener(context)
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
                unregisterReceiver(context)
                unregisterMessageListener(context)
            }
        })
    }

    private fun requestDataFromWatch(context: Context, result: MethodChannel.Result) {
        val messageClient = Wearable.getMessageClient(context)
        val nodeClient    = Wearable.getNodeClient(context)
        var replied = false

        // Временный слушатель ответа от часов
        val listener = object : MessageClient.OnMessageReceivedListener {
            override fun onMessageReceived(event: MessageEvent) {
                if (event.path == "/aquatrack/data_response" && !replied) {
                    replied = true
                    val parts = String(event.data).split(",")
                    val currentMl = parts.getOrNull(0)?.toIntOrNull() ?: 0
                    val goalMl    = parts.getOrNull(1)?.toIntOrNull() ?: 2000
                    Log.d(TAG, "Watch data response: $currentMl/$goalMl")
                    messageClient.removeListener(this)
                    result.success(mapOf("current_ml" to currentMl, "goal_ml" to goalMl))
                }
            }
        }
        messageClient.addListener(listener)

        nodeClient.connectedNodes.addOnSuccessListener { nodes ->
            if (nodes.isEmpty()) {
                Log.w(TAG, "pullFromWatch: no connected nodes")
                messageClient.removeListener(listener)
                if (!replied) { replied = true; result.success(null) }
                return@addOnSuccessListener
            }
            for (node in nodes) {
                messageClient.sendMessage(node.id, "/aquatrack/request_data", ByteArray(0))
                    .addOnSuccessListener { Log.d(TAG, "Request sent to ${node.displayName}") }
                    .addOnFailureListener { Log.w(TAG, "Request failed: ${it.message}") }
            }
            // Таймаут 3 секунды на ответ
            android.os.Handler(context.mainLooper).postDelayed({
                if (!replied) {
                    replied = true
                    messageClient.removeListener(listener)
                    Log.w(TAG, "pullFromWatch: timeout")
                    result.success(null)
                }
            }, 3000)
        }.addOnFailureListener {
            messageClient.removeListener(listener)
            if (!replied) { replied = true; result.success(null) }
        }
    }

    private fun sendDataToWatch(context: Context, currentMl: Int, goalMl: Int, timestamp: Long) {
        // Получаем firebase_uid из SharedPreferences Flutter
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val uid = prefs.getString("flutter.firebase_uid", null)

        val request = PutDataMapRequest.create("/aquatrack/sync").apply {
            dataMap.putInt("current_ml", currentMl)
            dataMap.putInt("goal_ml", goalMl)
            dataMap.putLong("timestamp", timestamp)
            if (uid != null) dataMap.putString("firebase_uid", uid)
        }.asPutDataRequest().setUrgent()

        Wearable.getDataClient(context)
            .putDataItem(request)
            .addOnSuccessListener { Log.d(TAG, "Data sent to watch: $currentMl/$goalMl ml, uid=$uid") }
            .addOnFailureListener { Log.w(TAG, "Watch not connected: ${it.message}") }
    }

    private fun scheduleReminderOnWatch(
        context: Context,
        scheduledAt: Long,
        glassIndex: Int,
        totalGlasses: Int,
    ) {
        val request = PutDataMapRequest.create("/aquatrack/reminder/$glassIndex").apply {
            dataMap.putLong("scheduled_at",  scheduledAt)
            dataMap.putInt("glass_index",    glassIndex)
            dataMap.putInt("total_glasses",  totalGlasses)
            dataMap.putLong("created_at", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        Wearable.getDataClient(context)
            .putDataItem(request)
            .addOnSuccessListener { Log.d(TAG, "Reminder $glassIndex/$totalGlasses scheduled on watch") }
            .addOnFailureListener { Log.w(TAG, "Watch not connected for reminder: ${it.message}") }
    }

    private fun registerBroadcastReceiver(context: Context) {
        receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent?.action == WearDataListenerService.ACTION_WATER_FROM_WEAR) {
                    // Читаем добавленный объём из intent (от часов или виджета)
                    val addedMl = intent.getIntExtra("added_ml", 250)
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

    private fun registerMessageListener(context: Context) {
        messageListener = MessageClient.OnMessageReceivedListener { event: MessageEvent ->
            if (event.path == "/aquatrack/add_water") {
                val parts    = String(event.data).split(",")
                val addedMl  = parts.getOrNull(2)?.toIntOrNull() ?: 250
                Log.d(TAG, "MessageClient received from watch: +$addedMl ml")
                eventSink?.success(mapOf("added_ml" to addedMl))
            }
        }
        Wearable.getMessageClient(context).addListener(messageListener!!)
        Log.d(TAG, "MessageClient listener registered")
    }

    private fun unregisterMessageListener(context: Context) {
        messageListener?.let {
            Wearable.getMessageClient(context).removeListener(it)
        }
        messageListener = null
    }
}

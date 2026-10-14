package com.financeapp.finance_manager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import org.json.JSONArray
import org.json.JSONObject

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION &&
            intent.action != "android.provider.Telephony.SMS_RECEIVED") {
            return
        }

        val bundle = intent.extras ?: return
        val pdus = bundle.get("pdus") as? Array<*> ?: return
        val format = bundle.getString("format")

        val messagesBySender = mutableMapOf<String, StringBuilder>()
        var timestamp = System.currentTimeMillis()

        for (pdu in pdus) {
            val bytes = pdu as? ByteArray ?: continue
            val sms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                SmsMessage.createFromPdu(bytes, format)
            } else {
                @Suppress("DEPRECATION")
                SmsMessage.createFromPdu(bytes)
            } ?: continue

            val sender = sms.displayOriginatingAddress ?: "UNKNOWN"
            val body = sms.displayMessageBody ?: ""
            timestamp = sms.timestampMillis

            if (!messagesBySender.containsKey(sender)) {
                messagesBySender[sender] = StringBuilder()
            }
            messagesBySender[sender]?.append(body)
        }

        for ((sender, bodyBuilder) in messagesBySender) {
            val body = bodyBuilder.toString()
            if (body.isBlank()) continue

            // 1. If Flutter engine is alive and channel is active, deliver to Flutter immediately
            val channel = MainActivity.smsChannel
            if (channel != null) {
                MainActivity.mainHandler.post {
                    channel.invokeMethod("onSmsReceived", mapOf(
                        "sender" to sender,
                        "body" to body,
                        "timestamp" to timestamp
                    ))
                }
            } else {
                // 2. Queue in SharedPreferences so it is processed when app opens
                queueSms(context, sender, body, timestamp)
            }
        }
    }

    private fun queueSms(context: Context, sender: String, body: String, timestamp: Long) {
        val prefs = context.getSharedPreferences("offline_sms_queue", Context.MODE_PRIVATE)
        val existingJson = prefs.getString("queued_messages", "[]") ?: "[]"
        val array = JSONArray(existingJson)
        val obj = JSONObject()
        obj.put("sender", sender)
        obj.put("body", body)
        obj.put("timestamp", timestamp)
        array.put(obj)
        prefs.edit().putString("queued_messages", array.toString()).apply()
    }
}

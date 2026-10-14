package com.financeapp.finance_manager

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.util.ArrayList

class MainActivity : FlutterFragmentActivity() {

    companion object {
        const val CHANNEL_NAME = "com.financeapp.finance_manager/sms"
        const val SMS_PERMISSION_REQ_CODE = 1001
        var smsChannel: MethodChannel? = null
        val mainHandler = Handler(Looper.getMainLooper())
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Prevent screenshots, screen recording, and obscure app switcher snapshot
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        smsChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSmsPermission" -> {
                    val hasReceive = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                    val hasRead = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    result.success(hasReceive && hasRead)
                }

                "requestSmsPermission" -> {
                    val hasReceive = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                    val hasRead = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    if (hasReceive && hasRead) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS),
                            SMS_PERMISSION_REQ_CODE
                        )
                    }
                }

                "getQueuedSms" -> {
                    val prefs = getSharedPreferences("offline_sms_queue", Context.MODE_PRIVATE)
                    val queuedJson = prefs.getString("queued_messages", "[]") ?: "[]"
                    prefs.edit().remove("queued_messages").apply()

                    val list = ArrayList<Map<String, Any>>()
                    try {
                        val array = JSONArray(queuedJson)
                        for (i in 0 until array.length()) {
                            val obj = array.getJSONObject(i)
                            list.add(mapOf(
                                "sender" to obj.optString("sender", ""),
                                "body" to obj.optString("body", ""),
                                "timestamp" to obj.optLong("timestamp", System.currentTimeMillis())
                            ))
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(list)
                }

                "fetchRecentInboxSms" -> {
                    val limit = (call.argument<Int>("limit") ?: 50).coerceAtMost(200)
                    val daysBack = call.argument<Int>("daysBack") ?: 7
                    val list = fetchInboxMessages(limit, daysBack)
                    result.success(list)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQ_CODE) {
            val isGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(isGranted)
            pendingPermissionResult = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        smsChannel = null
    }

    private fun fetchInboxMessages(limit: Int, daysBack: Int): List<Map<String, Any>> {
        val messages = ArrayList<Map<String, Any>>()
        val hasRead = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
        if (!hasRead) return messages

        val uri = Uri.parse("content://sms/inbox")
        val cutoffTime = System.currentTimeMillis() - (daysBack.toLong() * 24 * 60 * 60 * 1000)

        val projection = arrayOf("_id", "address", "body", "date")
        val selection = "date >= ?"
        val selectionArgs = arrayOf(cutoffTime.toString())
        val sortOrder = "date DESC LIMIT $limit"

        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)
            if (cursor != null && cursor.moveToFirst()) {
                val addressIdx = cursor.getColumnIndex("address")
                val bodyIdx = cursor.getColumnIndex("body")
                val dateIdx = cursor.getColumnIndex("date")

                do {
                    val address = if (addressIdx != -1) cursor.getString(addressIdx) ?: "" else ""
                    val body = if (bodyIdx != -1) cursor.getString(bodyIdx) ?: "" else ""
                    val date = if (dateIdx != -1) cursor.getLong(dateIdx) else System.currentTimeMillis()

                    if (body.isNotBlank()) {
                        messages.add(mapOf(
                            "sender" to address,
                            "body" to body,
                            "timestamp" to date
                        ))
                    }
                } while (cursor.moveToNext())
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            cursor?.close()
        }

        return messages
    }
}

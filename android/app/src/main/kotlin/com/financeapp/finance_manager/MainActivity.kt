package com.financeapp.finance_manager

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Prevent screenshots, screen recording, and obscure app switcher snapshot
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}

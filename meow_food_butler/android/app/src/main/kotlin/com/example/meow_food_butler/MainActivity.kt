package com.example.meow_food_butler

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private var sharedText: String? = null
  private var methodChannel: MethodChannel? = null

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    handleSharedIntent(intent)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "meow_food_butler/shared_text")
    methodChannel?.setMethodCallHandler { call, result ->
      when (call.method) {
        "getSharedText" -> result.success(sharedText)
        else -> result.notImplemented()
      }
    }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    handleSharedIntent(intent)
  }

  private fun handleSharedIntent(intent: Intent) {
    if (intent.action == Intent.ACTION_SEND && intent.type == "text/plain") {
      val text = intent.getStringExtra(Intent.EXTRA_TEXT)
      if (!text.isNullOrBlank()) {
        sharedText = text
        methodChannel?.invokeMethod("sharedText", text)
      }
    }
  }
}


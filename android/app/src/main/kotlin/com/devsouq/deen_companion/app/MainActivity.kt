package com.devsouq.deen_companion.app

import android.content.Intent
import com.devsouq.deen_companion.app.alarm.AlarmMethodChannelHandler
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AlarmMethodChannelHandler.configure(flutterEngine, this)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (AlarmMethodChannelHandler.handleActivityResult(requestCode, resultCode, data)) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        AlarmMethodChannelHandler.detach()
        super.onDestroy()
    }
}
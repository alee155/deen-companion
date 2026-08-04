package com.devsouq.deen_companion.app.qibla

import android.hardware.GeomagneticField
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges one thing Dart genuinely cannot compute itself: the local magnetic declination (the angle
 * between magnetic north and true north at a given point on Earth). Android ships this as
 * [GeomagneticField], built from the NOAA World Magnetic Model and kept current by the OS — there's
 * no reason to vendor a second copy of that model into the app.
 *
 * This is the only reason any native code exists for Qibla at all. Everything else (reading the
 * compass sensor, smoothing, the UI) stays in Dart via flutter_compass, which already talks to the
 * platform sensor APIs directly — there was never a reason to move that part natively too.
 */
object QiblaMethodChannelHandler {
    private const val METHOD_CHANNEL = "com.devsouq.deen_companion.app/qibla"

    fun configure(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
                .setMethodCallHandler { call, result -> handleMethod(call, result) }
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getMagneticDeclination" -> getMagneticDeclination(call, result)
            else -> result.notImplemented()
        }
    }

    private fun getMagneticDeclination(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val latitude = (args?.get("latitude") as? Number)?.toFloat()
        val longitude = (args?.get("longitude") as? Number)?.toFloat()

        if (latitude == null || longitude == null) {
            result.error("BAD_ARGS", "Expected latitude and longitude", null)
            return
        }

        try {
            // Altitude is deliberately 0: declination changes by a small
            // fraction of a degree per km of altitude, utterly negligible
            // next to the multi-degree corrections this is meant to fix.
            val field = GeomagneticField(latitude, longitude, 0f, System.currentTimeMillis())
            result.success(field.declination.toDouble())
        } catch (e: Exception) {
            result.error("DECLINATION_FAILED", e.message, null)
        }
    }
}

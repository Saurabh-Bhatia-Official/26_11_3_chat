package com.chatgen.frontend

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.chatgen.whisper/launcher"

    private val aliasMap = mapOf(
        "whisper" to "com.chatgen.frontend.MainActivityDefault",
        "cyber_pulse" to "com.chatgen.frontend.MainActivityCyberPulse",
        "cyber_shield" to "com.chatgen.frontend.MainActivityCyberShield",
        "cosmic_night" to "com.chatgen.frontend.MainActivityCosmicNight",
        "solar_flare" to "com.chatgen.frontend.MainActivitySolarFlare"
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "changeLauncherIcon" -> {
                    val iconKey = call.argument<String>("icon") ?: "whisper"
                    val success = switchLauncherIcon(iconKey)
                    result.success(success)
                }
                "getCurrentLauncherIcon" -> {
                    result.success(getEnabledLauncherIcon())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun switchLauncherIcon(targetKey: String): Boolean {
        return try {
            val pm = packageManager
            val targetAlias = aliasMap[targetKey] ?: aliasMap["whisper"]!!

            // Enable target first to ensure app launcher is never lost
            pm.setComponentEnabledSetting(
                ComponentName(this, targetAlias),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )

            // Disable all other aliases
            for ((key, alias) in aliasMap) {
                if (alias != targetAlias) {
                    pm.setComponentEnabledSetting(
                        ComponentName(this, alias),
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                }
            }
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun getEnabledLauncherIcon(): String {
        try {
            val pm = packageManager
            for ((key, alias) in aliasMap) {
                val state = pm.getComponentEnabledSetting(ComponentName(this, alias))
                if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                    return key
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return "whisper"
    }
}

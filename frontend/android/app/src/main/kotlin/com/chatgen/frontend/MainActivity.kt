package com.chatgen.frontend

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.chatgen.whisper/launcher"
    private val defaultAlias = "com.chatgen.frontend.MainActivityDefault"

    // Maps (iconKey, nameKey) to fully qualified alias class names
    private val aliasMap = mapOf(
        // 1. Whisper Icon
        Pair("whisper", "whisper") to "com.chatgen.frontend.MainActivityDefault",
        Pair("whisper", "cyber_pulse") to "com.chatgen.frontend.MainActivity_whisper_cyber_pulse",
        Pair("whisper", "cyber_shield") to "com.chatgen.frontend.MainActivity_whisper_cyber_shield",
        Pair("whisper", "cosmic_night") to "com.chatgen.frontend.MainActivity_whisper_cosmic_night",
        Pair("whisper", "solar_flare") to "com.chatgen.frontend.MainActivity_whisper_solar_flare",

        // 2. Cyber Pulse Icon
        Pair("cyber_pulse", "cyber_pulse") to "com.chatgen.frontend.MainActivityCyberPulse",
        Pair("cyber_pulse", "whisper") to "com.chatgen.frontend.MainActivity_cyber_pulse_whisper",
        Pair("cyber_pulse", "cyber_shield") to "com.chatgen.frontend.MainActivity_cyber_pulse_cyber_shield",
        Pair("cyber_pulse", "cosmic_night") to "com.chatgen.frontend.MainActivity_cyber_pulse_cosmic_night",
        Pair("cyber_pulse", "solar_flare") to "com.chatgen.frontend.MainActivity_cyber_pulse_solar_flare",

        // 3. Cyber Shield Icon
        Pair("cyber_shield", "cyber_shield") to "com.chatgen.frontend.MainActivityCyberShield",
        Pair("cyber_shield", "whisper") to "com.chatgen.frontend.MainActivity_cyber_shield_whisper",
        Pair("cyber_shield", "cyber_pulse") to "com.chatgen.frontend.MainActivity_cyber_shield_cyber_pulse",
        Pair("cyber_shield", "cosmic_night") to "com.chatgen.frontend.MainActivity_cyber_shield_cosmic_night",
        Pair("cyber_shield", "solar_flare") to "com.chatgen.frontend.MainActivity_cyber_shield_solar_flare",

        // 4. Cosmic Night Icon
        Pair("cosmic_night", "cosmic_night") to "com.chatgen.frontend.MainActivityCosmicNight",
        Pair("cosmic_night", "whisper") to "com.chatgen.frontend.MainActivity_cosmic_night_whisper",
        Pair("cosmic_night", "cyber_pulse") to "com.chatgen.frontend.MainActivity_cosmic_night_cyber_pulse",
        Pair("cosmic_night", "cyber_shield") to "com.chatgen.frontend.MainActivity_cosmic_night_cyber_shield",
        Pair("cosmic_night", "solar_flare") to "com.chatgen.frontend.MainActivity_cosmic_night_solar_flare",

        // 5. Solar Flare Icon
        Pair("solar_flare", "solar_flare") to "com.chatgen.frontend.MainActivitySolarFlare",
        Pair("solar_flare", "whisper") to "com.chatgen.frontend.MainActivity_solar_flare_whisper",
        Pair("solar_flare", "cyber_pulse") to "com.chatgen.frontend.MainActivity_solar_flare_cyber_pulse",
        Pair("solar_flare", "cyber_shield") to "com.chatgen.frontend.MainActivity_solar_flare_cyber_shield",
        Pair("solar_flare", "cosmic_night") to "com.chatgen.frontend.MainActivity_solar_flare_cosmic_night"
    )

    private val allAliases = aliasMap.values.toSet()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "changeLauncherBranding", "changeLauncherIcon" -> {
                    val iconKey = call.argument<String>("icon") ?: "whisper"
                    val title = call.argument<String>("title") ?: ""
                    val success = switchLauncherBranding(iconKey, title)
                    result.success(success)
                }
                "getCurrentLauncherBranding" -> {
                    result.success(getEnabledLauncherBranding())
                }
                "getCurrentLauncherIcon" -> {
                    val current = getEnabledLauncherBranding()
                    result.success(current["icon"] ?: "whisper")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun normalizeKey(raw: String): String {
        val clean = raw.trim().lowercase().replace(Regex("[\\s_-]+"), "")
        return when (clean) {
            "whisper", "whisperblueribbon" -> "whisper"
            "cyberpulse" -> "cyber_pulse"
            "cybershield" -> "cyber_shield"
            "cosmicnight" -> "cosmic_night"
            "solarflare" -> "solar_flare"
            else -> ""
        }
    }

    private fun switchLauncherBranding(rawIcon: String, rawTitle: String): Boolean {
        return try {
            val pm = packageManager

            var iconKey = normalizeKey(rawIcon)
            if (iconKey.isEmpty()) {
                iconKey = "whisper"
            }

            var nameKey = normalizeKey(rawTitle)
            if (nameKey.isEmpty()) {
                // If title was empty or an arbitrary string, default to matching icon or whisper
                nameKey = if (aliasMap.containsKey(Pair(iconKey, iconKey))) iconKey else "whisper"
            }

            val targetAlias = aliasMap[Pair(iconKey, nameKey)]
                ?: aliasMap[Pair(iconKey, "whisper")]
                ?: defaultAlias

            // 1. Enable target alias FIRST so at least one valid launcher entry is always active
            pm.setComponentEnabledSetting(
                ComponentName(this, targetAlias),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )

            // 2. Disable all other aliases safely
            for (alias in allAliases) {
                if (alias != targetAlias) {
                    val currentState = pm.getComponentEnabledSetting(ComponentName(this, alias))
                    if (currentState != PackageManager.COMPONENT_ENABLED_STATE_DISABLED) {
                        pm.setComponentEnabledSetting(
                            ComponentName(this, alias),
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP
                        )
                    }
                }
            }

            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun getEnabledLauncherBranding(): Map<String, String> {
        try {
            val pm = packageManager
            for ((pair, alias) in aliasMap) {
                val state = pm.getComponentEnabledSetting(ComponentName(this, alias))
                if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                    return mapOf(
                        "icon" to pair.first,
                        "name" to pair.second,
                        "alias" to alias
                    )
                }
            }
            // By default before any switch, MainActivityDefault is enabled
            return mapOf(
                "icon" to "whisper",
                "name" to "whisper",
                "alias" to defaultAlias
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return mapOf(
            "icon" to "whisper",
            "name" to "whisper",
            "alias" to defaultAlias
        )
    }
}

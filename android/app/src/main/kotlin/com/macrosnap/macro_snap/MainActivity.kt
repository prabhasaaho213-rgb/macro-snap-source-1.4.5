package com.macrosnap.macro_snap

import android.os.Bundle
import androidx.activity.EdgeToEdge
import io.flutter.embedding.android.FlutterActivity

/**
 * Main entry point for MacroSnap.
 *
 * Uses [EdgeToEdge.enable] (AndroidX Activity 1.9+) for forward-compatible
 * edge-to-edge support on Android 15 (SDK 35) and Android 16 (SDK 36).
 *
 * This replaces the deprecated [androidx.core.view.WindowCompat]
 * `setDecorFitsSystemWindows(window, false)` call. Flutter's own
 * rendering pipeline already draws under the system bars, and
 * [Scaffold] / [SafeArea] handle insets — so no additional
 * layout changes are needed.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Enable edge-to-edge display for Android 15+ (SDK 35+).
        // On Android 16 this becomes mandatory — calling it here ensures
        // identical behavior across all supported API levels.
        EdgeToEdge.enable(this)
        super.onCreate(savedInstanceState)
    }
}

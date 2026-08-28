package com.macrosnap.macro_snap

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

/**
 * Main entry point for MacroSnap.
 *
 * Uses [WindowCompat.setDecorFitsSystemWindows] to enable edge-to-edge
 * rendering on Android 15 (SDK 35) and Android 16 (SDK 36).
 *
 * The newer [androidx.activity.EdgeToEdge] API requires AndroidX Activity
 * 1.9+, which isn't bundled with Flutter 3.47. This deprecated call
 * achieves the same result and is confirmed working across all API levels.
 * Flutter's rendering pipeline draws under the system bars, and
 * [Scaffold] / [SafeArea] handle insets — so no layout changes needed.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Draw under system bars on Android 15+ (SDK 35+).
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }
}

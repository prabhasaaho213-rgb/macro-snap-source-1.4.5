package com.macrosnap.macro_snap

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 15+ enforces edge-to-edge for apps targeting SDK 35+
        // (this app targets 36). Drawing under the system bars on pre-15
        // devices makes the behavior identical everywhere. Flutter already
        // renders under the bars and consumes the insets itself
        // (Scaffold/SafeArea), so no layout changes are needed.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }
}

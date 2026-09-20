package com.dcenhance.xtream_player

import com.dcenhance.xtream_player.dexcoreupdate.DceArchiveUpdates

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        DceArchiveUpdates.check(this);
    }
}


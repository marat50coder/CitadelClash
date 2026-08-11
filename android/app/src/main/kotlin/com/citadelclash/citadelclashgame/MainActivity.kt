package com.citadelclash.citadelclashgame

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Dependency-free WebView file upload: a site's <input type="file"> opens the
// WebView file selector, which hops here over a MethodChannel and returns the
// picked content:// URIs. Keeps the app off file_picker (whose 10.x line brings
// a clashing Kotlin Gradle Plugin).
class MainActivity : FlutterActivity() {
    private val bridgeName = "citadel/files"
    private val pickCode = 0x5C31
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bridgeName)
            .setMethodCallHandler { call, result ->
                if (call.method == "pick") {
                    val multiple = call.argument<Boolean>("multiple") ?: false
                    val mimes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                    launchChooser(multiple, mimes, result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun launchChooser(
        multiple: Boolean,
        mimes: List<String>,
        result: MethodChannel.Result,
    ) {
        pending?.success(emptyList<String>())
        pending = result

        val usable = mimes.filter { it.contains("/") }
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            when {
                usable.isEmpty() -> type = "*/*"
                usable.size == 1 -> type = usable[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, usable.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(Intent.createChooser(intent, null), pickCode)
        } catch (e: Exception) {
            pending = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickCode) return

        val result = pending
        pending = null
        if (result == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }

        val uris = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                uris.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { uris.add(it.toString()) }
        }
        result.success(uris)
    }
}

package com.letsbelikesophie.mehh

import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Mehh → 다른 앱(Cortex) 연결. 사용자가 버튼을 누를 때만 사진을 넘긴다.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mehh/handoff")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isInstalled" -> {
                        val pkg = call.argument<String>("package")!!
                        result.success(isInstalled(pkg))
                    }
                    "sendImage" -> {
                        val pkg = call.argument<String>("package")!!
                        val id = call.argument<String>("id")!!
                        result.success(sendImage(pkg, id))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isInstalled(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    /// 사진첩 사진(MediaStore id)을 그 앱의 공유 받기 화면으로 바로 보낸다.
    private fun sendImage(pkg: String, id: String): Boolean {
        val uri = ContentUris.withAppendedId(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            id.toLongOrNull() ?: return false,
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/*"
            putExtra(Intent.EXTRA_STREAM, uri)
            setPackage(pkg)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return try {
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}

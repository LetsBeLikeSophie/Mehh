package dev.itssophie.mehh

import android.content.ClipData
import android.content.ComponentName
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Mehh → 다른 앱(Cortex) 연결. 사용자가 버튼을 누를 때만 사진을 넘긴다.
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mehh/handoff")
        channel!!.setMethodCallHandler { call, result ->
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
                    "sendImages" -> {
                        val pkg = call.argument<String>("package")!!
                        val ids = call.argument<List<String>>("ids")!!
                        result.success(sendImages(pkg, ids))
                    }
                    else -> result.notImplemented()
                }
            }
        // 기기 정보: 사진 전체 용량, 갤러리 휴지통 열기 (2026-10-24 Sophie)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mehh/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "photoBytes" -> result.success(photoBytes())
                    "openTrash" -> result.success(openTrash())
                    else -> result.notImplemented()
                }
            }
    }

    /// 사진첩 사진 전체 용량(바이트). 휴지통에 있는 것은 빠진다(안드로이드 11+ 기본 조회).
    private fun photoBytes(): Long {
        var total = 0L
        contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.MediaColumns.SIZE),
            null, null, null,
        )?.use { c ->
            val col = c.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
            while (c.moveToNext()) total += c.getLong(col)
        }
        return total
    }

    /// 갤러리 앱의 휴지통을 연다. 안드로이드 공통 방법이 없어 차례로 시도한다.
    /// 반환: "trash"(휴지통 화면), "gallery"(갤러리 앱만), "none"
    private fun openTrash(): String {
        // 1) 삼성 갤러리: 휴지통 화면(이름에 Trash가 든 공개 화면)을 찾아 연다
        val samsung = "com.sec.android.gallery3d"
        try {
            @Suppress("DEPRECATION")
            val info = packageManager.getPackageInfo(samsung, PackageManager.GET_ACTIVITIES)
            val trash = info.activities?.firstOrNull { it.exported && it.name.contains("Trash", ignoreCase = true) }
            if (trash != null) {
                val ok = start(Intent().setComponent(ComponentName(samsung, trash.name)))
                if (ok) return "trash"
            }
            packageManager.getLaunchIntentForPackage(samsung)?.let { if (start(it)) return "gallery" }
        } catch (e: PackageManager.NameNotFoundException) {
        }
        // 2) Google 포토: 휴지통 주소
        val photos = Intent(Intent.ACTION_VIEW, Uri.parse("https://photos.google.com/trash"))
            .setPackage("com.google.android.apps.photos")
        if (photos.resolveActivity(packageManager) != null && start(photos)) return "trash"
        // 3) 아무 갤러리 앱
        val gallery = Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_GALLERY)
        if (start(gallery)) return "gallery"
        return "none"
    }

    private fun start(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: Exception) {
        false
    }

    /// Cortex가 저장을 마치면 mehh://cortex-saved?count=N 으로 Mehh를 다시 연다 (2026-10-22 Sophie C2-A)
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val data = intent.data ?: return
        if (data.scheme == "mehh" && data.host == "cortex-saved") {
            val count = data.getQueryParameter("count")?.toIntOrNull() ?: 0
            // 다음 버전 Cortex는 저장한 사진 id 목록도 돌려준다 (ids=1,2,3). 없으면 장수만
            val ids = data.getQueryParameter("ids")
                ?.split(',')?.map { it.trim() }?.filter { it.isNotEmpty() }
            channel?.invokeMethod("cortexSaved", mapOf("count" to count, "ids" to ids))
        }
    }

    private fun isInstalled(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    private fun uriOf(id: String): Uri? = id.toLongOrNull()?.let {
        ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, it)
    }

    /// 여러 장을 한 번에 보낸다. 반환: "ok", "unsupported"(그 앱이 여러 장 받기를 안 함), "failed"
    private fun sendImages(pkg: String, ids: List<String>): String {
        val uris = ArrayList(ids.mapNotNull(::uriOf))
        if (uris.isEmpty()) return "failed"
        if (uris.size == 1) return if (sendImage(pkg, ids.first())) "ok" else "failed"
        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = "image/*"
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            putExtra(Intent.EXTRA_TEXT, returnUrl(ids))
            // 받는 앱이 모든 사진을 읽을 수 있게 ClipData로도 넘긴다
            clipData = ClipData.newRawUri(null, uris.first()).also { clip ->
                uris.drop(1).forEach { clip.addItem(ClipData.Item(it)) }
            }
            setPackage(pkg)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        if (intent.resolveActivity(packageManager) == null) return "unsupported"
        return try {
            startActivity(intent)
            "ok"
        } catch (e: Exception) {
            "failed"
        }
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
            putExtra(Intent.EXTRA_TEXT, returnUrl(listOf(id)))
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

    companion object {
        /// 받는 앱(Cortex)이 저장을 마친 뒤 열 주소. 공유 글(EXTRA_TEXT)로 같이 넘긴다.
        const val RETURN_URL = "mehh://cortex-saved"

        /// 보내는 사진 id를 보낸 순서대로 붙인다. Cortex는 저장한 것의 id만 돌려준다
        /// (mehh://cortex-saved?count=N&ids=…, 2026-10-23 Sophie C1-B)
        fun returnUrl(ids: List<String>) = "$RETURN_URL?ids=${ids.joinToString(",")}"
    }
}

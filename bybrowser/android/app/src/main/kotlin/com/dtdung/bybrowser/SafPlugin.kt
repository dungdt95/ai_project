package com.dtdung.bybrowser

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException
import java.util.concurrent.Executors

/**
 * Cầu nối Storage Access Framework cho Dart (`SafService`).
 *
 * Mọi file đều được tham chiếu bằng content URI; sau khi người dùng chọn file
 * ta lấy persistable permission để có thể mở lại / ghi đè về sau mà không cần
 * quyền truy cập toàn bộ bộ nhớ.
 */
class SafPlugin(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.dtdung.bybrowser/saf"
        private const val REQ_OPEN = 0x5A01
        private const val REQ_CREATE = 0x5A02
    }

    private val channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** Result đang chờ activity trả về (chỉ một hộp thoại tại một thời điểm). */
    private var pending: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openDocument" -> openDocument(call.argument<List<String>>("mimeTypes"), result)
            "createDocument" -> createDocument(
                call.argument<String>("name") ?: "untitled",
                call.argument<String>("mime") ?: "*/*",
                result,
            )
            "readBytes" -> runIo(result) { readBytes(uriArg(call)) }
            "writeBytes" -> runIo(result) {
                writeBytes(uriArg(call), call.argument<ByteArray>("bytes") ?: ByteArray(0)); null
            }
            "getInfo" -> runIo(result) { describe(uriArg(call), requireAccess = true) }
            "releasePermission" -> runIo(result) { releasePermission(uriArg(call)); null }
            else -> result.notImplemented()
        }
    }

    // ---------------------------------------------------------------- pickers

    private fun openDocument(mimeTypes: List<String>?, result: MethodChannel.Result) {
        if (!claimPending(result)) return
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            if (!mimeTypes.isNullOrEmpty()) putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }
        activity.startActivityForResult(intent, REQ_OPEN)
    }

    private fun createDocument(name: String, mime: String, result: MethodChannel.Result) {
        if (!claimPending(result)) return
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mime
            putExtra(Intent.EXTRA_TITLE, name)
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )
        }
        activity.startActivityForResult(intent, REQ_CREATE)
    }

    private fun claimPending(result: MethodChannel.Result): Boolean {
        if (pending != null) {
            result.error("busy", "Đang có hộp thoại chọn file khác mở", null)
            return false
        }
        pending = result
        return true
    }

    /** Gọi từ MainActivity.onActivityResult. Trả về true nếu đã xử lý. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQ_OPEN && requestCode != REQ_CREATE) return false
        val result = pending ?: return true
        pending = null

        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri == null) {
            result.success(null) // người dùng hủy
            return true
        }
        runIo(result) {
            try {
                activity.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                )
            } catch (_: SecurityException) {
                // Một số provider không cho persist; vẫn dùng được trong phiên này.
            }
            describe(uri, requireAccess = false)
        }
        return true
    }

    // ------------------------------------------------------------------- io

    private fun readBytes(uri: Uri): ByteArray {
        val stream = activity.contentResolver.openInputStream(uri)
            ?: throw SafError("not_found", "Không mở được file để đọc")
        return stream.use { it.readBytes() }
    }

    private fun writeBytes(uri: Uri, bytes: ByteArray) {
        // "wt" = ghi + truncate. Một số provider không hỗ trợ "wt" → thử "rwt" rồi "w".
        val resolver = activity.contentResolver
        val stream = sequenceOf("wt", "rwt", "w").firstNotNullOfOrNull { mode ->
            try {
                resolver.openOutputStream(uri, mode)
            } catch (_: FileNotFoundException) {
                null
            } catch (_: IllegalArgumentException) {
                null
            } catch (_: UnsupportedOperationException) {
                null
            }
        } ?: throw SafError("write_failed", "Không mở được file để ghi")
        stream.use {
            it.write(bytes)
            it.flush()
        }
    }

    private fun releasePermission(uri: Uri) {
        try {
            activity.contentResolver.releasePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
            // Quyền đã không còn — bỏ qua.
        }
    }

    /** Lấy tên, kích thước, mime của URI. Ném lỗi nếu không còn truy cập được. */
    private fun describe(uri: Uri, requireAccess: Boolean): Map<String, Any?> {
        val resolver = activity.contentResolver
        var name: String? = null
        var size: Long? = null
        var cursor: Cursor? = null
        try {
            cursor = resolver.query(uri, null, null, null, null)
            if (cursor != null && cursor.moveToFirst()) {
                val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIdx >= 0) name = cursor.getString(nameIdx)
                val sizeIdx = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (sizeIdx >= 0 && !cursor.isNull(sizeIdx)) size = cursor.getLong(sizeIdx)
            } else if (requireAccess) {
                throw SafError("not_found", "File không còn tồn tại")
            }
        } catch (e: SecurityException) {
            throw SafError("no_permission", "Không còn quyền truy cập file")
        } catch (e: IllegalArgumentException) {
            throw SafError("not_found", "File không còn tồn tại")
        } finally {
            cursor?.close()
        }
        if (name == null) name = uri.lastPathSegment?.substringAfterLast('/') ?: "Không tên"
        val mime = try {
            resolver.getType(uri)
        } catch (_: Exception) {
            null
        }
        return mapOf(
            "uri" to uri.toString(),
            "name" to name,
            "size" to size,
            "mime" to mime,
        )
    }

    // --------------------------------------------------------------- helpers

    private fun uriArg(call: MethodCall): Uri {
        val s = call.argument<String>("uri") ?: throw SafError("bad_args", "Thiếu uri")
        return Uri.parse(s)
    }

    /** Chạy [block] trên thread IO rồi trả kết quả về main thread. */
    private fun runIo(result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            val outcome = try {
                Outcome.Ok(block())
            } catch (e: SafError) {
                Outcome.Err(e.code, e.message ?: "")
            } catch (e: FileNotFoundException) {
                Outcome.Err("not_found", "File không còn tồn tại")
            } catch (e: SecurityException) {
                Outcome.Err("no_permission", "Không còn quyền truy cập file")
            } catch (e: Exception) {
                Outcome.Err("io_error", e.message ?: e.javaClass.simpleName)
            }
            main.post {
                when (outcome) {
                    is Outcome.Ok -> result.success(outcome.value)
                    is Outcome.Err -> result.error(outcome.code, outcome.message, null)
                }
            }
        }
    }

    private sealed class Outcome {
        class Ok(val value: Any?) : Outcome()
        class Err(val code: String, val message: String) : Outcome()
    }

    private class SafError(val code: String, message: String) : Exception(message)

    fun dispose() {
        channel.setMethodCallHandler(null)
        io.shutdown()
    }
}

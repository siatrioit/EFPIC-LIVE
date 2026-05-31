package lv.edgarsfoto.efpic_live

import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import lv.edgarsfoto.efpic_live.xmp.XmpImageRenderer
import lv.edgarsfoto.efpic_live.xmp.XmpParser
import java.util.concurrent.Executors

/**
 * Flutter bridge for Lightroom `.xmp` preset import and rendering.
 */
class XmpPresetPlugin(
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "lv.edgarsfoto.efpic_live/xmp_preset"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val ioExecutor = Executors.newSingleThreadExecutor()

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        ioExecutor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)
            "extractDisplayName" -> {
                val path = call.argument<String>("xmpPath") ?: run {
                    result.error("ARG", "xmpPath required", null)
                    return
                }
                ioExecutor.execute {
                    try {
                        result.success(XmpImageRenderer.extractDisplayName(path))
                    } catch (e: Exception) {
                        result.error("XMP", e.message, null)
                    }
                }
            }
            "validateXmp" -> {
                val path = call.argument<String>("xmpPath") ?: run {
                    result.error("ARG", "xmpPath required", null)
                    return
                }
                ioExecutor.execute {
                    try {
                        XmpParser.parse(java.io.File(path).inputStream())
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
            }
            "applyXmpToFile" -> {
                val xmpPath = call.argument<String>("xmpPath")
                val sourcePath = call.argument<String>("sourcePath")
                val destPath = call.argument<String>("destPath")
                if (xmpPath == null || sourcePath == null || destPath == null) {
                    result.error("ARG", "xmpPath, sourcePath, destPath required", null)
                    return
                }
                ioExecutor.execute {
                    try {
                        val ok = XmpImageRenderer.applyXmpToFile(xmpPath, sourcePath, destPath)
                        result.success(ok)
                    } catch (e: Exception) {
                        result.error("RENDER", e.message, null)
                    }
                }
            }
            "renderPreviewJpeg" -> {
                val xmpPath = call.argument<String>("xmpPath")
                val sourcePath = call.argument<String>("sourcePath")
                val maxEdge = call.argument<Int>("maxLongEdge") ?: 1400
                if (xmpPath == null || sourcePath == null) {
                    result.error("ARG", "xmpPath, sourcePath required", null)
                    return
                }
                ioExecutor.execute {
                    try {
                        val bytes = XmpImageRenderer.renderPreviewJpeg(
                            xmpPath, sourcePath, maxEdge,
                        )
                        if (bytes == null) {
                            result.success(null)
                        } else {
                            result.success(bytes)
                        }
                    } catch (e: Exception) {
                        result.error("RENDER", e.message, null)
                    }
                }
            }
            "invalidateCache" -> {
                val path = call.argument<String>("xmpPath")
                XmpImageRenderer.invalidateCache(path)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}

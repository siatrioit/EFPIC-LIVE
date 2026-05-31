package lv.edgarsfoto.efpic_live

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import lv.edgarsfoto.efpic_live.raw.develop.DevelopOptions
import lv.edgarsfoto.efpic_live.raw.develop.LibRawSupport
import lv.edgarsfoto.efpic_live.raw.develop.RawDevelopCoordinator
import java.util.concurrent.Executors

/**
 * Lightroom-style develop: same engine for preview bytes and export file.
 */
class RawDevelopPlugin(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "lv.edgarsfoto.efpic_live/raw_develop"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)
            "isLibRawLinked" -> result.success(LibRawSupport.isLinked())
            "setDevelopOptions" -> {
                DevelopOptions.tiledExportEnabled =
                    call.argument<Boolean>("tiledExportEnabled") ?: true
                DevelopOptions.useGpuTileBlit =
                    call.argument<Boolean>("useGpuTileBlit") ?: true
                result.success(null)
            }
            "renderPreview" -> runDevelop(call, result, preview = true)
            "renderExport" -> runDevelop(call, result, preview = false)
            else -> result.notImplemented()
        }
    }

    private fun runDevelop(
        call: MethodCall,
        result: MethodChannel.Result,
        preview: Boolean,
    ) {
        val rawPath = call.argument<String>("rawPath")
        if (rawPath.isNullOrBlank()) {
            result.error("ARG", "rawPath required", null)
            return
        }
        val args = DevelopArgs.fromCall(call)
        executor.execute {
            try {
                val out = if (preview) {
                    RawDevelopCoordinator.developPreviewForPath(
                        rawPath = rawPath,
                        kelvin = args.kelvin,
                        tint = args.tint,
                        exposureOffset = args.exposureOffset,
                        contrastOffset = args.contrastOffset,
                        shadowsOffset = args.shadowsOffset,
                        highlightsOffset = args.highlightsOffset,
                        sharpnessOffset = args.sharpnessOffset,
                    )
                } else {
                    RawDevelopCoordinator.developExportForPath(
                        rawPath = rawPath,
                        kelvin = args.kelvin,
                        tint = args.tint,
                        exposureOffset = args.exposureOffset,
                        contrastOffset = args.contrastOffset,
                        shadowsOffset = args.shadowsOffset,
                        highlightsOffset = args.highlightsOffset,
                        sharpnessOffset = args.sharpnessOffset,
                    )
                }
                mainHandler.post {
                    result.success(
                        mapOf(
                            "jpeg" to out.jpegBytes,
                            "width" to out.width,
                            "height" to out.height,
                            "source" to out.sourceLabel,
                        ),
                    )
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("DEVELOP", e.message, null)
                }
            }
        }
    }

    private data class DevelopArgs(
        val kelvin: Float,
        val tint: Float,
        val exposureOffset: Float,
        val contrastOffset: Float,
        val shadowsOffset: Float,
        val highlightsOffset: Float,
        val sharpnessOffset: Float,
    ) {
        companion object {
            fun fromCall(call: MethodCall) = DevelopArgs(
                kelvin = call.argument<Number>("kelvin")?.toFloat() ?: 6500f,
                tint = call.argument<Number>("tint")?.toFloat() ?: 0f,
                exposureOffset = call.argument<Number>("exposureOffset")?.toFloat() ?: 0f,
                contrastOffset = call.argument<Number>("contrastOffset")?.toFloat() ?: 0f,
                shadowsOffset = call.argument<Number>("shadowsOffset")?.toFloat() ?: 0f,
                highlightsOffset = call.argument<Number>("highlightsOffset")?.toFloat() ?: 0f,
                sharpnessOffset = call.argument<Number>("sharpnessOffset")?.toFloat() ?: 0f,
            )
        }
    }
}

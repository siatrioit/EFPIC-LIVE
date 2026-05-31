package lv.edgarsfoto.efpic_live

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import lv.edgarsfoto.efpic_live.raw.RawEditSessionManager
import lv.edgarsfoto.efpic_live.raw.UserAdjustments
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * MethodChannel: initialize RAW edit session with camera "As Shot" baseline from NEF/RAW.
 */
class RawEditPlugin(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "lv.edgarsfoto.efpic_live/raw_edit"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)
            "initializeSession" -> {
                val rawPath = call.argument<String>("rawPath")
                val previewPath = call.argument<String>("previewPath")
                if (rawPath.isNullOrBlank() || previewPath.isNullOrBlank()) {
                    result.error("ARG", "rawPath and previewPath required", null)
                    return
                }
                val latch = CountDownLatch(1)
                val out = AtomicReference<Map<String, Any?>?>()
                val err = AtomicReference<Exception?>()
                RawEditSessionManager.openSessionAsync(
                    rawPath = rawPath,
                    previewPath = previewPath,
                    onComplete = { state ->
                        out.set(RawEditSessionManager.toFlutterMap(state))
                        latch.countDown()
                    },
                    onError = { e ->
                        err.set(e)
                        latch.countDown()
                    },
                )
                Thread {
                    try {
                        if (!latch.await(45, TimeUnit.SECONDS)) {
                            mainHandler.post {
                                result.error("TIMEOUT", "RAW metadata read timeout", null)
                            }
                            return@Thread
                        }
                        mainHandler.post {
                            val error = err.get()
                            if (error != null) {
                                result.error("RAW", error.message, null)
                            } else {
                                result.success(out.get())
                            }
                        }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("RAW", e.message, null) }
                    }
                }.start()
            }
            "getSession" -> {
                val rawPath = call.argument<String>("rawPath") ?: run {
                    result.error("ARG", "rawPath required", null)
                    return
                }
                val state = RawEditSessionManager.get(rawPath)
                if (state == null) result.success(null)
                else result.success(RawEditSessionManager.toFlutterMap(state))
            }
            "invalidateSession" -> {
                RawEditSessionManager.invalidate(call.argument<String>("rawPath"))
                result.success(null)
            }
            "syncBaselineFromDart" -> {
                val rawPath = call.argument<String>("rawPath")
                @Suppress("UNCHECKED_CAST")
                val map = call.argument<Map<String, Any?>>("baseline")
                if (rawPath.isNullOrBlank() || map == null) {
                    result.error("ARG", "rawPath and baseline required", null)
                    return
                }
                val state = RawEditSessionManager.syncBaselineFromDart(rawPath, map)
                if (state == null) result.error("SESSION", "No RAW session", null)
                else result.success(RawEditSessionManager.toFlutterMap(state))
            }
            "setWhiteBalance" -> {
                val rawPath = call.argument<String>("rawPath")
                val kelvin = call.argument<Number>("kelvin")?.toFloat()
                val tint = call.argument<Number>("tint")?.toFloat()
                if (rawPath.isNullOrBlank() || kelvin == null || tint == null) {
                    result.error("ARG", "rawPath, kelvin, tint required", null)
                    return
                }
                val map = RawEditSessionManager.updateWhiteBalanceFromSliders(
                    rawPath,
                    kelvin,
                    tint,
                )
                if (map == null) result.error("SESSION", "No RAW session for path", null)
                else result.success(map)
            }
            "getWhiteBalanceState" -> {
                val rawPath = call.argument<String>("rawPath") ?: run {
                    result.error("ARG", "rawPath required", null)
                    return
                }
                result.success(RawEditSessionManager.whiteBalanceUiState(rawPath))
            }
            else -> result.notImplemented()
        }
    }
}

package lv.edgarsfoto.efpic_live.raw

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Async lifecycle for RAW edit sessions — extracts baseline once, caches for preview loop.
 */
object RawEditSessionManager {
    private val executor = Executors.newCachedThreadPool()
    private val sessions = ConcurrentHashMap<String, EditSessionState>()

    @JvmStatic
    fun get(rawPath: String): EditSessionState? = sessions[rawPath]

    @JvmStatic
    fun invalidate(rawPath: String? = null) {
        if (rawPath == null) sessions.clear()
        else sessions.remove(rawPath)
    }

    /**
     * Opens a session: reads camera baseline from [rawPath], links [previewPath] for rendering.
     * Blocks until complete (call from background thread / executor).
     */
    @JvmStatic
    fun openSession(rawPath: String, previewPath: String): EditSessionState {
        val baseline = RawCameraBaselineExtractor.extract(rawPath)
        val state = EditSessionState(
            rawPath = rawPath,
            previewPath = previewPath,
            cameraBaseline = baseline,
        )
        sessions[rawPath] = state
        return state
    }

    /** Async open — callback on main thread via supplied handler. */
    @JvmStatic
    fun openSessionAsync(
        rawPath: String,
        previewPath: String,
        onComplete: (EditSessionState) -> Unit,
        onError: (Exception) -> Unit,
    ) {
        executor.execute {
            try {
                val state = openSession(rawPath, previewPath)
                onComplete(state)
            } catch (e: Exception) {
                onError(e)
            }
        }
    }

    @JvmStatic
    fun updateUserAdjustments(rawPath: String, user: UserAdjustments): EditSessionState? {
        val prev = sessions[rawPath] ?: return null
        val next = prev.withUserAdjustments(user)
        sessions[rawPath] = next
        return next
    }

    @JvmStatic
    fun pipelineConfig(rawPath: String): PipelineConfig? =
        sessions[rawPath]?.let { PipelineConfig.from(it) }

    @JvmStatic
    fun updateWhiteBalanceFromSliders(
        rawPath: String,
        sliderKelvin: Float,
        sliderTint: Float,
    ): Map<String, Any?>? {
        val state = sessions[rawPath] ?: return null
        val next = WhiteBalanceController(state.cameraBaseline)
            .syncSessionFromSliders(state, sliderKelvin, sliderTint)
        sessions[rawPath] = next
        return toFlutterMap(next)
    }

    @JvmStatic
    fun whiteBalanceUiState(rawPath: String): Map<String, Any?>? {
        val state = sessions[rawPath] ?: return null
        val e = state.effective()
        val wb = WhiteBalanceController(state.cameraBaseline)
            .uiStateFromSliders(e.kelvin, e.tint)
        return mapOf(
            "baselineKelvin" to wb.baselineKelvin.toDouble(),
            "baselineTint" to wb.baselineTint.toDouble(),
            "appliedKelvin" to wb.appliedKelvin.toDouble(),
            "appliedTint" to wb.appliedTint.toDouble(),
            "kelvinOffset" to wb.kelvinOffset.toDouble(),
            "tintOffset" to wb.tintOffset.toDouble(),
            "deltaRedGain" to wb.deltaRedGain.toDouble(),
            "deltaGreenGain" to wb.deltaGreenGain.toDouble(),
            "deltaBlueGain" to wb.deltaBlueGain.toDouble(),
        )
    }

    @JvmStatic
    fun toFlutterMap(state: EditSessionState): Map<String, Any?> {
        val b = state.cameraBaseline
        val e = state.effective()
        val wb = WhiteBalanceController(b).uiStateFromSliders(e.kelvin, e.tint)
        return mapOf(
            "rawPath" to state.rawPath,
            "previewPath" to state.previewPath,
            "exposureEv" to b.exposureEv.toDouble(),
            "kelvin" to b.kelvin.toDouble(),
            "tint" to b.tint.toDouble(),
            "baselineKelvin" to wb.baselineKelvin.toDouble(),
            "baselineTint" to wb.baselineTint.toDouble(),
            "appliedKelvin" to wb.appliedKelvin.toDouble(),
            "appliedTint" to wb.appliedTint.toDouble(),
            "kelvinOffset" to wb.kelvinOffset.toDouble(),
            "tintOffset" to wb.tintOffset.toDouble(),
            "deltaRedGain" to wb.deltaRedGain.toDouble(),
            "deltaGreenGain" to wb.deltaGreenGain.toDouble(),
            "deltaBlueGain" to wb.deltaBlueGain.toDouble(),
            "redGain" to b.redGain.toDouble(),
            "greenGain" to b.greenGain.toDouble(),
            "blueGain" to b.blueGain.toDouble(),
            "contrast" to b.contrast.toDouble(),
            "shadows" to b.shadows.toDouble(),
            "highlights" to b.highlights.toDouble(),
            "sharpness" to b.sharpness.toDouble(),
            "saturation" to b.saturation.toDouble(),
            "colorSpace" to b.colorSpace.name,
            "pictureControl" to b.pictureControl,
            "cameraModel" to b.cameraModel,
            "rawWidth" to b.rawWidth,
            "rawHeight" to b.rawHeight,
            "sources" to b.sources,
            "usedFallback" to b.usedFallback,
        )
    }
}

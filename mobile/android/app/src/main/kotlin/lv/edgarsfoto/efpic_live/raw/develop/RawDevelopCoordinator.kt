package lv.edgarsfoto.efpic_live.raw.develop

import lv.edgarsfoto.efpic_live.raw.EditSessionState
import lv.edgarsfoto.efpic_live.raw.RawEditSessionManager
import lv.edgarsfoto.efpic_live.raw.UserAdjustments

/**
 * Single entry for Lightroom-style develop (preview + export).
 */
object RawDevelopCoordinator {

    const val PREVIEW_MAX_LONG_EDGE = 2048
    const val PREVIEW_JPEG_QUALITY = 88
    const val EXPORT_JPEG_QUALITY = 92

    /** Fāze 2: LibRaw demosaic when linked; else embedded JPG proxy. */
    private val engine: RawDevelopEngine = FallbackDevelopEngine()

    @JvmStatic
    fun developPreview(session: EditSessionState): RawDevelopEngine.DevelopResult =
        engine.develop(session, PREVIEW_MAX_LONG_EDGE, PREVIEW_JPEG_QUALITY)

    @JvmStatic
    fun developExport(session: EditSessionState): RawDevelopEngine.DevelopResult =
        engine.develop(session, maxLongEdge = 0, EXPORT_JPEG_QUALITY)

    @JvmStatic
    fun developPreviewForPath(
        rawPath: String,
        kelvin: Float,
        tint: Float,
        exposureOffset: Float = 0f,
        contrastOffset: Float = 0f,
        shadowsOffset: Float = 0f,
        highlightsOffset: Float = 0f,
        sharpnessOffset: Float = 0f,
    ): RawDevelopEngine.DevelopResult {
        val session = sessionWithSliders(
            rawPath,
            kelvin,
            tint,
            exposureOffset,
            contrastOffset,
            shadowsOffset,
            highlightsOffset,
            sharpnessOffset,
        )
        return developPreview(session)
    }

    @JvmStatic
    fun developExportForPath(
        rawPath: String,
        kelvin: Float,
        tint: Float,
        exposureOffset: Float = 0f,
        contrastOffset: Float = 0f,
        shadowsOffset: Float = 0f,
        highlightsOffset: Float = 0f,
        sharpnessOffset: Float = 0f,
    ): RawDevelopEngine.DevelopResult {
        val session = sessionWithSliders(
            rawPath,
            kelvin,
            tint,
            exposureOffset,
            contrastOffset,
            shadowsOffset,
            highlightsOffset,
            sharpnessOffset,
        )
        return developExport(session)
    }

    @JvmStatic
    fun developExportToFile(
        rawPath: String,
        destPath: String,
        kelvin: Float,
        tint: Float,
        exposureOffset: Float = 0f,
        contrastOffset: Float = 0f,
        shadowsOffset: Float = 0f,
        highlightsOffset: Float = 0f,
        sharpnessOffset: Float = 0f,
    ): RawDevelopEngine.DevelopResult {
        val result = developExportForPath(
            rawPath,
            kelvin,
            tint,
            exposureOffset,
            contrastOffset,
            shadowsOffset,
            highlightsOffset,
            sharpnessOffset,
        )
        java.io.File(destPath).apply {
            parentFile?.mkdirs()
            writeBytes(result.jpegBytes)
        }
        return result
    }

    private fun sessionWithSliders(
        rawPath: String,
        kelvin: Float,
        tint: Float,
        exposureOffset: Float,
        contrastOffset: Float,
        shadowsOffset: Float,
        highlightsOffset: Float,
        sharpnessOffset: Float,
    ): EditSessionState {
        val state = RawEditSessionManager.get(rawPath)
            ?: throw IllegalStateException("RAW session not initialized: $rawPath")
        val b = state.cameraBaseline
        val user = UserAdjustments(
            exposureOffset = exposureOffset,
            kelvinOffset = kelvin - b.kelvin,
            tintOffset = tint - b.tint,
            contrastOffset = contrastOffset,
            shadowsOffset = shadowsOffset,
            highlightsOffset = highlightsOffset,
            sharpnessOffset = sharpnessOffset,
        )
        return RawEditSessionManager.updateUserAdjustments(rawPath, user)
            ?: throw IllegalStateException("RAW session not initialized: $rawPath")
    }
}

package lv.edgarsfoto.efpic_live.raw

/**
 * In-camera "As Shot" values read from RAW (NEF/ARW/CR2…) — immutable baseline.
 *
 * User edits are stored separately as [UserAdjustments]; effective render values are
 * `baseline + offset` (see [EditSessionState.effective]).
 */
data class CameraBaseline(
    val exposureEv: Float = 0f,
    val kelvin: Float = 6500f,
    val tint: Float = 0f,
    /** Von Kries-style multipliers from Nikon ColorBalance / WB tags. */
    val redGain: Float = 1f,
    val greenGain: Float = 1f,
    val blueGain: Float = 1f,
    val contrast: Float = 0f,
    val shadows: Float = 0f,
    val highlights: Float = 0f,
    val sharpness: Float = 0f,
    val saturation: Float = 1f,
    val colorSpace: ColorSpace = ColorSpace.SRGB,
    val pictureControl: String? = null,
    val cameraModel: String? = null,
    val rawWidth: Int = 0,
    val rawHeight: Int = 0,
    val sources: List<String> = emptyList(),
) {
    val usedFallback: Boolean get() = sources.isEmpty()

    enum class ColorSpace { SRGB, ADOBE_RGB, UNKNOWN }
}

/**
 * Cumulative user deltas vs [CameraBaseline] (non-destructive).
 * Slider at 0 means "no change from as-shot".
 */
data class UserAdjustments(
    val exposureOffset: Float = 0f,
    val kelvinOffset: Float = 0f,
    val tintOffset: Float = 0f,
    val contrastOffset: Float = 0f,
    val shadowsOffset: Float = 0f,
    val highlightsOffset: Float = 0f,
    val sharpnessOffset: Float = 0f,
    val saturationMultiplier: Float = 1f,
) {
    companion object {
        val ZERO = UserAdjustments()
    }
}

/** Effective slider values = camera baseline + user offsets. */
data class EffectiveEditParams(
    val exposureEv: Float,
    val kelvin: Float,
    val tint: Float,
    val redGain: Float,
    val greenGain: Float,
    val blueGain: Float,
    val contrast: Float,
    val shadows: Float,
    val highlights: Float,
    val sharpness: Float,
    val saturation: Float,
    val colorSpace: CameraBaseline.ColorSpace,
    val pictureControl: String?,
)

/**
 * Session opened when user edits a RAW-backed image.
 * Baseline is fixed; [userAdjustments] mutate during editing.
 */
data class EditSessionState(
    val rawPath: String,
    val previewPath: String,
    val cameraBaseline: CameraBaseline,
    val userAdjustments: UserAdjustments = UserAdjustments.ZERO,
    val createdAtMs: Long = System.currentTimeMillis(),
) {
    /** Values fed into tone/WB/HSL processing (baseline + user). */
    fun effective(): EffectiveEditParams {
        val b = cameraBaseline
        val u = userAdjustments
        return EffectiveEditParams(
            exposureEv = b.exposureEv + u.exposureOffset,
            kelvin = (b.kelvin + u.kelvinOffset).coerceIn(2000f, 50000f),
            tint = (b.tint + u.tintOffset).coerceIn(-150f, 150f),
            redGain = b.redGain,
            greenGain = b.greenGain,
            blueGain = b.blueGain,
            contrast = b.contrast + u.contrastOffset,
            shadows = b.shadows + u.shadowsOffset,
            highlights = b.highlights + u.highlightsOffset,
            sharpness = b.sharpness + u.sharpnessOffset,
            saturation = b.saturation * u.saturationMultiplier,
            colorSpace = b.colorSpace,
            pictureControl = b.pictureControl,
        )
    }

    fun resetUserAdjustments(): EditSessionState = copy(userAdjustments = UserAdjustments.ZERO)

    fun withUserAdjustments(user: UserAdjustments): EditSessionState =
        copy(userAdjustments = user)
}

/**
 * Maps [EffectiveEditParams] into the background render chain
 * (exposure → WB → tones → curves → HSL → grading → local contrast → sharpen).
 */
data class PipelineConfig(
    val tone: ToneBlock,
    val whiteBalance: WhiteBalanceBlock,
    val colorProfileMatrix: FloatArray? = null,
) {
    data class ToneBlock(
        val exposureEv: Float,
        val contrast: Float,
        val shadows: Float,
        val highlights: Float,
        val whites: Float = 0f,
        val blacks: Float = 0f,
        val saturation: Float,
    )

    data class WhiteBalanceBlock(
        val baselineKelvin: Float,
        val baselineTint: Float,
        val appliedKelvin: Float,
        val appliedTint: Float,
        /** Channel multipliers for preview (delta vs as-shot embedded JPG). */
        val deltaRedGain: Float,
        val deltaGreenGain: Float,
        val deltaBlueGain: Float,
    )

    companion object {
        fun from(state: EditSessionState): PipelineConfig {
            val e = state.effective()
            val wb = WhiteBalanceController(state.cameraBaseline).uiStateFromSliders(
                e.kelvin,
                e.tint,
            )
            return PipelineConfig(
                tone = ToneBlock(
                    exposureEv = e.exposureEv,
                    contrast = e.contrast,
                    shadows = e.shadows,
                    highlights = e.highlights,
                    saturation = e.saturation,
                ),
                whiteBalance = WhiteBalanceBlock(
                    baselineKelvin = wb.baselineKelvin,
                    baselineTint = wb.baselineTint,
                    appliedKelvin = wb.appliedKelvin,
                    appliedTint = wb.appliedTint,
                    deltaRedGain = wb.deltaRedGain,
                    deltaGreenGain = wb.deltaGreenGain,
                    deltaBlueGain = wb.deltaBlueGain,
                ),
                colorProfileMatrix = ColorProfileMatrix.forProfile(
                    e.colorSpace,
                    e.pictureControl,
                ),
            )
        }
    }
}

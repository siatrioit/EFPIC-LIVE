package lv.edgarsfoto.efpic_live.raw

import lv.edgarsfoto.efpic_live.processing.WhiteBalanceMath

/**
 * Links RAW "As Shot" white balance to UI sliders and the render engine.
 *
 * - Sliders show **absolute** Kelvin/Tint (= camera baseline + user offset).
 * - Engine applies **delta gains** vs baseline so embedded JPG previews stay neutral at load.
 * - Double-tap reset → [baselineKelvin] / [baselineTint] from [CameraBaseline].
 */
class WhiteBalanceController(
    private val baseline: CameraBaseline,
) {
    val baselineKelvin: Float get() = baseline.kelvin
    val baselineTint: Float get() = baseline.tint

    val cameraMultipliers: WhiteBalanceMath.RgbGains
        get() = WhiteBalanceMath.RgbGains(
            baseline.redGain,
            baseline.greenGain,
            baseline.blueGain,
        )

    /** UI + engine state for current slider positions (absolute K/tint). */
    data class UiState(
        val baselineKelvin: Float,
        val baselineTint: Float,
        val appliedKelvin: Float,
        val appliedTint: Float,
        val kelvinOffset: Float,
        val tintOffset: Float,
        val deltaRedGain: Float,
        val deltaGreenGain: Float,
        val deltaBlueGain: Float,
    )

    /** Applied = baseline + offset (clamped to UI range). */
    fun appliedFromOffsets(kelvinOffset: Float, tintOffset: Float): Pair<Float, Float> {
        val k = (baselineKelvin + kelvinOffset).coerceIn(
            WhiteBalanceMath.KELVIN_MIN,
            WhiteBalanceMath.KELVIN_MAX,
        )
        val t = (baselineTint + tintOffset).coerceIn(
            WhiteBalanceMath.TINT_MIN,
            WhiteBalanceMath.TINT_MAX,
        )
        return k to t
    }

    fun offsetsFromSliders(sliderKelvin: Float, sliderTint: Float): UserAdjustments {
        val b = baseline
        return UserAdjustments(
            kelvinOffset = sliderKelvin - b.kelvin,
            tintOffset = sliderTint - b.tint,
        )
    }

    /** Map absolute slider values (Kelvin/Tint) → UI state + delta RGB multipliers. */
    fun uiStateFromSliders(sliderKelvin: Float, sliderTint: Float): UiState {
        val appliedK = sliderKelvin.coerceIn(
            WhiteBalanceMath.KELVIN_MIN,
            WhiteBalanceMath.KELVIN_MAX,
        )
        val appliedT = sliderTint.coerceIn(
            WhiteBalanceMath.TINT_MIN,
            WhiteBalanceMath.TINT_MAX,
        )
        val delta = previewDeltaGains(appliedK, appliedT)
        return UiState(
            baselineKelvin = baselineKelvin,
            baselineTint = baselineTint,
            appliedKelvin = appliedK,
            appliedTint = appliedT,
            kelvinOffset = appliedK - baselineKelvin,
            tintOffset = appliedT - baselineTint,
            deltaRedGain = delta.r,
            deltaGreenGain = delta.g,
            deltaBlueGain = delta.b,
        )
    }

    fun uiStateFromSession(state: EditSessionState): UiState {
        val e = state.effective()
        return uiStateFromSliders(e.kelvin, e.tint)
    }

    /**
     * Gains applied on embedded preview: only the change vs in-camera WB.
     * Uses Nikon RGGB multipliers when present on baseline.
     */
    fun previewDeltaGains(appliedKelvin: Float, appliedTint: Float): WhiteBalanceMath.RgbGains {
        val cam = if (baseline.sources.any { it.contains("nikon:Wb", ignoreCase = true) }) {
            cameraMultipliers
        } else {
            null
        }
        return WhiteBalanceMath.deltaGains(
            baselineKelvin = baselineKelvin,
            baselineTint = baselineTint,
            targetKelvin = appliedKelvin,
            targetTint = appliedTint,
            baselineCameraMultipliers = cam,
            targetCameraMultipliers = cam,
        )
    }

    fun resetToAsShot(): Pair<Float, Float> = baselineKelvin to baselineTint

    fun syncSessionFromSliders(
        state: EditSessionState,
        sliderKelvin: Float,
        sliderTint: Float,
    ): EditSessionState {
        val wb = offsetsFromSliders(sliderKelvin, sliderTint)
        return state.withUserAdjustments(
            state.userAdjustments.copy(
                kelvinOffset = wb.kelvinOffset,
                tintOffset = wb.tintOffset,
            ),
        )
    }
}

package lv.edgarsfoto.efpic_live.processing

import lv.edgarsfoto.efpic_live.xmp.LightroomPreset
import kotlin.math.pow

/**
 * White balance, exposure, contrast, highlights/shadows, whites/blacks (Process 2012).
 * All operations in scene-linear space.
 */
object BasicToneEngine {

    data class ToneState(
        val tempKelvinScale: Float,
        val tintScale: Float,
        val exposureMul: Float,
        val contrastPivot: Float,
        val contrastGain: Float,
        val highlightsAmount: Float,
        val shadowsAmount: Float,
        val whitesAmount: Float,
        val blacksAmount: Float,
        val vibrance: Float,
        val saturation: Float,
    ) {
        companion object {
            fun fromPreset(p: LightroomPreset): ToneState {
                val exp = if (p.exposure2012 != 0f) p.exposure2012 else p.exposure
                val contrast = if (p.contrast2012 != 0) p.contrast2012 else p.contrast
                val temp = p.temperature + p.incrementalTemperature
                val tint = p.tint + p.incrementalTint
                return ToneState(
                    tempKelvinScale = kelvinToMultiplier(temp),
                    tintScale = 1f + tint / 150f,
                    exposureMul = 2f.pow(exp),
                    contrastPivot = 0.18f,
                    contrastGain = 1f + contrast / 100f,
                    highlightsAmount = p.highlights2012 / 100f,
                    shadowsAmount = p.shadows2012 / 100f,
                    whitesAmount = p.whites2012 / 100f,
                    blacksAmount = p.blacks2012 / 100f,
                    vibrance = p.vibrance / 100f,
                    saturation = p.saturation / 100f,
                )
            }

            /** Map XMP temperature offset (~±1500) to RGB multiplier around D65. */
            private fun kelvinToMultiplier(tempOffset: Int): Float =
                1f + tempOffset / 5000f
        }
    }

    @JvmStatic
    fun applyWhiteBalance(r: Float, g: Float, b: Float, state: ToneState): Triple<Float, Float, Float> {
        if (state.tempKelvinScale == 1f && state.tintScale == 1f) {
            return Triple(r, g, b)
        }
        // XMP incremental temperature/tint offsets relative to D65.
        val tempOffset = (state.tempKelvinScale - 1f) * 5000f
        val tempK = WhiteBalanceMath.NEUTRAL_KELVIN + tempOffset
        val tint = (state.tintScale - 1f) * WhiteBalanceMath.TINT_MAX
        val gains = WhiteBalanceMath.vonKriesGains(tempK, tint)
        return WhiteBalanceMath.applyDiagonalGains(r, g, b, gains)
    }

    @JvmStatic
    fun applyExposure(r: Float, g: Float, b: Float, mul: Float): Triple<Float, Float, Float> {
        if (mul == 1f) return Triple(r, g, b)
        return ColorSpaces.clampLinear(r * mul, g * mul, b * mul)
    }

    @JvmStatic
    fun applyContrast(r: Float, g: Float, b: Float, gain: Float, pivot: Float): Triple<Float, Float, Float> {
        if (gain == 1f) return Triple(r, g, b)
        fun ch(c: Float) = ((c - pivot) * gain + pivot).coerceIn(0f, 1f)
        return Triple(ch(r), ch(g), ch(b))
    }

    /** Highlights2012: masked luma compress/lift in upper range. */
    @JvmStatic
    fun applyHighlights(r: Float, g: Float, b: Float, amount: Float): Triple<Float, Float, Float> {
        if (amount == 0f) return Triple(r, g, b)
        val y = ColorSpaces.linearLuma(r, g, b)
        if (y < 1e-5f) return Triple(r, g, b)
        val mask = ColorSpaces.smoothstep(0.55f, 0.95f, y)
        val delta = amount * mask * 0.45f
        val newY = (y * (1f - delta * 0.5f) + delta * 0.15f).coerceIn(0f, 1f)
        if (amount > 0f) {
            val scale = (y + delta * (1f - y) * mask) / y
            return ColorSpaces.clampLinear(r * scale, g * scale, b * scale)
        }
        val scale = newY / y
        return ColorSpaces.clampLinear(r * scale, g * scale, b * scale)
    }

    /** Shadows2012: lift/crush dark tones. */
    @JvmStatic
    fun applyShadows(r: Float, g: Float, b: Float, amount: Float): Triple<Float, Float, Float> {
        if (amount == 0f) return Triple(r, g, b)
        val y = ColorSpaces.linearLuma(r, g, b)
        if (y < 1e-5f) return Triple(r, g, b)
        val mask = 1f - ColorSpaces.smoothstep(0.05f, 0.45f, y)
        val lift = amount * mask * 0.35f
        val newY = (y + lift).coerceIn(0f, 1f)
        val scale = newY / y
        return ColorSpaces.clampLinear(r * scale, g * scale, b * scale)
    }

    /**
     * **Whites2012** — moves the white clipping point in linear space.
     * Positive: expand bright headroom; negative: recover highlight shoulder.
     */
    @JvmStatic
    fun applyWhites(r: Float, g: Float, b: Float, amount: Float): Triple<Float, Float, Float> {
        if (amount == 0f) return Triple(r, g, b)
        val y = ColorSpaces.linearLuma(r, g, b)
        if (y < 1e-5f) return Triple(r, g, b)
        // White point pivot 0.75…1.0
        val whitePoint = (1f - amount * 0.22f).coerceIn(0.55f, 1.05f)
        val mask = ColorSpaces.smoothstep(0.5f, 0.98f, y)
        val norm = (y / whitePoint).coerceIn(0f, 1f)
        val newY = (norm + (y - norm) * (1f - mask)).coerceIn(0f, 1f)
        val scale = newY / y
        return ColorSpaces.clampLinear(r * scale, g * scale, b * scale)
    }

    /**
     * **Blacks2012** — adjusts black clipping threshold.
     * Positive: deepen blacks; negative: lift toe / fade black clip.
     */
    @JvmStatic
    fun applyBlacks(r: Float, g: Float, b: Float, amount: Float): Triple<Float, Float, Float> {
        if (amount == 0f) return Triple(r, g, b)
        val y = ColorSpaces.linearLuma(r, g, b)
        val blackPoint = (amount * 0.04f).coerceIn(-0.04f, 0.08f)
        val mask = 1f - ColorSpaces.smoothstep(0.08f, 0.35f, y)
        val newY = (y - blackPoint * mask).coerceIn(0f, 1f)
        if (y < 1e-5f) return Triple(r, g, b)
        val scale = newY / y
        return ColorSpaces.clampLinear(r * scale, g * scale, b * scale)
    }

    @JvmStatic
    fun applyGlobalSaturation(r: Float, g: Float, b: Float, sat: Float, vibrance: Float): Triple<Float, Float, Float> {
        if (sat == 0f && vibrance == 0f) return Triple(r, g, b)
        val y = ColorSpaces.linearLuma(r, g, b)
        val hsv = ColorSpaces.rgbToHsv(r, g, b)
        var s = hsv.s
        s *= 1f + sat
        if (vibrance != 0f) {
            val vibMask = (1f - s).coerceIn(0f, 1f)
            s += vibrance * vibMask * 0.8f
        }
        s = s.coerceIn(0f, 1f)
        val (nr, ng, nb) = ColorSpaces.hsvToRgb(hsv.h, s, hsv.v)
        return ColorSpaces.clampLinear(nr, ng, nb)
    }

    @JvmStatic
    fun applyBasicTones(r: Float, g: Float, b: Float, state: ToneState): Triple<Float, Float, Float> {
        var c = applyExposure(r, g, b, state.exposureMul)
        c = applyContrast(c.first, c.second, c.third, state.contrastGain, state.contrastPivot)
        c = applyHighlights(c.first, c.second, c.third, state.highlightsAmount)
        c = applyShadows(c.first, c.second, c.third, state.shadowsAmount)
        c = applyWhites(c.first, c.second, c.third, state.whitesAmount)
        c = applyBlacks(c.first, c.second, c.third, state.blacksAmount)
        c = applyGlobalSaturation(c.first, c.second, c.third, state.saturation, state.vibrance)
        return c
    }
}

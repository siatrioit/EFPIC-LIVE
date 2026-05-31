package lv.edgarsfoto.efpic_live.processing

import kotlin.math.ln
import kotlin.math.max
import kotlin.math.pow

/**
 * Kelvin/Tint → linear RGB channel multipliers (Von Kries + Tanner Helland).
 *
 * Pipeline for absolute white point at [kelvin]/[tint]:
 * 1. Helland: color temperature → illuminant RGB (linear 0…1).
 * 2. Von Kries: diagonal gains = targetIlluminant / referenceIlluminant (D65 ref).
 * 3. Tint: green ↔ magenta opponent axis on diagonal gains.
 * 4. Luminance normalization on reference gray so WB does not shift exposure.
 *
 * For embedded-JPG preview (already WB-correct at as-shot), use [deltaGains] =
 * gains(target) / gains(baseline).
 */
object WhiteBalanceMath {

    const val KELVIN_MIN = 2000f
    const val KELVIN_MAX = 50000f
    const val NEUTRAL_KELVIN = 6500f
    const val TINT_MIN = -150f
    const val TINT_MAX = 150f

    /** Rec.709 luma coefficients (linear). */
    private const val KR = 0.2126f
    private const val KG = 0.7152f
    private const val KB = 0.0722f

    /** Mid-gray linear reference for global luminance preservation. */
    private const val REF_GRAY_LINEAR = 0.18f

    data class RgbGains(
        val r: Float,
        val g: Float,
        val b: Float,
    ) {
        fun multiply(other: RgbGains): RgbGains =
            RgbGains(r * other.r, g * other.g, b * other.b)

        fun divideBy(other: RgbGains): RgbGains =
            RgbGains(
                r / max(other.r, 1e-6f),
                g / max(other.g, 1e-6f),
                b / max(other.b, 1e-6f),
            )

        fun isNeutral(epsilon: Float = 1e-4f): Boolean =
            (r - 1f).let { it * it } + (g - 1f).let { it * it } + (b - 1f).let { it * it } < epsilon * epsilon * 3f
    }

    /**
     * Von Kries diagonal gains for absolute [kelvin] + [tint] (scene-linear).
     * Optional [cameraMultipliers] from RAW MakerNote scale the baseline illuminant.
     */
    @JvmStatic
    fun vonKriesGains(
        kelvin: Float,
        tint: Float,
        cameraMultipliers: RgbGains? = null,
    ): RgbGains {
        val k = kelvin.coerceIn(KELVIN_MIN, KELVIN_MAX)
        val t = tint.coerceIn(TINT_MIN, TINT_MAX)

        val ref = kelvinToRgbLinear(NEUTRAL_KELVIN)
        val tgt = kelvinToRgbLinear(k)

        var gr = tgt.r / max(ref.r, 1e-6f)
        var gg = tgt.g / max(ref.g, 1e-6f)
        var gb = tgt.b / max(ref.b, 1e-6f)

        // Tint: +tint → magenta (↓G), −tint → green (↑G).
        val tm = t / TINT_MAX
        gr *= 1f + 0.11f * tm
        gg *= 1f - 0.15f * tm
        gb *= 1f + 0.11f * tm

        normalizeLuminanceOnRefGray(gr, gg, gb).let { (nr, ng, nb) ->
            gr = nr
            gg = ng
            gb = nb
        }

        var gains = RgbGains(gr, gg, gb)
        if (cameraMultipliers != null) {
            gains = gains.multiply(cameraMultipliers)
            normalizeLuminanceOnRefGray(gains.r, gains.g, gains.b).let { (nr, ng, nb) ->
                gains = RgbGains(nr, ng, nb)
            }
        }
        return gains
    }

    /** Gains to apply on top of an image already at [baselineKelvin]/[baselineTint]. */
    @JvmStatic
    fun deltaGains(
        baselineKelvin: Float,
        baselineTint: Float,
        targetKelvin: Float,
        targetTint: Float,
        baselineCameraMultipliers: RgbGains? = null,
        targetCameraMultipliers: RgbGains? = null,
    ): RgbGains {
        if (isAtBaseline(baselineKelvin, baselineTint, targetKelvin, targetTint) &&
            baselineCameraMultipliers == null &&
            targetCameraMultipliers == null
        ) {
            return RgbGains(1f, 1f, 1f)
        }
        val base = vonKriesGains(baselineKelvin, baselineTint, baselineCameraMultipliers)
        val tgt = vonKriesGains(targetKelvin, targetTint, targetCameraMultipliers)
        return tgt.divideBy(base)
    }

    @JvmStatic
    fun isAtBaseline(
        baselineKelvin: Float,
        baselineTint: Float,
        kelvin: Float,
        tint: Float,
    ): Boolean =
        kotlin.math.abs(kelvin - baselineKelvin) < 0.5f &&
            kotlin.math.abs(tint - baselineTint) < 0.5f

    /**
     * Tanner Helland — approximate RGB for a black-body-style illuminant (Kelvin).
     * Returns linear 0…1 primaries.
     */
    @JvmStatic
    fun kelvinToRgbLinear(kelvin: Float): RgbGains {
        val temp = kelvin.coerceIn(KELVIN_MIN, KELVIN_MAX) / 100f
        val r: Float
        val g: Float
        val b: Float
        if (temp <= 66f) {
            r = 255f
            g = (99.4708025861f * ln(temp) - 161.1195681661f).toFloat()
            b = if (temp <= 19f) {
                0f
            } else {
                (138.5177312231f * ln(temp - 10f) - 305.0447927307f).toFloat()
            }
        } else {
            r = (329.698727446f * (temp - 60f).pow(-0.1332047592f)).toFloat()
            g = (288.1221695283f * (temp - 60f).pow(-0.0755148492f)).toFloat()
            b = 255f
        }
        return RgbGains(
            r = r.coerceIn(0f, 255f) / 255f,
            g = g.coerceIn(0f, 255f) / 255f,
            b = b.coerceIn(0f, 255f) / 255f,
        )
    }

    @JvmStatic
    fun applyDiagonalGains(r: Float, g: Float, b: Float, gains: RgbGains): Triple<Float, Float, Float> {
        var nr = r * gains.r
        var ng = g * gains.g
        var nb = b * gains.b
        val maxC = max(nr, max(ng, nb))
        if (maxC > 1f) {
            val s = 1f / maxC
            nr *= s
            ng *= s
            nb *= s
        }
        return ColorSpaces.clampLinear(nr, ng, nb)
    }

    private fun normalizeLuminanceOnRefGray(r: Float, g: Float, b: Float): Triple<Float, Float, Float> {
        val inLuma = REF_GRAY_LINEAR
        val outLuma = KR * REF_GRAY_LINEAR * r + KG * REF_GRAY_LINEAR * g + KB * REF_GRAY_LINEAR * b
        if (outLuma <= 1e-6f) return Triple(r, g, b)
        val scale = inLuma / outLuma
        return Triple(r * scale, g * scale, b * scale)
    }
}
